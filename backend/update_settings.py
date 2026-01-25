import os
import sys
from dotenv import load_dotenv
from pymongo import MongoClient
import certifi

# Load environment variables
load_dotenv()

def print_header(msg):
    print(f"\n{'='*50}")
    print(f" {msg}")
    print(f"{'='*50}")

def get_mongo_client():
    uri = os.getenv('MONGODB_URI')
    if not uri:
        raise ValueError("MONGODB_URI not found in .env")
    return MongoClient(uri, tlsCAFile=certifi.where())

def main():
    print_header("UPDATING TRADING SETTINGS")

    # The NEW recommended settings
    new_settings = {
        'buy_threshold': 0.003,       # 0.3% (Conservative price dip)
        'sell_threshold': 0.003,      # 0.3% (Conservative price peak)
        'short_ma_period': 7,         # 7 Minutes (Less noise)
        'long_ma_period': 25,         # 25 Minutes (Reliable trend)
        'rsi_period': 14,             # RSI 14 (Standard)
        'rsi_overbought': 70,         # Sell zone
        'rsi_oversold': 30,           # Buy zone
        'trading_enabled': True,      # Ensure bot is ON
        'trading_mode': 'testnet',
        'notifications_enabled': True,
        'trade_amount_usdt': 20,      # Consistent trade size
        'sell_percentage': 100
    }

    try:
        client = get_mongo_client()
        db = client['bitcoin_watcher']
        collection = db['settings']

        print("Connecting to MongoDB...")
        
        # Upsert the settings
        result = collection.update_one(
            {'_id': 'default'},
            {'$set': {'settings': new_settings}},
            upsert=True
        )

        print("\n✅ Settings Updated Successfully!")
        print("New Configuration:")
        for key, value in new_settings.items():
            print(f"   {key:<20}: {value}")

        if result.modified_count > 0:
            print("\n(Database document was modified)")
        elif result.upserted_id:
            print("\n(New document created)")
        else:
            print("\n(No changes needed - already up to date)")

        client.close()

    except Exception as e:
        print(f"\n❌ Failed to update settings: {e}")

if __name__ == "__main__":
    main()
