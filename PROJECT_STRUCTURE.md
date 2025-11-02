# Bitcoin Watcher - Clean Project Structure

## Core Files & Directories

### Root Directory
```
bitcoin-watcher/
├── .env.example          # Environment variables template
├── .gitignore            # Git ignore rules
├── pubspec.yaml          # Flutter dependencies
├── analysis_options.yaml # Dart linting rules
├── README.md             # Main project documentation
├── lib/                  # Flutter app source code
├── android/              # Android platform code
├── assets/               # App assets (images, etc.)
├── backend/              # AWS Lambda functions
└── test/                 # Flutter tests
```

### Backend Directory
```
backend/
├── lambda/
│   ├── price_listener.py       # Fetches BTC price every minute
│   ├── signal_analyzer.py      # Analyzes prices, generates signals
│   └── api_handler.py          # API Gateway handler
├── requirements.txt            # Python dependencies
├── test_notification_aws.py    # Test FCM notifications
└── AWS_SETUP.md               # AWS deployment guide
```

### Flutter App Structure
```
lib/
├── main.dart              # App entry point
├── models/               # Data models
│   ├── btc_price.dart
│   ├── signal.dart
│   ├── notification_item.dart
│   └── app_settings.dart
├── screens/              # UI screens
│   ├── home_screen.dart
│   ├── history_screen.dart
│   └── settings_screen.dart
├── services/             # Business logic
│   ├── bitcoin_service.dart
│   └── notification_service.dart
├── utils/                # Utilities
│   ├── api_config.dart
│   ├── formatters.dart
│   └── theme.dart
└── widgets/              # Reusable widgets
    ├── error_view.dart
    ├── loading_indicator.dart
    └── signal_badge.dart
```

## Removed Files

The following files have been removed as they are:
- Outdated documentation
- Duplicate guides
- Unnecessary templates
- Auto-generated files in git

### Documentation Consolidated
- ✅ Keep: README.md (main docs)
- ✅ Keep: backend/AWS_SETUP.md (deployment)
- ❌ Remove: SETUP_GUIDE.md (outdated)
- ❌ Remove: QUICKSTART.md (merged into README)
- ❌ Remove: PROJECT_SUMMARY.md (redundant)
- ❌ Remove: SETUP_CHECKLIST.md (outdated)
- ❌ Remove: CHECK_EVENTBRIDGE.md (specific issue)
- ❌ Remove: TIMEZONE_UPDATE_GUIDE.md (already implemented)
- ❌ Remove: ALGORITHM_GUIDE.md (can be in README)
- ❌ Remove: ARCHITECTURE.md (merged into README)
- ❌ Remove: .env.template (replaced with .env.example)

### Test Files
- ❌ Remove: test_coingecko.py (one-time test)
- ❌ Remove: backend/test_notification.py (use AWS version)
- ✅ Keep: backend/test_notification_aws.py

### Backend Build Artifacts
- ❌ Remove: backend/python/ (Lambda layer source, regenerate when needed)
- ❌ Remove: backend/lambda-layer.zip (regenerate when needed)

## Environment Variables

### Flutter (.env)
```
API_BASE_URL=https://your-api-url.execute-api.us-east-1.amazonaws.com/prod
```

Run with:
```bash
flutter run --dart-define-from-file=.env
```

### Backend (AWS Services)
- MongoDB URI: AWS Parameter Store → `/bitcoin-watcher/mongodb-uri`
- Firebase Creds: AWS Secrets Manager → `bitcoin-watcher-firebase-creds`

## Git Ignore
All sensitive files, build artifacts, and IDE configs are properly ignored.

## Next Steps
1. Copy `.env.example` to `.env` and fill in your API URL
2. Ensure Firebase config files are in place (google-services.json, GoogleService-Info.plist)
3. Deploy Lambda functions using backend/AWS_SETUP.md
4. Run: `flutter run --dart-define-from-file=.env`
