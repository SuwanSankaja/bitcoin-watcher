"""
Lambda Function #2 (Hodler): Signal Analyzer — Accumulation Engine
Replaces BUY/SELL/HOLD with a composite Accumulation Score (0–100).
Only acts on buy opportunities. No automated sell.
"""

import json
import os
from datetime import datetime, timedelta
import pytz
from pymongo import MongoClient
import boto3
import requests
import firebase_admin
from firebase_admin import credentials, messaging
from binance_trader import BinanceSpotTrader, get_binance_credentials_from_aws

# --- Firebase ---
firebase_app = None


def initialize_firebase():
    global firebase_app
    if firebase_app is None:
        secrets_client = boto3.client('secretsmanager')
        secret = secrets_client.get_secret_value(
            SecretId='bitcoin-watcher-firebase-creds'
        )
        cred_dict = json.loads(secret['SecretString'])
        cred = credentials.Certificate(cred_dict)
        firebase_app = firebase_admin.initialize_app(cred)
    return firebase_app


# --- MongoDB ---
def get_mongo_client():
    mongo_uri = os.getenv('MONGODB_URI')
    if not mongo_uri:
        try:
            ssm = boto3.client('ssm')
            mongo_uri = ssm.get_parameter(
                Name='/bitcoin-watcher/mongodb-uri',
                WithDecryption=True
            )['Parameter']['Value']
        except Exception as e:
            print(f"Error fetching MongoDB URI from SSM: {e}")
            raise Exception("MongoDB URI not found in environment or SSM")
    return MongoClient(mongo_uri)


# --- Settings ---
def get_settings_from_db():
    """Fetch hodler settings from MongoDB (merged with expanded defaults)"""
    default_settings = {
        'notifications_enabled': True,
        # MA parameters
        'buy_threshold': 0.001,
        'short_ma_period': 7,
        'long_ma_period': 25,
        # RSI
        'rsi_period': 14,
        'rsi_overbought': 70,
        'rsi_oversold': 30,
        # Bollinger Bands
        'bb_period': 20,
        'bb_std_dev': 2.0,
        # Accumulation scoring
        'min_score_threshold': 60,       # minimum score to trigger a buy
        'lookback_hours': 4,             # hours of price history used for dip_depth
        # Trading / DCA
        'trading_enabled': False,
        'trading_mode': 'testnet',
        'trade_amount_usdt': 20,
        'dca_scale_factor': 1.5,
        'max_single_trade_usdt': 200,
    }

    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        settings_doc = db['settings'].find_one({'_id': 'hodler_default'})
        # fall back to the shared 'default' doc if hodler-specific one not set
        if not settings_doc:
            settings_doc = db['settings'].find_one({'_id': 'default'})
        client.close()

        if settings_doc and 'settings' in settings_doc:
            merged = default_settings.copy()
            merged.update(settings_doc['settings'])
            print(f"Using settings: {merged}")
            return merged
        else:
            print("No settings in MongoDB, using defaults")
            return default_settings
    except Exception as e:
        print(f"Error fetching settings: {e}")
        return default_settings


# --- Price data ---
def get_recent_prices(minutes=90):
    """Fetch recent prices from MongoDB (longer window for Bollinger Bands)"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['btc_prices']

        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_now = datetime.now(sri_lanka_tz).replace(tzinfo=None)
        cutoff_time = sri_lanka_now - timedelta(minutes=minutes)

        prices = list(collection.find(
            {'timestamp': {'$gte': cutoff_time}},
            {'_id': 0, 'timestamp': 1, 'price': 1, 'volume_24h': 1}
        ).sort('timestamp', 1))

        client.close()
        print(f"Fetched {len(prices)} price points over last {minutes} min")
        return prices
    except Exception as e:
        print(f"Error fetching prices: {e}")
        raise


# --- Indicators ---
def calculate_moving_average(prices, period):
    if len(prices) < period:
        return None
    return sum(p['price'] for p in prices[-period:]) / period


def calculate_rsi(prices, period=14):
    if len(prices) < period + 1:
        return 50

    gains, losses = [], []
    for i in range(1, len(prices)):
        change = prices[i]['price'] - prices[i - 1]['price']
        gains.append(max(change, 0))
        losses.append(max(-change, 0))

    if len(gains) < period:
        return 50

    avg_gain = sum(gains[-period:]) / period
    avg_loss = sum(losses[-period:]) / period

    if avg_loss == 0:
        return 100
    rs = avg_gain / avg_loss
    return 100 - (100 / (1 + rs))


def calculate_bollinger_bands(prices, period=20, std_dev_mult=2.0):
    """
    Returns (upper, middle, lower) Bollinger Bands.
    Returns None, None, None if insufficient data.
    """
    if len(prices) < period:
        return None, None, None

    recent = [p['price'] for p in prices[-period:]]
    middle = sum(recent) / period
    variance = sum((p - middle) ** 2 for p in recent) / period
    std_dev = variance ** 0.5

    upper = middle + std_dev_mult * std_dev
    lower = middle - std_dev_mult * std_dev
    return upper, middle, lower


def get_fear_greed_index():
    """
    Fetch current Crypto Fear & Greed Index from Alternative.me (free, no auth).
    Returns (value: int, label: str) or (50, 'Neutral') on error.
    Scale: 0=Extreme Fear, 25=Fear, 50=Neutral, 75=Greed, 100=Extreme Greed.
    """
    try:
        response = requests.get(
            'https://api.alternative.me/fng/',
            params={'limit': 1},
            timeout=8
        )
        data = response.json()
        value = int(data['data'][0]['value'])
        label = data['data'][0]['value_classification']
        print(f"Fear & Greed Index: {value} ({label})")
        return value, label
    except Exception as e:
        print(f"Could not fetch Fear & Greed index: {e} — defaulting to Neutral (50)")
        return 50, 'Neutral'


def calculate_dip_depth(prices, lookback_hours=4):
    """
    How far below the recent high the current price sits, as a percentage.
    Returns 0.0–100.0 (100 = price is AT the recent high, 0 = undefined/error).
    """
    try:
        if not prices:
            return 0.0
        recent_high = max(p['price'] for p in prices)
        current_price = prices[-1]['price']
        if recent_high == 0:
            return 0.0
        dip_pct = ((recent_high - current_price) / recent_high) * 100
        return round(dip_pct, 4)
    except Exception as e:
        print(f"Error calculating dip depth: {e}")
        return 0.0


# --- Core Accumulation Score ---
def calculate_accumulation_score(prices, settings):
    """
    Composite Accumulation Score 0–100.

    Component breakdown:
      RSI component       0–30 pts  (max when RSI < rsi_oversold)
      MA crossover        0–25 pts  (short MA below long MA by threshold)
      Bollinger lower     0–20 pts  (price at/below lower BB)
      Fear & Greed        0–15 pts  (Extreme Fear/Fear zone)
      Dip depth           0–10 pts  (deeper dip from recent high)
    """
    if not prices:
        return 0, {}

    current_price = prices[-1]['price']

    short_period = settings.get('short_ma_period', 7)
    long_period = settings.get('long_ma_period', 25)
    buy_threshold = settings.get('buy_threshold', 0.001)
    rsi_period = settings.get('rsi_period', 14)
    rsi_oversold = settings.get('rsi_oversold', 30)
    bb_period = settings.get('bb_period', 20)
    bb_std = settings.get('bb_std_dev', 2.0)
    lookback_hours = settings.get('lookback_hours', 4)

    # Calculate indicators
    short_ma = calculate_moving_average(prices, short_period)
    long_ma = calculate_moving_average(prices, long_period)
    rsi = calculate_rsi(prices, rsi_period)
    bb_upper, bb_middle, bb_lower = calculate_bollinger_bands(prices, bb_period, bb_std)
    fear_greed_value, fear_greed_label = get_fear_greed_index()
    dip_depth = calculate_dip_depth(prices, lookback_hours)

    print(f"Price=${current_price:.2f} | SMA({short_period})={short_ma:.2f if short_ma else 'N/A'} | "
          f"SMA({long_period})={long_ma:.2f if long_ma else 'N/A'} | RSI={rsi:.2f} | "
          f"BB_lower={bb_lower:.2f if bb_lower else 'N/A'} | "
          f"F&G={fear_greed_value} | Dip={dip_depth:.2f}%")

    score = 0
    breakdown = {}

    # ── 1. RSI component (0–30 pts) ─────────────────────────────────────────
    if rsi <= rsi_oversold:
        # Full points when deeply oversold; scales from 15 at oversold threshold → 30 at RSI=0
        rsi_pts = 30 * (1 - rsi / rsi_oversold) + 15
        rsi_pts = min(30, rsi_pts)
    elif rsi < 45:
        rsi_pts = 8  # slightly below neutral
    else:
        rsi_pts = max(0, 8 - (rsi - 45) * 0.5)  # diminishing above neutral

    rsi_pts = round(rsi_pts, 2)
    score += rsi_pts
    breakdown['rsi_pts'] = rsi_pts
    print(f"  RSI pts: {rsi_pts:.1f}/30 (RSI={rsi:.1f})")

    # ── 2. MA crossover (0–25 pts) ──────────────────────────────────────────
    ma_pts = 0
    if short_ma and long_ma:
        ma_divergence = (long_ma - short_ma) / long_ma  # positive = short below long
        if ma_divergence >= buy_threshold:
            # Scale: threshold = 15 pts, 3× threshold = 25 pts
            ma_pts = min(25, 15 + (ma_divergence / buy_threshold - 1) * 5)
    ma_pts = round(ma_pts, 2)
    score += ma_pts
    breakdown['ma_pts'] = ma_pts
    print(f"  MA pts: {ma_pts:.1f}/25")

    # ── 3. Bollinger Band lower touch (0–20 pts) ────────────────────────────
    bb_pts = 0
    if bb_lower is not None:
        if current_price <= bb_lower:
            # Below lower band: full 20 pts, scaled by how far below
            pct_below = (bb_lower - current_price) / bb_lower * 100
            bb_pts = min(20, 20 + pct_below * 2)
        elif current_price <= bb_lower * 1.005:
            bb_pts = 14  # touching lower band
        elif current_price <= bb_middle:
            # Between lower and middle: partial credit
            fraction = (bb_middle - current_price) / (bb_middle - bb_lower)
            bb_pts = fraction * 10
    bb_pts = round(bb_pts, 2)
    score += bb_pts
    breakdown['bb_pts'] = bb_pts
    print(f"  BB pts: {bb_pts:.1f}/20 (lower={bb_lower:.2f if bb_lower else 'N/A'})")

    # ── 4. Fear & Greed (0–15 pts) ──────────────────────────────────────────
    if fear_greed_value <= 10:
        fg_pts = 15    # Extreme Fear
    elif fear_greed_value <= 25:
        fg_pts = 12   # Fear
    elif fear_greed_value <= 40:
        fg_pts = 7    # Approaching fear
    elif fear_greed_value <= 50:
        fg_pts = 3    # Neutral
    else:
        fg_pts = 0    # Greed/Extreme Greed — no credit
    score += fg_pts
    breakdown['fg_pts'] = fg_pts
    print(f"  F&G pts: {fg_pts:.1f}/15 (index={fear_greed_value} '{fear_greed_label}')")

    # ── 5. Dip depth (0–10 pts) ─────────────────────────────────────────────
    if dip_depth >= 5.0:
        dip_pts = 10   # 5%+ dip from recent high
    elif dip_depth >= 3.0:
        dip_pts = 7
    elif dip_depth >= 1.5:
        dip_pts = 4
    elif dip_depth >= 0.5:
        dip_pts = 2
    else:
        dip_pts = 0
    score += dip_pts
    breakdown['dip_pts'] = dip_pts
    print(f"  Dip pts: {dip_pts:.1f}/10 (dip={dip_depth:.2f}%)")

    score = round(min(100, score), 2)
    print(f"  ▶ Accumulation Score: {score}/100")

    return score, {
        'score': score,
        'rsi': round(rsi, 2),
        'short_ma': round(short_ma, 2) if short_ma else None,
        'long_ma': round(long_ma, 2) if long_ma else None,
        'bb_upper': round(bb_upper, 2) if bb_upper else None,
        'bb_middle': round(bb_middle, 2) if bb_middle else None,
        'bb_lower': round(bb_lower, 2) if bb_lower else None,
        'fear_greed_index': fear_greed_value,
        'fear_greed_label': fear_greed_label,
        'dip_depth': dip_depth,
        **breakdown
    }


def analyze_signal(prices, settings):
    """
    Wrapper: compute score + determine signal_type.
    Returns signal dict for storage/notification/trading.
    """
    min_score = settings.get('min_score_threshold', 60)

    if not prices:
        return {
            'type': 'HOLD',
            'accumulation_score': 0,
            'buy_zone': False,
            'price': 0,
            'confidence': 0,
            'reason': 'No price data'
        }

    current_price = prices[-1]['price']
    score, indicators = calculate_accumulation_score(prices, settings)

    buy_zone = score >= min_score
    signal_type = 'BUY' if buy_zone else 'HOLD'

    return {
        'type': signal_type,
        'accumulation_score': score,
        'buy_zone': buy_zone,
        'price': current_price,
        'confidence': score,   # for backward compat with existing Flutter model
        **indicators
    }


# --- Database helpers ---
def get_last_signal():
    try:
        client = get_mongo_client()
        last = client['bitcoin_watcher']['signals'].find_one({}, sort=[('timestamp', -1)])
        client.close()
        return last
    except Exception as e:
        print(f"Error fetching last signal: {e}")
        return None


def store_signal(signal_data):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_naive = datetime.now(sri_lanka_tz).replace(tzinfo=None)

        document = {
            'timestamp': sri_lanka_naive,
            'type': signal_data['type'],
            'price': signal_data['price'],
            'confidence': signal_data.get('confidence', 0),
            # Hodler-specific fields
            'accumulation_score': signal_data.get('accumulation_score', 0),
            'buy_zone': signal_data.get('buy_zone', False),
            'rsi': signal_data.get('rsi'),
            'short_ma': signal_data.get('short_ma'),
            'long_ma': signal_data.get('long_ma'),
            'bb_lower': signal_data.get('bb_lower'),
            'fear_greed_index': signal_data.get('fear_greed_index'),
            'fear_greed_label': signal_data.get('fear_greed_label'),
            'dip_depth': signal_data.get('dip_depth'),
        }

        result = db['signals'].insert_one(document)
        client.close()
        return str(result.inserted_id)
    except Exception as e:
        print(f"Error storing signal: {e}")
        raise


def store_trade(trade_result, signal_id, signal_data, btc_balance_after=None, scaled_usdt=None):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_naive = datetime.now(sri_lanka_tz).replace(tzinfo=None)

        fills = trade_result.get('fills', [])
        total_qty = sum(float(f['qty']) for f in fills) if fills else 0
        avg_price = (
            sum(float(f['price']) * float(f['qty']) for f in fills) / total_qty
            if total_qty > 0 else 0
        )

        trade_doc = {
            'timestamp': sri_lanka_naive,
            'signal_id': signal_id,
            'binance_order_id': trade_result.get('orderId'),
            'symbol': trade_result.get('symbol'),
            'side': trade_result.get('side'),
            'type': trade_result.get('type'),
            'status': trade_result.get('status'),
            'executed_qty': float(trade_result.get('executedQty', 0)),
            'average_price': avg_price,
            'signal_price': signal_data.get('price'),
            'signal_confidence': signal_data.get('confidence'),
            'accumulation_score': signal_data.get('accumulation_score'),
            'usdt_spent': scaled_usdt,
            'fills': fills,
            'btc_balance_after': btc_balance_after,
        }

        result = db['trades'].insert_one(trade_doc)
        client.close()
        print(f"Trade stored in MongoDB: {result.inserted_id}")
        return str(result.inserted_id)
    except Exception as e:
        print(f"Error storing trade: {e}")
        raise


def store_failed_trade(signal_data, signal_id, error_message):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_naive = datetime.now(sri_lanka_tz).replace(tzinfo=None)

        db['failed_trades'].insert_one({
            'timestamp': sri_lanka_naive,
            'signal_id': signal_id,
            'signal_type': signal_data['type'],
            'signal_price': signal_data['price'],
            'accumulation_score': signal_data.get('accumulation_score', 0),
            'error': error_message,
        })
        client.close()
    except Exception as e:
        print(f"Error storing failed trade: {e}")


def execute_trade(signal_data, signal_id, settings):
    """Execute DCA-scaled buy based on accumulation score"""
    try:
        if not settings.get('trading_enabled', False):
            print("Trading disabled in settings")
            return None

        if signal_data['type'] != 'BUY':
            print(f"No trade for {signal_data['type']} signal (only BUY triggers trades in hodler mode)")
            return None

        is_testnet = settings.get('trading_mode', 'testnet') == 'testnet'
        print(f"Fetching Binance credentials ({'testnet' if is_testnet else 'PRODUCTION'})")
        creds = get_binance_credentials_from_aws(testnet=is_testnet)

        trader = BinanceSpotTrader(
            api_key=creds['api_key'],
            api_secret=creds['api_secret'],
            testnet=is_testnet
        )
        trader.test_connection()

        accumulation_score = signal_data.get('accumulation_score', 60)
        base_usdt = settings.get('trade_amount_usdt', 20)
        scale_factor = settings.get('dca_scale_factor', 1.5)
        max_usdt = settings.get('max_single_trade_usdt', 200)

        order_result, actual_usdt_spent = trader.execute_scaled_buy(
            usdt_base_amount=base_usdt,
            accumulation_score=accumulation_score,
            dca_scale_factor=scale_factor,
            max_usdt=max_usdt,
            symbol='BTCUSDT'
        )

        if order_result:
            btc_balance_after = None
            try:
                balance = trader.get_balance('BTC')
                btc_balance_after = float(balance['free'])
            except Exception as e:
                print(f"Could not fetch BTC balance after trade: {e}")

            store_trade(order_result, signal_id, signal_data, btc_balance_after, actual_usdt_spent)
            print(f"✅ DCA BUY executed and stored | Score={accumulation_score} | USDT=${actual_usdt_spent:.2f}")

        return order_result

    except Exception as e:
        print(f"❌ Trade execution failed: {e}")
        store_failed_trade(signal_data, signal_id, str(e))
        return None


def send_notification(signal_data, signal_id):
    """Send FCM notification for BUY zone events"""
    try:
        if signal_data['type'] not in ['BUY']:
            return

        initialize_firebase()

        score = signal_data.get('accumulation_score', 0)
        price = signal_data['price']

        # Score tier label
        if score >= 85:
            tier = "🔥 STRONG BUY ZONE"
        elif score >= 70:
            tier = "🟢 BUY ZONE"
        else:
            tier = "🟡 Moderate Buy Zone"

        title = f"₿ Accumulation Score: {score:.0f}/100"
        body = f"{tier} — BTC at ${price:,.2f}"

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={
                'signal_id': signal_id,
                'signal_type': signal_data['type'],
                'price': str(price),
                'accumulation_score': str(score),
                'confidence': str(score),
            },
            topic='bitcoin-signals'
        )

        response = messaging.send(message)
        print(f"Notification sent: {response}")

        # Store notification
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_naive = datetime.now(sri_lanka_tz).replace(tzinfo=None)

        db['notifications'].insert_one({
            'timestamp': sri_lanka_naive,
            'signal_id': signal_id,
            'title': title,
            'message': body,
            'signal_type': signal_data['type'],
            'price': price,
            'accumulation_score': score,
        })
        client.close()
        return True

    except Exception as e:
        print(f"Error sending notification: {e}")
        return False


def lambda_handler(event, context):
    """Main Lambda handler — Hodler Accumulation Engine"""
    try:
        settings = get_settings_from_db()
        min_score = settings.get('min_score_threshold', 60)
        lookback_min = max(90, settings.get('lookback_hours', 4) * 60)

        print(f"Hodler settings: min_score={min_score} | "
              f"MA={settings['short_ma_period']}/{settings['long_ma_period']} | "
              f"BB={settings['bb_period']}p/{settings['bb_std_dev']}σ | "
              f"DCA_scale={settings['dca_scale_factor']}x | "
              f"max_usdt=${settings['max_single_trade_usdt']}")

        prices = get_recent_prices(minutes=lookback_min)

        if not prices:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No price data available'})
            }

        signal_data = analyze_signal(prices, settings)
        last_signal = get_last_signal()
        signal_id = store_signal(signal_data)

        # Only act when we enter a NEW buy zone (score crossed threshold)
        entered_buy_zone = (
            signal_data['buy_zone'] and
            (last_signal is None or not last_signal.get('buy_zone', False))
        )

        trade_executed = False
        if entered_buy_zone and settings.get('trading_enabled', False):
            print(f"Entering buy zone! Score={signal_data['accumulation_score']:.1f} — executing DCA buy...")
            trade_result = execute_trade(signal_data, signal_id, settings)
            trade_executed = trade_result is not None

        should_notify = settings['notifications_enabled'] and entered_buy_zone
        if should_notify:
            send_notification(signal_data, signal_id)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Signal analyzed successfully (hodler mode)',
                'signal': {
                    'type': signal_data['type'],
                    'accumulation_score': signal_data['accumulation_score'],
                    'buy_zone': signal_data['buy_zone'],
                    'price': signal_data['price'],
                    'rsi': signal_data.get('rsi'),
                    'fear_greed_index': signal_data.get('fear_greed_index'),
                    'dip_depth': signal_data.get('dip_depth'),
                },
                'notification_sent': should_notify,
                'trade_executed': trade_executed,
            })
        }

    except Exception as e:
        print(f"Lambda execution error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Error processing request', 'error': str(e)})
        }
