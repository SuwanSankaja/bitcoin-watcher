"""
Lambda Function #3: API Gateway Handler
Provides REST API endpoints for the Flutter app
"""

import json
import os
from datetime import datetime, timedelta
from pymongo import MongoClient
import boto3

def get_mongo_client():
    """Get MongoDB client"""
    ssm = boto3.client('ssm')
    mongo_uri = ssm.get_parameter(
        Name='/bitcoin-watcher/mongodb-uri',
        WithDecryption=True
    )['Parameter']['Value']
    
    return MongoClient(mongo_uri)

def cors_headers():
    """Return CORS headers"""
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    }

def get_current_price():
    """Get the most recent BTC price and signal"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        
        # Get latest price
        price = db['btc_prices'].find_one(
            {},
            {'_id': 0, 'timestamp': 1, 'price': 1},
            sort=[('timestamp', -1)]
        )
        
        # Get latest signal
        signal = db['signals'].find_one(
            {},
            sort=[('timestamp', -1)]
        )
        
        client.close()
        
        if not price:
            return {
                'statusCode': 404,
                'headers': cors_headers(),
                'body': json.dumps({'message': 'No price data available'})
            }
        
        # Build response - signal can be null if not generated yet
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
                'confidence': signal['confidence']
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

def get_price_history(hours=24):
    """Get price history for chart"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['btc_prices']
        
        # Get prices from last N hours
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        
        prices = list(collection.find(
            {'timestamp': {'$gte': cutoff_time}},
            {'_id': 0, 'timestamp': 1, 'price': 1}
        ).sort('timestamp', 1))
        
        client.close()
        
        # Format for JSON response
        formatted_prices = [
            {
                'timestamp': p['timestamp'].isoformat(),
                'price': p['price']
            }
            for p in prices
        ]
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'prices': formatted_prices})
        }
    except Exception as e:
        print(f"Error in get_price_history: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }

def get_signal_history(limit=50):
    """Get notification/signal history"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['notifications']
        
        notifications = list(collection.find(
            {},
            {'_id': 1, 'timestamp': 1, 'signal_id': 1, 'title': 1, 'message': 1, 'signal_type': 1, 'price': 1}
        ).sort('timestamp', -1).limit(limit))
        
        client.close()
        
        # Format for JSON response
        formatted_notifications = [
            {
                '_id': str(n['_id']),
                'timestamp': n['timestamp'].isoformat(),
                'signal_id': n.get('signal_id', ''),
                'title': n.get('title', ''),
                'message': n.get('message', ''),
                'signal_type': n.get('signal_type', 'HOLD'),
                'price': n.get('price', 0)
            }
            for n in notifications
        ]
        
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'notifications': formatted_notifications})
        }
    except Exception as e:
        print(f"Error in get_signal_history: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Internal server error', 'error': str(e)})
        }

def get_settings():
    """Get user settings (default values for now)"""
    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({
            'settings': {
                'notifications_enabled': True,
                'buy_threshold': 0.005,
                'sell_threshold': 0.005,
                'short_ma_period': 7,
                'long_ma_period': 21
            }
        })
    }

def update_settings(body):
    """Update user settings"""
    # For now, just acknowledge the update
    # In production, you'd store these in a settings collection
    return {
        'statusCode': 200,
        'headers': cors_headers(),
        'body': json.dumps({
            'message': 'Settings updated successfully'
        })
    }

def lambda_handler(event, context):
    """Main Lambda handler for API Gateway"""
    try:
        # Handle CORS preflight
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers(),
                'body': ''
            }
        
        # Get the route - try multiple path sources
        path = event.get('resource') or event.get('path', '')
        path = path.replace('/prod', '').replace('/test-invoke-stage', '')
        method = event.get('httpMethod', 'GET')
        query_params = event.get('queryStringParameters') or {}
        
        print(f"Path: {path}, Method: {method}, Event: {json.dumps(event)}")  # Debug logging
        
        # Route requests
        if path == '/currentPrice' and method == 'GET':
            return get_current_price()
        
        elif path == '/priceHistory' and method == 'GET':
            hours = int(query_params.get('hours', 24))
            return get_price_history(hours)
        
        elif path == '/signalHistory' and method == 'GET':
            limit = int(query_params.get('limit', 50))
            return get_signal_history(limit)
        
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
                    'resource': event.get('resource'),
                    'rawPath': event.get('path')
                })
            }
    
    except Exception as e:
        print(f"Lambda execution error: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({
                'message': 'Internal server error',
                'error': str(e)
            })
        }
