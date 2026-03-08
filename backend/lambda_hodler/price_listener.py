"""
Lambda Function #1 (Hodler): Price Listener
Fetches real-time BTC price + 24h volume from CoinGecko and stores in MongoDB
"""

import json
import os
from datetime import datetime
import pytz
import requests
from pymongo import MongoClient
import boto3


def get_mongo_client():
    """Get MongoDB client — supports Lambda (SSM) and local (.env)"""
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


def get_bitcoin_data():
    """Fetch current BTC price + 24h volume from CoinGecko API"""
    try:
        url = "https://api.coingecko.com/api/v3/simple/price"
        params = {
            "ids": "bitcoin",
            "vs_currencies": "usd",
            "include_24hr_vol": "true"
        }
        headers = {
            'User-Agent': 'Bitcoin-Watcher-Hodler/1.0',
            'Accept': 'application/json'
        }
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        price = float(data['bitcoin']['usd'])
        volume_24h = float(data['bitcoin'].get('usd_24h_vol', 0))
        return price, volume_24h
    except Exception as e:
        print(f"Error fetching Bitcoin data: {e}")
        raise


def store_price(price, volume_24h=0):
    """Store price + volume in MongoDB"""
    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['btc_prices']

        utc_now = datetime.utcnow().replace(tzinfo=pytz.UTC)
        sri_lanka_tz = pytz.timezone('Asia/Colombo')
        sri_lanka_time = utc_now.astimezone(sri_lanka_tz)
        sri_lanka_naive = sri_lanka_time.replace(tzinfo=None)

        document = {
            'timestamp': sri_lanka_naive,
            'price': price,
            'volume_24h': volume_24h
        }

        collection.insert_one(document)
        print(f"Stored price: ${price:,.2f} | Volume 24h: ${volume_24h:,.0f} at {sri_lanka_naive}")

        client.close()
        return True
    except Exception as e:
        print(f"Error storing price: {e}")
        raise


def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        price, volume_24h = get_bitcoin_data()
        store_price(price, volume_24h)

        utc_now = datetime.utcnow().replace(tzinfo=pytz.UTC)
        sri_lanka_time = utc_now.astimezone(pytz.timezone('Asia/Colombo'))

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Price stored successfully',
                'price': price,
                'volume_24h': volume_24h,
                'timestamp': sri_lanka_time.isoformat()
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
