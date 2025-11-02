"""
Lambda Function #1: Price Listener
Fetches real-time BTC price from Binance API and stores in MongoDB
"""

import json
import os
from datetime import datetime
import requests
from pymongo import MongoClient
import boto3

# MongoDB connection
def get_mongo_client():
    # Get MongoDB connection string from Parameter Store
    ssm = boto3.client('ssm')
    mongo_uri = ssm.get_parameter(
        Name='/bitcoin-watcher/mongodb-uri',
        WithDecryption=True
    )['Parameter']['Value']
    
    return MongoClient(mongo_uri)

def get_binance_price():
    """Fetch current BTC price from CoinGecko API (free, no auth required)"""
    try:
        # CoinGecko free API - more reliable from AWS Lambda
        url = "https://api.coingecko.com/api/v3/simple/price"
        params = {
            "ids": "bitcoin",
            "vs_currencies": "usd"
        }
        headers = {
            'User-Agent': 'Bitcoin-Watcher-App/1.0',
            'Accept': 'application/json'
        }
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        return float(data['bitcoin']['usd'])
    except Exception as e:
        print(f"Error fetching Bitcoin price: {e}")
        raise

def store_price(price):
    """Store price in MongoDB time series collection"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['btc_prices']
        
        document = {
            'timestamp': datetime.utcnow(),
            'price': price
        }
        
        collection.insert_one(document)
        print(f"Stored price: ${price} at {document['timestamp']}")
        
        client.close()
        return True
    except Exception as e:
        print(f"Error storing price: {e}")
        raise

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Fetch current BTC price
        price = get_binance_price()
        
        # Store in MongoDB
        store_price(price)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Price stored successfully',
                'price': price,
                'timestamp': datetime.utcnow().isoformat()
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
