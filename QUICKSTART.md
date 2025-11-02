# Quick Start Guide - Bitcoin Watcher

Get your Bitcoin Watcher app running in 30 minutes!

## Prerequisites Checklist

- [ ] Flutter SDK installed
- [ ] Python 3.11+ installed
- [ ] AWS CLI configured
- [ ] MongoDB Atlas account
- [ ] Firebase account

## Step-by-Step Setup

### 1. MongoDB (5 minutes)

```bash
# 1. Go to https://cloud.mongodb.com/
# 2. Create free cluster "bitcoin-watcher"
# 3. Add database user
# 4. Allow network access (0.0.0.0/0)
# 5. Get connection string
```

Connection string format:
```
mongodb+srv://USER:PASSWORD@cluster.xxxxx.mongodb.net/bitcoin_watcher
```

### 2. AWS Setup (10 minutes)

```bash
# Create IAM role
aws iam create-role \
  --role-name bitcoin-watcher-lambda-role \
  --assume-role-policy-document file://backend/scripts/trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name bitcoin-watcher-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Store MongoDB URI
aws ssm put-parameter \
  --name "/bitcoin-watcher/mongodb-uri" \
  --value "YOUR_MONGODB_CONNECTION_STRING" \
  --type "SecureString"

# Deploy Lambda functions
cd backend
./scripts/deploy.sh  # Linux/Mac
# OR
.\scripts\deploy.ps1  # Windows
```

### 3. API Gateway (5 minutes)

```bash
# AWS Console → API Gateway → Create API
# 1. REST API → Build
# 2. Name: "bitcoin-watcher-api"
# 3. Create resources: /currentPrice, /priceHistory, /signalHistory, /settings
# 4. Link to lambda: bitcoin-watcher-api-handler
# 5. Enable CORS
# 6. Deploy to stage "prod"
# 7. Copy Invoke URL
```

### 4. Firebase (5 minutes)

```bash
# 1. Go to https://console.firebase.google.com/
# 2. Create project "Bitcoin Watcher"
# 3. Add Android app: com.example.bitcoin_watcher
# 4. Download google-services.json → android/app/
# 5. Enable Cloud Messaging
# 6. Generate service account key
# 7. Store in AWS:

aws secretsmanager create-secret \
  --name bitcoin-watcher-firebase-creds \
  --secret-string file://firebase-adminsdk.json
```

### 5. Flutter App (5 minutes)

```bash
# Update API URL
# Edit lib/utils/api_config.dart:
# static const String baseUrl = 'YOUR_API_GATEWAY_URL';

# Get dependencies
flutter pub get

# Run app
flutter run
```

## Verification

### Test Backend
```bash
# Check if price listener is working
aws lambda invoke \
  --function-name bitcoin-watcher-price-listener \
  --log-type Tail \
  output.json

# View logs
aws logs tail /aws/lambda/bitcoin-watcher-price-listener --follow
```

### Test API
```bash
curl https://YOUR_API_GATEWAY_URL/prod/currentPrice
```

### Test App
1. Open app
2. Should see BTC price on home screen
3. Wait 2-5 minutes for data to populate
4. Check History screen for signals

## Common Issues

**"Firebase not initialized"**
```bash
flutter clean
flutter pub get
flutter run
```

**"API Gateway 403 error"**
- Check CORS is enabled
- Verify Lambda permissions

**"No price data"**
- Check Lambda logs in CloudWatch
- Verify MongoDB connection
- Check EventBridge rules are enabled

**"No notifications"**
- Verify Firebase Cloud Messaging enabled
- Check app notification permissions
- Verify Firebase credentials in Secrets Manager

## Cost Estimate

**Monthly Cost: $0** (using free tiers)

- AWS Lambda: 1M requests/month free ✓
- API Gateway: 1M requests/month free ✓
- MongoDB Atlas: 512MB storage free ✓
- Firebase: Unlimited notifications free ✓

## Next Steps

1. ✅ App running locally
2. 📱 Build release APK: `flutter build apk --release`
3. 🚀 Deploy to Play Store (optional)
4. 📈 Monitor usage in AWS Console
5. 🎨 Customize UI and thresholds

## Full Documentation

For detailed setup, see [SETUP_GUIDE.md](SETUP_GUIDE.md)

## Support

- AWS CloudWatch Logs: Check Lambda errors
- MongoDB Atlas Logs: Check database issues
- Flutter logs: `flutter logs`
