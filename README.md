# Bitcoin Watcher 🚀

Real-time Bitcoin price tracker with intelligent buy/sell signals and push notifications.

## ✨ Features

- 📊 **Real-time BTC Price Tracking** - Fetches price every minute from CoinGecko API
- 📈 **Moving Average Crossover Algorithm** - Generates buy/sell signals using 7-min & 21-min MAs
- 🔔 **Push Notifications** - Instant alerts via Firebase Cloud Messaging (works even when app is closed)
- 📱 **Flutter Mobile App** - Beautiful, responsive Android app with interactive charts
- ☁️ **Serverless Architecture** - AWS Lambda + MongoDB Atlas + Firebase
- 🕒 **Sri Lanka Time** - All timestamps stored in Asia/Colombo timezone

## 🛠️ Tech Stack

### Frontend
- **Flutter 3.0+** - Cross-platform mobile framework
- **Firebase Messaging** - Push notifications
- **fl_chart** - Interactive price charts
- **Provider** - State management

### Backend
- **AWS Lambda** - Serverless compute (Python 3.11)
- **AWS EventBridge** - Scheduled triggers (1 min, 2 min)
- **AWS API Gateway** - REST API endpoints
- **MongoDB Atlas** - Time series database
- **Firebase Admin SDK** - Push notification delivery
- **CoinGecko API** - Bitcoin price data source

## 📁 Project Structure

```
bitcoin-watcher/
├── lib/                    # Flutter app source
│   ├── models/             # Data models (BtcPrice, Signal, etc.)
│   ├── screens/            # UI screens (Home, History, Settings)
│   ├── services/           # Business logic (Bitcoin, Notification)
│   ├── utils/              # Utilities & config
│   └── widgets/            # Reusable widgets
├── backend/
│   ├── lambda/             # AWS Lambda functions
│   │   ├── price_listener.py    # Fetches BTC price every minute
│   │   ├── signal_analyzer.py   # Generates signals every 2 minutes
│   │   └── api_handler.py       # API Gateway handler
│   ├── requirements.txt    # Python dependencies
│   ├── test_notification_aws.py # Test FCM notifications
│   └── AWS_SETUP.md       # Detailed deployment guide
├── android/                # Android platform code
├── .env.example            # Environment variables template
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Python 3.11
- AWS Account
- MongoDB Atlas cluster
- Firebase project

### 1. Clone & Configure

```bash
git clone <your-repo>
cd bitcoin-watcher

# Copy environment template
cp .env.example .env
```

Edit `.env` with your API Gateway URL:
```bash
API_BASE_URL=https://your-api-id.execute-api.us-east-1.amazonaws.com/prod
```

### 2. Firebase Setup

1. Create Firebase project: [console.firebase.google.com](https://console.firebase.google.com)
2. Download `google-services.json` → `android/app/`
3. Download Firebase Admin SDK JSON → store in AWS Secrets Manager as `bitcoin-watcher-firebase-creds`

### 3. Backend Deployment

See `backend/AWS_SETUP.md` for detailed instructions:

1. **MongoDB Atlas** - Create time series collection `btc_prices`
2. **AWS Lambda** - Deploy 3 functions with Python dependencies layer
3. **AWS EventBridge** - Schedule triggers every 1-2 minutes
4. **AWS API Gateway** - Create REST API with Lambda integration

Quick deploy:
```bash
cd backend

# Build Lambda layer
pip install -r requirements.txt --target python/
zip -r lambda-layer.zip python/

# Deploy functions (follow AWS_SETUP.md for details)
```

### 4. Run Flutter App

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

Or for Android:
```bash
flutter build apk --dart-define-from-file=.env
```

## 📊 Algorithm

**Moving Average Crossover Strategy:**

```
Indicators:
- Short MA: 7-minute moving average
- Long MA: 21-minute moving average

Signals:
BUY  → Short MA > Long MA × 1.005 (exceeds by 0.5%)
SELL → Short MA < Long MA × 0.995 (falls below 0.5%)
HOLD → Everything in between

Confidence: Distance from threshold (0-100%)
```

**Example:**
```
BTC Price: $110,500
7-min MA:  $110,800
21-min MA: $110,000

Result: BUY Signal (Short MA exceeds Long MA by 0.7%)
Confidence: 75%
```

## 🔌 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/currentPrice` | GET | Latest BTC price & active signal |
| `/priceHistory?hours=24` | GET | Historical prices for chart |
| `/signalHistory?limit=50` | GET | Past buy/sell signals |
| `/settings` | GET | Current algorithm parameters |
| `/settings` | POST | Update algorithm parameters |

## 🔔 Testing Notifications

```bash
cd backend
pip install firebase-admin boto3
python test_notification_aws.py
```

**Important:** Before testing:
1. Open the app at least once (subscribes to `bitcoin-signals` topic)
2. Enable notifications in Android Settings → Apps → Bitcoin Watcher
3. Ensure phone has internet connection

You should receive a test notification within 5-10 seconds.

## 🐛 Troubleshooting

### No Signals Generated (Confidence 0%)
- **Cause:** Insufficient data (need 21+ minutes)
- **Fix:** Wait for EventBridge to collect at least 21 data points
- **Check:** Verify `btc_prices` collection has data

### Notifications Not Working
- **Cause:** App not subscribed to topic
- **Fix:** Open app, wait 10 seconds, check logs for "Subscribed to bitcoin-signals"
- **Test:** Run `test_notification_aws.py` to verify FCM works

### Chart Shows "111K" for All Values
- **Cause:** Price range too small or invalid data
- **Fix:** Now handled with proper padding and scaling (v1.1)

### EventBridge Not Triggering
- **Cause:** Invalid cron expression
- **Fix:** Use `rate(1 minute)` not `rate(1 minutes)`
- **Check:** CloudWatch Logs for Lambda executions

## 💾 MongoDB Collections

```javascript
// btc_prices (Time Series Collection)
{
  timestamp: ISODate("2025-11-02T13:30:00"),  // Sri Lanka time
  price: 110500.0
}

// signals
{
  timestamp: ISODate("2025-11-02T13:30:00"),
  type: "BUY",  // or "SELL", "HOLD"
  price: 110500.0,
  confidence: 75.5
}

// notifications
{
  timestamp: ISODate("2025-11-02T13:30:00"),
  signal_id: "673f...",
  title: "BUY Signal Detected!",
  message: "BTC at $110,500.00 - Confidence 75%",
  signal_type: "BUY",
  price: 110500.0
}
```

## 🏗️ AWS Architecture

```
┌─────────────────┐
│  EventBridge    │
│  rate(1 min)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐        ┌──────────────┐
│ price_listener  │───────>│  MongoDB     │
│    Lambda       │        │  Atlas       │
└─────────────────┘        └──────┬───────┘
                                  │
┌─────────────────┐               │
│  EventBridge    │               │
│  rate(2 min)    │               │
└────────┬────────┘               │
         │                        │
         ▼                        │
┌─────────────────┐               │
│ signal_analyzer │<──────────────┘
│    Lambda       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐        ┌──────────────┐
│   Firebase      │───────>│   Mobile     │
│      FCM        │        │     App      │
└─────────────────┘        └──────────────┘
         ▲                        ▲
         │                        │
         └────────────┬───────────┘
                      │
              ┌───────┴────────┐
              │  API Gateway   │
              │  api_handler   │
              └────────────────┘
```

## 🔒 Security & Secrets

### Stored in AWS
- **Parameter Store** → `/bitcoin-watcher/mongodb-uri`
- **Secrets Manager** → `bitcoin-watcher-firebase-creds`

### Never Commit
- `.env` - Local environment variables
- `google-services.json` - Firebase Android config
- `firebase-adminsdk-*.json` - Firebase credentials
- `backend/python/` - Lambda layer build artifacts
- `backend/*.zip` - Deployment packages

All sensitive files are in `.gitignore`.

## 📦 Dependencies

### Flutter
```yaml
firebase_messaging: ^14.7.9
firebase_core: ^2.24.2
fl_chart: ^0.65.0
provider: ^6.1.1
http: ^1.1.0
```

### Python (Lambda)
```
boto3==1.34.34
pymongo==4.6.1
requests==2.31.0
firebase-admin==6.4.0
pytz==2024.1
```

## 📄 License

MIT License - Feel free to use for your own projects!

## 🤝 Contributing

Pull requests welcome! Please:
- Follow Flutter/Dart style guidelines
- Keep Python code PEP 8 compliant
- Update documentation for new features
- Test thoroughly before submitting

## 📞 Support

- Deployment issues? → See `backend/AWS_SETUP.md`
- Project structure? → See `PROJECT_STRUCTURE.md`
- Found a bug? → Open an issue on GitHub

---

**Built with ❤️ using Flutter, AWS Lambda, and MongoDB**
