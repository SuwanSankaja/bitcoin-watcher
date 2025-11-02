"""
Lambda Function #2: Signal Analyzer
Analyzes recent prices, calculates moving averages, generates buy/sell signals,
and sends notifications via FCM
"""

import json
import os
from datetime import datetime, timedelta
from pymongo import MongoClient
import boto3
import firebase_admin
from firebase_admin import credentials, messaging

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
    """Get MongoDB client"""
    ssm = boto3.client('ssm')
    mongo_uri = ssm.get_parameter(
        Name='/bitcoin-watcher/mongodb-uri',
        WithDecryption=True
    )['Parameter']['Value']
    
    return MongoClient(mongo_uri)

def get_recent_prices(minutes=30):
    """Fetch recent prices from MongoDB"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['btc_prices']
        
        # Get prices from last N minutes
        cutoff_time = datetime.utcnow() - timedelta(minutes=minutes)
        
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

def analyze_signal(prices, short_period=7, long_period=21, buy_threshold=0.005, sell_threshold=0.005):
    """Analyze prices and generate trading signal"""
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
    
    # Calculate signal
    if short_ma > long_ma * (1 + buy_threshold):
        signal_type = 'BUY'
        confidence = min(((short_ma / long_ma - 1) / buy_threshold) * 100, 100)
    elif short_ma < long_ma * (1 - sell_threshold):
        signal_type = 'SELL'
        confidence = min(((1 - short_ma / long_ma) / sell_threshold) * 100, 100)
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
        
        document = {
            'timestamp': datetime.utcnow(),
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
        
        notification_doc = {
            'timestamp': datetime.utcnow(),
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
        # Fetch recent prices
        prices = get_recent_prices(minutes=30)
        
        if not prices:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No prices available'})
            }
        
        # Analyze and generate signal
        signal_data = analyze_signal(prices)
        
        # Get last signal to check if it changed
        last_signal = get_last_signal()
        
        # Store current signal
        signal_id = store_signal(signal_data)
        
        # Send notification only if signal changed and it's BUY or SELL
        should_notify = (
            signal_data['type'] in ['BUY', 'SELL'] and
            (last_signal is None or last_signal.get('type') != signal_data['type'])
        )
        
        if should_notify:
            send_notification(signal_data, signal_id)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Signal analyzed successfully',
                'signal': signal_data,
                'notification_sent': should_notify
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
