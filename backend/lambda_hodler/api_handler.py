"""
Lambda Function #3 (Hodler): API Gateway Handler
Provides REST API endpoints for the Hodler Flutter app.
Additive over original: adds /portfolio, enriched /currentPrice signal, new settings keys.
"""

import json
import os
from datetime import datetime, timedelta
from pymongo import MongoClient
import boto3


def get_mongo_client():
    """Get MongoDB client — supports Lambda (SSM) and local (.env)"""
    mongo_uri = os.getenv('MONGODB_URI')
    if not mongo_uri:
        ssm = boto3.client('ssm')
        mongo_uri = ssm.get_parameter(
            Name='/bitcoin-watcher/mongodb-uri',
            WithDecryption=True
        )['Parameter']['Value']
    return MongoClient(mongo_uri)


def cors_headers():
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    }


# ── /currentPrice ─────────────────────────────────────────────────────────────
def get_current_price():
    """Get most recent BTC price + enriched signal (includes accumulation score)"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        price = db['btc_prices'].find_one(
            {},
            {'_id': 0, 'timestamp': 1, 'price': 1},
            sort=[('timestamp', -1)]
        )
        signal = db['signals'].find_one({}, sort=[('timestamp', -1)])
        client.close()

        if not price:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'message': 'No price data available'})
            }

        response_data = {
            'price': {
                'timestamp': price['timestamp'].isoformat(),
                'price': price['price']
            }
        }

        if signal:
            response_data['signal'] = {
                '_id': str(signal['_id']),
                'timestamp': signal['timestamp'].isoformat(),
                'type': signal['type'],
                'price': signal['price'],
                'confidence': signal.get('confidence', 0),
                # Hodler-specific fields (may be None for old prod signals)
                'accumulation_score': signal.get('accumulation_score'),
                'buy_zone': signal.get('buy_zone'),
                'rsi': signal.get('rsi'),
                'bb_lower': signal.get('bb_lower'),
                'fear_greed_index': signal.get('fear_greed_index'),
                'fear_greed_label': signal.get('fear_greed_label'),
                'dip_depth': signal.get('dip_depth'),
            }
        else:
            response_data['signal'] = None

        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps(response_data, default=str)
        }
    except Exception as e:
        print(f"Error in get_current_price: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }


# ── /priceHistory ─────────────────────────────────────────────────────────────
def get_price_history(hours=24):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)

        prices = list(db['btc_prices'].find(
            {'timestamp': {'$gte': cutoff_time}},
            {'_id': 0, 'timestamp': 1, 'price': 1}
        ).sort('timestamp', 1))

        client.close()

        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'prices': [
                    {'timestamp': p['timestamp'].isoformat(), 'price': p['price']}
                    for p in prices
                ]
            })
        }
    except Exception as e:
        print(f"Error in get_price_history: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }


# ── /signalHistory ────────────────────────────────────────────────────────────
def get_signal_history(limit=50):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        notifications = list(db['notifications'].find(
            {},
            {'_id': 1, 'timestamp': 1, 'signal_id': 1, 'title': 1, 'message': 1,
             'signal_type': 1, 'price': 1, 'accumulation_score': 1}
        ).sort('timestamp', -1).limit(limit))

        client.close()

        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'notifications': [
                    {
                        '_id': str(n['_id']),
                        'timestamp': n['timestamp'].isoformat(),
                        'signal_id': n.get('signal_id', ''),
                        'title': n.get('title', ''),
                        'message': n.get('message', ''),
                        'signal_type': n.get('signal_type', 'HOLD'),
                        'price': n.get('price', 0),
                        'accumulation_score': n.get('accumulation_score'),
                    }
                    for n in notifications
                ]
            })
        }
    except Exception as e:
        print(f"Error in get_signal_history: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }


# ── /tradesHistory ────────────────────────────────────────────────────────────
def get_trades_history(limit=50):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        filled = list(db['trades'].find(
            {},
            {'_id': 1, 'timestamp': 1, 'signal_id': 1, 'side': 1, 'symbol': 1,
             'executed_qty': 1, 'average_price': 1, 'signal_price': 1,
             'signal_confidence': 1, 'accumulation_score': 1, 'usdt_spent': 1,
             'status': 1, 'btc_balance_after': 1}
        ).sort('timestamp', -1).limit(limit))

        failed = list(db['failed_trades'].find(
            {},
            {'_id': 1, 'timestamp': 1, 'signal_id': 1, 'signal_type': 1,
             'signal_price': 1, 'accumulation_score': 1, 'error': 1}
        ).sort('timestamp', -1).limit(limit))

        client.close()

        formatted = []
        for t in filled:
            formatted.append({
                '_id': str(t['_id']),
                'timestamp': t['timestamp'].isoformat(),
                'signal_id': t.get('signal_id', ''),
                'side': t.get('side', ''),
                'symbol': t.get('symbol', 'BTCUSDT'),
                'executed_qty': t.get('executed_qty', 0),
                'average_price': t.get('average_price', 0),
                'signal_price': t.get('signal_price', 0),
                'signal_confidence': t.get('signal_confidence', 0),
                'accumulation_score': t.get('accumulation_score'),
                'usdt_spent': t.get('usdt_spent'),
                'status': t.get('status', 'FILLED'),
                'btc_balance_after': t.get('btc_balance_after'),
                'error': None,
            })

        for t in failed:
            formatted.append({
                '_id': str(t['_id']),
                'timestamp': t['timestamp'].isoformat(),
                'signal_id': t.get('signal_id', ''),
                'side': t.get('signal_type', ''),
                'symbol': 'BTCUSDT',
                'executed_qty': 0,
                'average_price': 0,
                'signal_price': t.get('signal_price', 0),
                'signal_confidence': 0,
                'accumulation_score': t.get('accumulation_score'),
                'usdt_spent': None,
                'status': 'FAILED',
                'error': t.get('error', 'Unknown error'),
            })

        formatted.sort(key=lambda x: x['timestamp'], reverse=True)
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'trades': formatted[:limit]})
        }
    except Exception as e:
        print(f"Error in get_trades_history: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }


# ── /portfolio (NEW) ──────────────────────────────────────────────────────────
def get_portfolio():
    """
    Aggregate all BUY trades to compute BTC stack metrics:
    total_btc_accumulated, total_usdt_spent, average_cost_basis,
    current_value (using latest price), unrealized_pnl_percent.
    """
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        # All filled BUY trades
        buy_trades = list(db['trades'].find(
            {'side': 'BUY', 'status': 'FILLED'},
            {'_id': 0, 'executed_qty': 1, 'average_price': 1, 'usdt_spent': 1,
             'timestamp': 1, 'accumulation_score': 1}
        ).sort('timestamp', 1))

        # Latest price
        latest_price_doc = db['btc_prices'].find_one(
            {}, {'_id': 0, 'price': 1}, sort=[('timestamp', -1)]
        )

        client.close()

        total_btc = sum(t.get('executed_qty', 0) for t in buy_trades)
        # Use usdt_spent if available (scaled DCA buys), otherwise estimate from qty × avg_price
        total_usdt = sum(
            t.get('usdt_spent') or (t.get('executed_qty', 0) * t.get('average_price', 0))
            for t in buy_trades
        )

        avg_cost_basis = (total_usdt / total_btc) if total_btc > 0 else 0
        current_price = latest_price_doc['price'] if latest_price_doc else 0
        current_value = total_btc * current_price
        pnl_percent = (
            ((current_value - total_usdt) / total_usdt * 100)
            if total_usdt > 0 else 0
        )

        # Per-trade history for accumulation chart
        cumulative_btc = 0
        trade_history = []
        for t in buy_trades:
            cumulative_btc += t.get('executed_qty', 0)
            trade_history.append({
                'timestamp': t['timestamp'].isoformat(),
                'btc_acquired': round(t.get('executed_qty', 0), 8),
                'cumulative_btc': round(cumulative_btc, 8),
                'average_price': round(t.get('average_price', 0), 2),
                'accumulation_score': t.get('accumulation_score'),
            })

        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({
                'total_btc_accumulated': round(total_btc, 8),
                'total_usdt_spent': round(total_usdt, 2),
                'average_cost_basis': round(avg_cost_basis, 2),
                'current_btc_price': round(current_price, 2),
                'current_value': round(current_value, 2),
                'unrealized_pnl_percent': round(pnl_percent, 4),
                'trade_count': len(buy_trades),
                'trade_history': trade_history,
            })
        }
    except Exception as e:
        print(f"Error in get_portfolio: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }


# ── /settings ─────────────────────────────────────────────────────────────────
def get_settings():
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        settings_doc = db['settings'].find_one({'_id': 'hodler_default'})
        if not settings_doc:
            settings_doc = db['settings'].find_one({'_id': 'default'})
        client.close()

        default_settings = {
            'notifications_enabled': True,
            'buy_threshold': 0.001,
            'short_ma_period': 7,
            'long_ma_period': 25,
            'rsi_period': 14,
            'rsi_overbought': 70,
            'rsi_oversold': 30,
            'bb_period': 20,
            'bb_std_dev': 2.0,
            'min_score_threshold': 60,
            'lookback_hours': 4,
            'trading_enabled': False,
            'trading_mode': 'testnet',
            'trade_amount_usdt': 20,
            'dca_scale_factor': 1.5,
            'max_single_trade_usdt': 200,
        }

        if settings_doc and 'settings' in settings_doc:
            default_settings.update(settings_doc['settings'])

        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'settings': default_settings})
        }
    except Exception as e:
        print(f"Error in get_settings: {e}")
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'settings': {
                'notifications_enabled': True,
                'buy_threshold': 0.001,
                'short_ma_period': 7,
                'long_ma_period': 25,
                'min_score_threshold': 60,
                'dca_scale_factor': 1.5,
                'max_single_trade_usdt': 200,
                'lookback_hours': 4,
            }})
        }


def update_settings(body):
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']

        settings = {
            'notifications_enabled': body.get('notifications_enabled', True),
            'buy_threshold': float(body.get('buy_threshold', 0.001)),
            'short_ma_period': int(body.get('short_ma_period', 7)),
            'long_ma_period': int(body.get('long_ma_period', 25)),
            'rsi_period': int(body.get('rsi_period', 14)),
            'rsi_overbought': int(body.get('rsi_overbought', 70)),
            'rsi_oversold': int(body.get('rsi_oversold', 30)),
            'bb_period': int(body.get('bb_period', 20)),
            'bb_std_dev': float(body.get('bb_std_dev', 2.0)),
            'min_score_threshold': int(body.get('min_score_threshold', 60)),
            'lookback_hours': int(body.get('lookback_hours', 4)),
            'trading_enabled': body.get('trading_enabled', False),
            'trading_mode': body.get('trading_mode', 'testnet'),
            'trade_amount_usdt': float(body.get('trade_amount_usdt', 20)),
            'dca_scale_factor': float(body.get('dca_scale_factor', 1.5)),
            'max_single_trade_usdt': float(body.get('max_single_trade_usdt', 200)),
        }

        db['settings'].update_one(
            {'_id': 'hodler_default'},
            {'$set': {'settings': settings, 'updated_at': datetime.utcnow()}},
            upsert=True
        )
        client.close()

        print(f"Hodler settings updated: {settings}")
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Settings updated successfully', 'settings': settings})
        }
    except Exception as e:
        print(f"Error in update_settings: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Failed to update settings', 'error': str(e)})
        }


# ── Lambda handler ─────────────────────────────────────────────────────────────
def lambda_handler(event, context):
    """Main Lambda handler for API Gateway — Hodler Edition"""
    try:
        if event.get('httpMethod') == 'OPTIONS':
            return {'statusCode': 200, 'headers': cors_headers(), 'body': ''}

        path = event.get('resource') or event.get('path', '')
        path = path.replace('/prod', '').replace('/test-invoke-stage', '')
        method = event.get('httpMethod', 'GET')
        query_params = event.get('queryStringParameters') or {}

        print(f"Hodler API: {method} {path}")

        if path == '/currentPrice' and method == 'GET':
            return get_current_price()

        elif path == '/priceHistory' and method == 'GET':
            hours = int(query_params.get('hours', 24))
            return get_price_history(hours)

        elif path == '/signalHistory' and method == 'GET':
            limit = int(query_params.get('limit', 50))
            return get_signal_history(limit)

        elif path == '/tradesHistory' and method == 'GET':
            limit = int(query_params.get('limit', 50))
            return get_trades_history(limit)

        elif path == '/portfolio' and method == 'GET':
            return get_portfolio()

        elif path == '/settings' and method == 'GET':
            return get_settings()

        elif path == '/settings' and method == 'POST':
            body = json.loads(event.get('body', '{}'))
            return update_settings(body)

        else:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({
                    'message': 'Endpoint not found',
                    'path': path,
                    'method': method,
                })
            }

    except Exception as e:
        print(f"Lambda execution error: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }
