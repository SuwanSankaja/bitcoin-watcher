"""
Lambda Function #2: Signal Analyzer
Analyzes recent prices, calculates moving averages, generates buy/sell signals,
sends notifications via FCM, and executes trades on Binance
"""

import json
import os
from datetime import datetime, timedelta
import pytz
from pymongo import MongoClient
import boto3
import firebase_admin
from firebase_admin import credentials, messaging
from binance_trader import BinanceSpotTrader, get_binance_credentials_from_aws

# Initialize Firebase Admin SDK
firebase_app = None

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    global firebase_app
    if firebase_app is None:
        # Get Firebase credentials from Secrets Manager
        secrets_client = boto3.client('secretsmanager')
        secret = secrets_client.get_secret_value(
            SecretId='bitcoin-watcher-firebase-creds'
        )
        cred_dict = json.loads(secret['SecretString'])
        
        cred = credentials.Certificate(cred_dict)
        firebase_app = firebase_admin.initialize_app(cred)
    return firebase_app

def get_mongo_client():
    """Get MongoDB client - supports both Lambda (SSM) and local (.env)"""
    # Try environment variable first (for local testing)
    mongo_uri = os.getenv('MONGODB_URI')

    # If not in env, try AWS SSM (for Lambda)
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

def get_settings_from_db():
    """Fetch settings from MongoDB, return defaults if not found"""
    default_settings = {
        'notifications_enabled': True,
        'buy_threshold': 0.008,  # 0.8% - Day trading: catch smaller movements
        'sell_threshold': 0.008,  # 0.8% - Day trading: catch smaller movements
        'short_ma_period': 5,  # 5 min - Fast reaction to price changes
        'long_ma_period': 15,  # 15 min - Quick trend detection for day trading
        'trading_enabled': False,  # Enable/disable automated trading
        'trading_mode': 'testnet',  # 'testnet' or 'production'
        'trade_amount_usdt': 100,  # USDT amount per BUY trade
        'sell_percentage': 100  # Percentage of BTC to sell (100 = all)
    }
    
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['settings']
        
        settings_doc = collection.find_one({'_id': 'default'})
        client.close()
        
        if settings_doc and 'settings' in settings_doc:
            # Merge stored settings with defaults
            merged_settings = default_settings.copy()
            merged_settings.update(settings_doc['settings'])
            print(f"Using settings from MongoDB: {merged_settings}")
            return merged_settings
        else:
            print("No settings found in MongoDB, using defaults")
            return default_settings
    except Exception as e:
        print(f"Error fetching settings from MongoDB: {e}")
        print("Falling back to default settings")
        return default_settings

def get_recent_prices(minutes=30):
    """Fetch recent prices from MongoDB"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['btc_prices']
        
        # Get current time in Sri Lanka timezone
        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_now = datetime.now(sri_lanka_tz)
        
        # Remove timezone for MongoDB query (since we store naive datetimes)
        sri_lanka_naive = sri_lanka_now.replace(tzinfo=None)
        cutoff_time = sri_lanka_naive - timedelta(minutes=minutes)
        
        prices = list(collection.find(
            {'timestamp': {'$gte': cutoff_time}},
            {'_id': 0, 'timestamp': 1, 'price': 1}
        ).sort('timestamp', 1))
        
        client.close()
        return prices
    except Exception as e:
        print(f"Error fetching prices: {e}")
        raise

def calculate_moving_average(prices, period):
    """Calculate moving average for given period"""
    if len(prices) < period:
        return None
    
    recent_prices = [p['price'] for p in prices[-period:]]
    return sum(recent_prices) / len(recent_prices)

def get_last_signal():
    """Get the most recent signal from database"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['signals']
        
        last_signal = collection.find_one(
            {},
            sort=[('timestamp', -1)]
        )
        
        client.close()
        return last_signal
    except Exception as e:
        print(f"Error fetching last signal: {e}")
        return None

def analyze_signal(prices, short_period=5, long_period=15, buy_threshold=0.008, sell_threshold=0.008):
    """Analyze prices and generate trading signal

    CORRECTED LOGIC:
    - BUY: When short MA crosses significantly BELOW long MA (price dipping - buy opportunity)
    - SELL: When short MA crosses significantly ABOVE long MA (price peaking - sell opportunity)
    """
    if len(prices) < long_period:
        return {
            'type': 'HOLD',
            'price': prices[-1]['price'] if prices else 0,
            'confidence': 0,
            'reason': 'Insufficient data'
        }

    # Calculate moving averages
    short_ma = calculate_moving_average(prices, short_period)
    long_ma = calculate_moving_average(prices, long_period)

    current_price = prices[-1]['price']

    # CORRECTED Calculate signal logic
    # When short MA is significantly BELOW long MA -> downtrend -> BUY opportunity (buy the dip)
    # When short MA is significantly ABOVE long MA -> uptrend -> SELL opportunity (take profit)
    if short_ma < long_ma * (1 - buy_threshold):
        signal_type = 'BUY'
        confidence = min(((1 - short_ma / long_ma) / buy_threshold) * 100, 100)
    elif short_ma > long_ma * (1 + sell_threshold):
        signal_type = 'SELL'
        confidence = min(((short_ma / long_ma - 1) / sell_threshold) * 100, 100)
    else:
        signal_type = 'HOLD'
        confidence = 50

    return {
        'type': signal_type,
        'price': current_price,
        'confidence': round(confidence, 2),
        'short_ma': round(short_ma, 2),
        'long_ma': round(long_ma, 2)
    }

def store_signal(signal_data):
    """Store signal in MongoDB"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['signals']
        
        # Get Sri Lanka time
        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_time = datetime.now(sri_lanka_tz)
        
        # Remove timezone info so MongoDB stores the actual Sri Lanka time
        sri_lanka_naive = sri_lanka_time.replace(tzinfo=None)
        
        document = {
            'timestamp': sri_lanka_naive,
            'type': signal_data['type'],
            'price': signal_data['price'],
            'confidence': signal_data['confidence']
        }
        
        result = collection.insert_one(document)
        client.close()
        
        return str(result.inserted_id)
    except Exception as e:
        print(f"Error storing signal: {e}")
        raise

def execute_trade(signal_data, signal_id, settings):
    """
    Execute trade on Binance based on signal

    Args:
        signal_data: Signal information (type, price, confidence)
        signal_id: MongoDB signal ID
        settings: Trading settings from database
    """
    try:
        # Check if trading is enabled
        if not settings.get('trading_enabled', False):
            print("Trading is disabled in settings")
            return None

        # Only trade on BUY or SELL signals
        if signal_data['type'] not in ['BUY', 'SELL']:
            print(f"No trade for {signal_data['type']} signal")
            return None

        # Determine testnet vs production
        is_testnet = settings.get('trading_mode', 'testnet') == 'testnet'

        # Get Binance credentials from AWS Secrets Manager
        print(f"Fetching Binance credentials ({'testnet' if is_testnet else 'PRODUCTION'})")
        credentials = get_binance_credentials_from_aws(testnet=is_testnet)

        # Initialize Binance trader
        trader = BinanceSpotTrader(
            api_key=credentials['api_key'],
            api_secret=credentials['api_secret'],
            testnet=is_testnet
        )

        # Test connection
        if not trader.test_connection():
            raise Exception("Failed to connect to Binance API")

        trade_result = None

        # Execute trade based on signal type
        if signal_data['type'] == 'BUY':
            trade_amount = settings.get('trade_amount_usdt', 100)
            print(f"Executing BUY trade: ${trade_amount} USDT")
            trade_result = trader.execute_buy_signal(
                usdt_amount=trade_amount,
                symbol='BTCUSDT'
            )

        elif signal_data['type'] == 'SELL':
            sell_percentage = settings.get('sell_percentage', 100)
            print(f"Executing SELL trade: {sell_percentage}% of BTC")
            trade_result = trader.execute_sell_signal(
                btc_percentage=sell_percentage,
                symbol='BTCUSDT'
            )

        # Store trade in database
        if trade_result:
            store_trade(trade_result, signal_id, signal_data)
            print(f"✅ Trade executed and stored: {signal_data['type']}")

        return trade_result

    except Exception as e:
        print(f"❌ Trade execution failed: {e}")
        # Store failed trade attempt
        store_failed_trade(signal_data, signal_id, str(e))
        return None


def store_trade(trade_result, signal_id, signal_data):
    """Store successful trade in MongoDB"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['trades']

        # Get Sri Lanka time
        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_time = datetime.now(sri_lanka_tz)
        sri_lanka_naive = sri_lanka_time.replace(tzinfo=None)

        # Calculate average price from fills
        fills = trade_result.get('fills', [])
        total_qty = sum(float(fill['qty']) for fill in fills) if fills else 0
        avg_price = (
            sum(float(fill['price']) * float(fill['qty']) for fill in fills) / total_qty
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
            'fills': fills
        }

        result = collection.insert_one(trade_doc)
        client.close()

        print(f"Trade stored in MongoDB with ID: {result.inserted_id}")
        return str(result.inserted_id)

    except Exception as e:
        print(f"Error storing trade: {e}")
        raise


def store_failed_trade(signal_data, signal_id, error_message):
    """Store failed trade attempt in MongoDB"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['failed_trades']

        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_time = datetime.now(sri_lanka_tz)
        sri_lanka_naive = sri_lanka_time.replace(tzinfo=None)

        failed_trade_doc = {
            'timestamp': sri_lanka_naive,
            'signal_id': signal_id,
            'signal_type': signal_data['type'],
            'signal_price': signal_data['price'],
            'error': error_message
        }

        collection.insert_one(failed_trade_doc)
        client.close()

        print(f"Failed trade logged in MongoDB")

    except Exception as e:
        print(f"Error storing failed trade: {e}")


def send_notification(signal_data, signal_id):
    """Send FCM notification and store in database"""
    try:
        # Only send notifications for BUY or SELL signals
        if signal_data['type'] not in ['BUY', 'SELL']:
            return
        
        # Initialize Firebase
        initialize_firebase()
        
        # Create notification message
        title = f"{signal_data['type']} Signal Detected!"
        body = f"BTC at ${signal_data['price']:,.2f} - Confidence {signal_data['confidence']:.0f}%"
        
        # Send to topic (all subscribed devices)
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                'signal_id': signal_id,
                'signal_type': signal_data['type'],
                'price': str(signal_data['price']),
                'confidence': str(signal_data['confidence']),
            },
            topic='bitcoin-signals'
        )
        
        response = messaging.send(message)
        print(f"Notification sent: {response}")
        
        # Store notification in database
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['notifications']
        
        # Get Sri Lanka time
        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_time = datetime.now(sri_lanka_tz)
        
        # Remove timezone info so MongoDB stores the actual Sri Lanka time
        sri_lanka_naive = sri_lanka_time.replace(tzinfo=None)
        
        notification_doc = {
            'timestamp': sri_lanka_naive,
            'signal_id': signal_id,
            'title': title,
            'message': body,
            'signal_type': signal_data['type'],
            'price': signal_data['price']
        }
        
        collection.insert_one(notification_doc)
        client.close()
        
        return True
    except Exception as e:
        print(f"Error sending notification: {e}")
        return False

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Get settings from MongoDB
        settings = get_settings_from_db()
        print(f"Using MA periods: {settings['short_ma_period']}/{settings['long_ma_period']}, Thresholds: {settings['buy_threshold']}/{settings['sell_threshold']}")
        
        # Fetch recent prices
        prices = get_recent_prices(minutes=30)
        
        if not prices:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No prices available'})
            }
        
        # Analyze and generate signal with dynamic settings
        signal_data = analyze_signal(
            prices,
            short_period=settings['short_ma_period'],
            long_period=settings['long_ma_period'],
            buy_threshold=settings['buy_threshold'],
            sell_threshold=settings['sell_threshold']
        )
        
        # Get last signal to check if it changed
        last_signal = get_last_signal()
        
        # Store current signal
        signal_id = store_signal(signal_data)
        
        # Check if signal changed
        signal_changed = (
            signal_data['type'] in ['BUY', 'SELL'] and
            (last_signal is None or last_signal.get('type') != signal_data['type'])
        )

        # Execute trade if enabled and signal changed
        trade_executed = False
        if signal_changed and settings.get('trading_enabled', False):
            print(f"Signal changed to {signal_data['type']}, attempting trade execution...")
            trade_result = execute_trade(signal_data, signal_id, settings)
            trade_executed = trade_result is not None

        # Send notification if enabled and signal changed
        should_notify = (
            settings['notifications_enabled'] and
            signal_changed
        )

        if should_notify:
            send_notification(signal_data, signal_id)
            print(f"Notification sent for {signal_data['type']} signal")
        elif not settings['notifications_enabled']:
            print("Notifications disabled in settings")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Signal analyzed successfully',
                'signal': signal_data,
                'notification_sent': should_notify,
                'trade_executed': trade_executed
            })
        }
    except Exception as e:
        print(f"Lambda execution error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing request',
                'error': str(e)
            })
        }
