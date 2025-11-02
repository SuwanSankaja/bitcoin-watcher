"""
Test script to send a test notification via Firebase Cloud Messaging
Uses AWS Secrets Manager to get Firebase credentials (same as Lambda)
"""

import json
import boto3
import firebase_admin
from firebase_admin import credentials, messaging

print("Fetching Firebase credentials from AWS Secrets Manager...")

try:
    secrets_client = boto3.client('secretsmanager', region_name='us-east-1')
    secret = secrets_client.get_secret_value(
        SecretId='bitcoin-watcher-firebase-creds'
    )
    cred_dict = json.loads(secret['SecretString'])
    print("✅ Credentials fetched successfully")
except Exception as e:
    print(f"❌ Error fetching credentials: {e}")
    print("\nMake sure:")
    print("  1. AWS CLI is configured with credentials")
    print("  2. Secret 'bitcoin-watcher-firebase-creds' exists in us-east-1")
    exit(1)

# Initialize Firebase Admin SDK
print("\nInitializing Firebase...")
try:
    cred = credentials.Certificate(cred_dict)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase initialized successfully")
except Exception as e:
    print(f"❌ Error initializing Firebase: {e}")
    exit(1)

# Create test notification
print("\nSending test notification...")

message = messaging.Message(
    notification=messaging.Notification(
        title="🔔 TEST: BUY Signal Detected!",
        body="BTC at $110,500.00 - Confidence 75% (TEST)",
    ),
    data={
        'signal_id': 'test_123',
        'signal_type': 'BUY',
        'price': '110500',
        'confidence': '75',
        'test': 'true',
    },
    topic='bitcoin-signals'
)

try:
    response = messaging.send(message)
    print(f"✅ Test notification sent successfully!")
    print(f"Message ID: {response}")
    print("\n📱 Check your phone - you should receive the notification within a few seconds.")
    print("\nMake sure:")
    print("  ✓ The app has been opened at least once")
    print("  ✓ Notifications are enabled in Android settings")
    print("  ✓ Your phone has internet connection")
    print("  ✓ The app subscribed to 'bitcoin-signals' topic on startup")
except Exception as e:
    print(f"❌ Error sending notification: {e}")
