# Bitcoin Watcher - Complete Setup Guide

This guide will walk you through setting up the entire Bitcoin Watcher application from scratch.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [MongoDB Atlas Setup](#mongodb-atlas-setup)
3. [AWS Setup](#aws-setup)
4. [Firebase Setup](#firebase-setup)
5. [Flutter App Setup](#flutter-app-setup)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts (All Free Tier)
- AWS Account
- MongoDB Atlas Account
- Firebase/Google Cloud Account

### Required Software
- Flutter SDK 3.0+
- Python 3.11+
- AWS CLI
- Git
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

### Installation Commands

**Flutter:**
```bash
# Download from https://flutter.dev/docs/get-started/install
flutter doctor
```

**AWS CLI:**
```bash
# Download from https://aws.amazon.com/cli/
aws --version
```

**Python:**
```bash
python --version  # Should be 3.11+
pip --version
```

---

## MongoDB Atlas Setup

### Step 1: Create Cluster

1. Go to https://cloud.mongodb.com/
2. Sign up or log in
3. Click **"Build a Database"**
4. Select **FREE** tier (M0 Sandbox)
5. Choose cloud provider (AWS recommended) and region (closest to you)
6. Name your cluster: `bitcoin-watcher`
7. Click **"Create"**

### Step 2: Configure Network Access

1. Navigate to **Security → Network Access**
2. Click **"Add IP Address"**
3. Choose **"Allow Access from Anywhere"** (0.0.0.0/0)
   - For production, use specific AWS Lambda IP ranges
4. Click **"Confirm"**

### Step 3: Create Database User

1. Navigate to **Security → Database Access**
2. Click **"Add New Database User"**
3. Choose **"Password"** authentication method
4. Username: `bitcoin_watcher_user`
5. Generate a strong password (save it!)
6. Database User Privileges: **"Read and write to any database"**
7. Click **"Add User"**

### Step 4: Create Collections

1. Click **"Browse Collections"** on your cluster
2. Click **"Add My Own Data"**
3. Database name: `bitcoin_watcher`
4. Create three collections:

**Collection 1: btc_prices (Time Series)**
```javascript
db.createCollection("btc_prices", {
  timeseries: {
    timeField: "timestamp",
    granularity: "seconds"
  }
});
db.btc_prices.createIndex({ "timestamp": -1 });
```

**Collection 2: signals**
```javascript
db.createCollection("signals");
db.signals.createIndex({ "timestamp": -1 });
db.signals.createIndex({ "type": 1 });
```

**Collection 3: notifications**
```javascript
db.createCollection("notifications");
db.notifications.createIndex({ "timestamp": -1 });
db.notifications.createIndex({ "signal_id": 1 });
```

### Step 5: Get Connection String

1. Click **"Connect"** on your cluster
2. Choose **"Connect your application"**
3. Driver: Python, Version: 3.6 or later
4. Copy the connection string
5. Replace `<password>` with your user's password

Example:
```
mongodb+srv://bitcoin_watcher_user:YOUR_PASSWORD@bitcoin-watcher.xxxxx.mongodb.net/bitcoin_watcher?retryWrites=true&w=majority
```

**Save this connection string - you'll need it later!**

---

## AWS Setup

### Step 1: Configure AWS CLI

```bash
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### Step 2: Create IAM Role for Lambda

Create a role with necessary permissions:

```bash
# Create trust policy file
cat > lambda-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role \
  --role-name bitcoin-watcher-lambda-role \
  --assume-role-policy-document file://lambda-trust-policy.json

# Attach necessary policies
aws iam attach-role-policy \
  --role-name bitcoin-watcher-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name bitcoin-watcher-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess

aws iam attach-role-policy \
  --role-name bitcoin-watcher-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

### Step 3: Store MongoDB Connection String

```bash
aws ssm put-parameter \
  --name "/bitcoin-watcher/mongodb-uri" \
  --value "YOUR_MONGODB_CONNECTION_STRING" \
  --type "SecureString" \
  --description "MongoDB connection string for Bitcoin Watcher"
```

Replace `YOUR_MONGODB_CONNECTION_STRING` with your actual connection string from MongoDB Atlas.

### Step 4: Deploy Lambda Functions

Navigate to the backend directory and run:

**On Windows (PowerShell):**
```powershell
cd backend
.\scripts\deploy.ps1
```

**On Linux/Mac:**
```bash
cd backend
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

This will:
- Package all Lambda functions
- Deploy them to AWS
- Set up EventBridge triggers
- Configure permissions

### Step 5: Set Up API Gateway

1. Go to AWS Console → API Gateway
2. Click **"Create API"**
3. Choose **"REST API"** → **"Build"**
4. API name: `bitcoin-watcher-api`
5. Click **"Create API"**

**Create Endpoints:**

For each endpoint, follow these steps:

1. Click **"Actions"** → **"Create Resource"**
2. Resource Name: `currentPrice` (or other endpoint name)
3. Click **"Create Resource"**
4. Click **"Actions"** → **"Create Method"** → **"GET"**
5. Integration type: **Lambda Function**
6. Lambda Function: `bitcoin-watcher-api-handler`
7. Click **"Save"**
8. Enable CORS: **"Actions"** → **"Enable CORS"** → **"Enable"**

Create these resources:
- `/currentPrice` (GET)
- `/priceHistory` (GET)
- `/signalHistory` (GET)
- `/settings` (GET, POST)

**Deploy API:**

1. Click **"Actions"** → **"Deploy API"**
2. Deployment stage: **New Stage** → `prod`
3. Click **"Deploy"**
4. Copy the **Invoke URL** (e.g., `https://xxxxx.execute-api.us-east-1.amazonaws.com/prod`)

**Save this URL - you'll need it for the Flutter app!**

---

## Firebase Setup

### Step 1: Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click **"Add project"**
3. Project name: `Bitcoin Watcher`
4. Disable Google Analytics (optional)
5. Click **"Create project"**

### Step 2: Add Android App

1. In project overview, click Android icon
2. Android package name: `com.example.bitcoin_watcher`
3. Click **"Register app"**
4. Download `google-services.json`
5. Place it in `android/app/` directory

### Step 3: Add iOS App (if developing for iOS)

1. Click iOS icon
2. iOS bundle ID: `com.example.bitcoinWatcher`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory

### Step 4: Enable Cloud Messaging

1. Go to **Project Settings** → **Cloud Messaging**
2. Under **Cloud Messaging API**, click **"Enable"**
3. Copy the **Server Key** (save it for later)

### Step 5: Generate Service Account Key

1. Go to **Project Settings** → **Service Accounts**
2. Click **"Generate New Private Key"**
3. Download the JSON file
4. This contains your Firebase Admin SDK credentials

### Step 6: Store Firebase Credentials in AWS

```bash
# Store Firebase Admin SDK credentials
aws secretsmanager create-secret \
  --name bitcoin-watcher-firebase-creds \
  --description "Firebase Admin SDK credentials" \
  --secret-string file://path/to/your-firebase-adminsdk.json
```

### Step 7: Create FCM Topic

The app will auto-subscribe users to the `bitcoin-signals` topic for notifications.

---

## Flutter App Setup

### Step 1: Get Dependencies

```bash
cd bitcoin-watcher
flutter pub get
```

### Step 2: Configure API URL

Edit `lib/utils/api_config.dart`:

```dart
static const String baseUrl = 'https://YOUR-API-GATEWAY-URL.amazonaws.com/prod';
```

Replace with your actual API Gateway URL from AWS setup.

### Step 3: Android Configuration

Edit `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Required for Firebase
        targetSdkVersion 33
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.1.0'
}
```

At the bottom of the file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

Edit `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

### Step 4: iOS Configuration (macOS only)

Edit `ios/Runner/Info.plist`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### Step 5: Run the App

**Android:**
```bash
flutter run
```

**iOS:**
```bash
cd ios
pod install
cd ..
flutter run
```

---

## Testing

### Test Lambda Functions

1. Go to AWS Console → Lambda
2. Select `bitcoin-watcher-price-listener`
3. Click **"Test"** → Create test event → **"Test"**
4. Check CloudWatch Logs for output

### Test MongoDB

1. Go to MongoDB Atlas → Collections
2. Check `btc_prices` collection for new entries
3. Should see price data being inserted every minute

### Test API

```bash
# Test current price endpoint
curl https://YOUR-API-GATEWAY-URL.amazonaws.com/prod/currentPrice

# Test price history
curl https://YOUR-API-GATEWAY-URL.amazonaws.com/prod/priceHistory?hours=1

# Test signal history
curl https://YOUR-API-GATEWAY-URL.amazonaws.com/prod/signalHistory?limit=10
```

### Test Flutter App

1. Launch the app
2. Home screen should show current BTC price
3. Chart should display 24-hour trend
4. Navigate to History screen (should be empty initially)
5. Navigate to Settings screen and adjust thresholds

### Test Notifications

1. Wait for a BUY or SELL signal to be generated
2. You should receive a push notification
3. Check History screen for the notification entry

---

## Troubleshooting

### Flutter App Issues

**"Firebase not initialized"**
```bash
# Ensure google-services.json is in android/app/
# Rebuild the app
flutter clean
flutter pub get
flutter run
```

**"API call failed"**
- Check API Gateway URL in `api_config.dart`
- Verify API Gateway is deployed
- Check Lambda function logs in CloudWatch

### Lambda Function Issues

**"Unable to connect to MongoDB"**
- Verify MongoDB connection string in Parameter Store
- Check MongoDB Atlas Network Access (allow 0.0.0.0/0)
- Verify database user credentials

**"Module not found"**
- Redeploy with all dependencies: `pip install -r requirements.txt -t ./packages/`

### MongoDB Issues

**"Authentication failed"**
- Verify database user credentials
- Check user has read/write permissions

**"No data in collections"**
- Check Lambda function logs for errors
- Verify EventBridge rules are enabled
- Manually invoke price_listener function to test

### Notification Issues

**"No notifications received"**
- Verify Firebase Cloud Messaging is enabled
- Check Firebase credentials in Secrets Manager
- Verify app has notification permissions
- Check if user is subscribed to `bitcoin-signals` topic

### Cost Monitoring

All services used are free tier:
- AWS Lambda: 1M requests/month free
- API Gateway: 1M requests/month free
- MongoDB Atlas: 512MB storage free
- Firebase: Free for notifications

Monitor your usage:
- AWS: CloudWatch → Billing Dashboard
- MongoDB: Atlas → Metrics
- Firebase: Console → Usage

---

## Production Recommendations

1. **Security:**
   - Restrict MongoDB Network Access to AWS IP ranges
   - Use API Gateway API Keys or AWS Cognito for authentication
   - Enable AWS CloudTrail for audit logging

2. **Monitoring:**
   - Set up CloudWatch Alarms for Lambda errors
   - Monitor MongoDB Atlas metrics
   - Use AWS X-Ray for request tracing

3. **Optimization:**
   - Adjust EventBridge schedules based on usage
   - Implement data retention policies in MongoDB
   - Use API Gateway caching to reduce Lambda invocations

4. **Scaling:**
   - Consider MongoDB Atlas M2+ tier for production
   - Use Lambda Reserved Concurrency if needed
   - Implement rate limiting in API Gateway

---

## Support

For issues or questions:
- Check AWS CloudWatch Logs
- Review MongoDB Atlas logs
- Check Flutter logs: `flutter logs`
- Review this documentation

---

## Next Steps

1. Customize the algorithm in `signal_analyzer.py`
2. Add more technical indicators (RSI, MACD, etc.)
3. Implement user authentication
4. Add portfolio tracking features
5. Support multiple cryptocurrencies
