# Bitcoin Watcher - Setup Checklist

Use this checklist to ensure you complete all setup steps correctly.

## Pre-Setup Checklist

### Software Installation
- [ ] Flutter SDK installed and working (`flutter doctor` passes)
- [ ] Python 3.11+ installed (`python --version`)
- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] Git installed
- [ ] Android Studio installed (for Android)
- [ ] Xcode installed (for iOS, macOS only)

### Account Creation
- [ ] AWS account created
- [ ] MongoDB Atlas account created
- [ ] Firebase/Google Cloud account created
- [ ] Binance account (optional, for personal API keys)

## MongoDB Atlas Setup (15 minutes)

- [ ] Logged into MongoDB Atlas
- [ ] Created new cluster named "bitcoin-watcher"
- [ ] Selected FREE tier (M0)
- [ ] Chosen region closest to AWS Lambda region
- [ ] Cluster created successfully

### Network & Security
- [ ] Added IP address 0.0.0.0/0 to Network Access (or specific AWS IPs)
- [ ] Created database user: `bitcoin_watcher_user`
- [ ] Saved user password securely
- [ ] User has "Read and write to any database" permissions

### Database Setup
- [ ] Created database named `bitcoin_watcher`
- [ ] Created collection `btc_prices` (time series)
- [ ] Created collection `signals`
- [ ] Created collection `notifications`
- [ ] Created indexes on timestamp fields
- [ ] Obtained connection string
- [ ] Tested connection (optional: using MongoDB Compass)

**Connection String**: `mongodb+srv://username:password@cluster.xxxxx.mongodb.net/bitcoin_watcher`

## AWS Setup (20 minutes)

### AWS CLI Configuration
- [ ] Configured AWS CLI: `aws configure`
- [ ] Entered Access Key ID
- [ ] Entered Secret Access Key
- [ ] Set region (e.g., us-east-1)
- [ ] Tested CLI: `aws sts get-caller-identity`

### IAM Role Creation
- [ ] Created IAM role: `bitcoin-watcher-lambda-role`
- [ ] Attached policy: `AWSLambdaBasicExecutionRole`
- [ ] Attached policy: `AmazonSSMReadOnlyAccess`
- [ ] Attached policy: `SecretsManagerReadWrite`
- [ ] Verified role exists in IAM console

### Parameter Store
- [ ] Stored MongoDB URI in Parameter Store:
  ```bash
  aws ssm put-parameter \
    --name "/bitcoin-watcher/mongodb-uri" \
    --value "YOUR_MONGODB_CONNECTION_STRING" \
    --type "SecureString"
  ```
- [ ] Verified parameter exists: `aws ssm get-parameter --name "/bitcoin-watcher/mongodb-uri"`

### Lambda Deployment
- [ ] Navigated to backend directory: `cd backend`
- [ ] Installed Python dependencies: `pip install -r requirements.txt`
- [ ] Ran deployment script:
  - Windows: `.\scripts\deploy.ps1`
  - Linux/Mac: `./scripts/deploy.sh`
- [ ] Verified functions created:
  - [ ] `bitcoin-watcher-price-listener`
  - [ ] `bitcoin-watcher-signal-analyzer`
  - [ ] `bitcoin-watcher-api-handler`
- [ ] Checked CloudWatch logs for any errors

### EventBridge Rules
- [ ] EventBridge rule created: `bitcoin-watcher-price-trigger` (rate: 1 minute)
- [ ] EventBridge rule created: `bitcoin-watcher-signal-trigger` (rate: 2 minutes)
- [ ] Both rules are ENABLED
- [ ] Permissions added for EventBridge to invoke Lambda

### API Gateway Setup
- [ ] Created REST API named `bitcoin-watcher-api`
- [ ] Created resource: `/currentPrice` (GET method)
- [ ] Created resource: `/priceHistory` (GET method)
- [ ] Created resource: `/signalHistory` (GET method)
- [ ] Created resource: `/settings` (GET and POST methods)
- [ ] Linked all methods to `bitcoin-watcher-api-handler`
- [ ] Enabled CORS on all resources
- [ ] Deployed API to stage: `prod`
- [ ] Copied Invoke URL: `https://xxxxx.execute-api.us-east-1.amazonaws.com/prod`

**API Gateway URL**: _________________________

## Firebase Setup (15 minutes)

### Firebase Project
- [ ] Logged into Firebase Console
- [ ] Created new project: "Bitcoin Watcher"
- [ ] Disabled Google Analytics (or enabled if desired)
- [ ] Project created successfully

### Android App Configuration
- [ ] Added Android app to Firebase
- [ ] Android package name: `com.example.bitcoin_watcher`
- [ ] Downloaded `google-services.json`
- [ ] Placed `google-services.json` in `android/app/` directory
- [ ] Verified file location is correct

### iOS App Configuration (if building for iOS)
- [ ] Added iOS app to Firebase
- [ ] iOS bundle ID: `com.example.bitcoinWatcher`
- [ ] Downloaded `GoogleService-Info.plist`
- [ ] Placed file in `ios/Runner/` directory

### Cloud Messaging
- [ ] Enabled Cloud Messaging API in Firebase
- [ ] Copied Server Key (for reference)

### Service Account Key
- [ ] Generated Firebase Admin SDK private key
- [ ] Downloaded JSON file
- [ ] Stored in AWS Secrets Manager:
  ```bash
  aws secretsmanager create-secret \
    --name bitcoin-watcher-firebase-creds \
    --secret-string file://path-to-firebase-adminsdk.json
  ```
- [ ] Verified secret exists in Secrets Manager

## Flutter App Setup (10 minutes)

### Dependencies
- [ ] Navigated to project root
- [ ] Ran: `flutter pub get`
- [ ] No errors in dependency resolution

### Configuration
- [ ] Edited `lib/utils/api_config.dart`
- [ ] Updated `baseUrl` with API Gateway URL
- [ ] Saved file

### Android Configuration
- [ ] Verified `google-services.json` in `android/app/`
- [ ] Checked `android/app/build.gradle` has Firebase dependencies
- [ ] Checked `android/build.gradle` has Google services plugin

### Build Test
- [ ] Connected Android device or started emulator
- [ ] Ran: `flutter run`
- [ ] App builds successfully
- [ ] No Firebase initialization errors
- [ ] App starts without crashes

## Testing & Verification (15 minutes)

### Backend Testing
- [ ] Manually invoked Price Listener:
  ```bash
  aws lambda invoke --function-name bitcoin-watcher-price-listener output.json
  ```
- [ ] Checked output.json for success
- [ ] Viewed CloudWatch logs (no errors)
- [ ] Verified data in MongoDB `btc_prices` collection

- [ ] Manually invoked Signal Analyzer:
  ```bash
  aws lambda invoke --function-name bitcoin-watcher-signal-analyzer output.json
  ```
- [ ] Checked output.json for success
- [ ] Viewed CloudWatch logs (no errors)
- [ ] Verified data in MongoDB `signals` collection

### API Testing
- [ ] Tested `/currentPrice`:
  ```bash
  curl https://YOUR-API-URL/prod/currentPrice
  ```
- [ ] Received valid JSON response
- [ ] Contains `price` and `signal` objects

- [ ] Tested `/priceHistory`:
  ```bash
  curl https://YOUR-API-URL/prod/priceHistory?hours=1
  ```
- [ ] Received array of prices

- [ ] Tested `/signalHistory`:
  ```bash
  curl https://YOUR-API-URL/prod/signalHistory?limit=10
  ```
- [ ] Received array of notifications

### App Testing
- [ ] Launched app
- [ ] Home screen displays:
  - [ ] Current BTC price
  - [ ] Current signal (BUY/SELL/HOLD)
  - [ ] 24-hour chart (may be empty initially)
- [ ] Navigated to History screen
  - [ ] Shows notification history (may be empty initially)
- [ ] Navigated to Settings screen
  - [ ] Can toggle notifications
  - [ ] Can adjust algorithm parameters
  - [ ] Save button works

### Notification Testing
- [ ] Waited 5-10 minutes for data collection
- [ ] Checked if signal changed (BUY or SELL)
- [ ] Received push notification (if signal changed)
- [ ] Notification appears in app's History screen
- [ ] Tapping notification navigates correctly

## Post-Setup Tasks

### Monitoring
- [ ] Bookmarked CloudWatch Logs URL
- [ ] Bookmarked MongoDB Atlas Metrics
- [ ] Set up CloudWatch alarms (optional)

### Documentation
- [ ] Saved all credentials securely
- [ ] Documented API Gateway URL
- [ ] Documented MongoDB connection string
- [ ] Created backup of configuration

### Version Control
- [ ] Initialized Git repository
- [ ] Added `.gitignore`
- [ ] Committed initial code
- [ ] Pushed to GitHub (private repo recommended)

### Cost Monitoring
- [ ] Checked AWS Billing Dashboard
- [ ] Verified Lambda invocations within free tier
- [ ] Verified API Gateway requests within free tier
- [ ] Checked MongoDB Atlas storage usage

## Troubleshooting Checklist

If something doesn't work, check:

### App doesn't build
- [ ] `flutter clean` then `flutter pub get`
- [ ] Verify `google-services.json` location
- [ ] Check Android SDK is installed
- [ ] Review build errors carefully

### No price data
- [ ] Check Lambda function logs in CloudWatch
- [ ] Verify EventBridge rules are enabled
- [ ] Test Lambda function manually
- [ ] Check MongoDB connection string
- [ ] Verify MongoDB Network Access allows Lambda

### API returns 403
- [ ] CORS enabled on all API Gateway resources
- [ ] Lambda has permission to be invoked by API Gateway
- [ ] API deployed to `prod` stage

### No notifications
- [ ] Firebase Cloud Messaging enabled
- [ ] Firebase credentials in Secrets Manager
- [ ] App has notification permissions
- [ ] User subscribed to `bitcoin-signals` topic
- [ ] Check Signal Analyzer logs for FCM errors

### Chart not showing
- [ ] Wait 24 hours for sufficient data
- [ ] Check `/priceHistory` API returns data
- [ ] Verify time range is correct
- [ ] Check app logs for parsing errors

## Success Criteria

Your setup is complete when:

✅ Lambda functions execute every 1-2 minutes  
✅ BTC prices are being stored in MongoDB  
✅ Signals are being generated and stored  
✅ API endpoints return valid data  
✅ Flutter app displays current price  
✅ Chart shows price trend  
✅ Push notifications are received for signal changes  
✅ All within free tier limits ($0 monthly cost)

## Next Steps

After successful setup:

1. **Customize Algorithm**
   - Adjust MA periods in Settings
   - Test different threshold values
   - Monitor signal accuracy

2. **Enhance UI**
   - Customize colors in `utils/theme.dart`
   - Add more chart types
   - Improve notification design

3. **Add Features**
   - Support more cryptocurrencies
   - Implement RSI/MACD indicators
   - Add user authentication
   - Create portfolio tracking

4. **Deploy to Production**
   - Build release APK: `flutter build apk --release`
   - Sign APK for Play Store
   - Create app listing
   - Submit for review

## Support Resources

If you get stuck:

- 📖 **SETUP_GUIDE.md** - Detailed setup instructions
- 📖 **QUICKSTART.md** - Quick 30-minute guide
- 📖 **ARCHITECTURE.md** - System architecture details
- 🔍 **CloudWatch Logs** - Lambda function debugging
- 🔍 **MongoDB Atlas Logs** - Database issues
- 🔍 **Flutter Logs** - `flutter logs` for app issues

---

**Congratulations!** You're now ready to track Bitcoin like a pro! 🚀📈
