"""
Test script to check current settings in MongoDB
"""
import os
from pymongo import MongoClient

# Replace with your MongoDB connection string
MONGO_URI = "your-mongodb-connection-string-here"

def check_settings():
    """Check current settings in MongoDB"""
    try:
        client = MongoClient(MONGO_URI)
        db = client['bitcoin_watcher']
        collection = db['settings']
        
        # Get the settings document
        settings_doc = collection.find_one({'_id': 'default'})
        
        if settings_doc:
            print("✅ Settings found in MongoDB:")
            print("-" * 50)
            print(f"Document ID: {settings_doc['_id']}")
            print(f"\nSettings:")
            for key, value in settings_doc.get('settings', {}).items():
                print(f"  {key}: {value}")
            print(f"\nLast Updated: {settings_doc.get('updated_at', 'N/A')}")
            print("-" * 50)
        else:
            print("❌ No settings document found in MongoDB")
            print("The Lambda will use default values")
        
        client.close()
        
    except Exception as e:
        print(f"❌ Error connecting to MongoDB: {e}")

if __name__ == "__main__":
    print("Checking Bitcoin Watcher Settings in MongoDB...\n")
    check_settings()
