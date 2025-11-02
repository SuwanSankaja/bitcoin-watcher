# Bitcoin Watcher 📊

A real-time Bitcoin tracker app with intelligent Buy/Sell signals and comprehensive notification history.

## Features

- 📈 Real-time BTC price tracking via Binance API
- 🔔 Push notifications for Buy/Sell signals
- 📜 Complete signal history with timestamps
- 📊 Interactive price trend charts
- ⚙️ Customizable algorithm sensitivity
- 🌙 Dark mode support

## Tech Stack

### Frontend
- **Flutter 3+** - Cross-platform mobile framework
- **Firebase Cloud Messaging** - Push notifications
- **fl_chart** - Interactive charts
- **Provider** - State management

### Backend
- **AWS Lambda** - Serverless compute (Price Listener, Signal Analyzer, API Handler)
- **AWS API Gateway** - REST API endpoints
- **AWS EventBridge** - Scheduled triggers
- **AWS Secrets Manager** - Secure API key storage

### Database
- **MongoDB Atlas** - Time series collections
  - `btc_prices` - Real-time price data
  - `signals` - Buy/Hold/Sell signals
  - `notifications` - Notification history

## Project Structure

```
bitcoin-watcher/
├── lib/
│   ├── main.dart
│   ├── models/          # Data models
│   ├── services/        # API & Firebase services
│   ├── screens/         # UI screens
│   ├── widgets/         # Reusable widgets
│   └── utils/           # Helper functions
├── backend/
│   ├── lambda/          # AWS Lambda functions
│   ├── scripts/         # Deployment scripts
│   └── config/          # Configuration files
└── mongodb/             # Database schemas
```

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0+
- AWS Account (Free Tier)
- MongoDB Atlas Account (Free Tier)
- Firebase Project

### 1. Flutter Setup
```bash
flutter pub get
```

### 2. Firebase Configuration
- Create a Firebase project
- Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
- Place in respective directories

### 3. AWS Setup
- Deploy Lambda functions from `backend/lambda/`
- Configure API Gateway endpoints
- Set up EventBridge for periodic triggers
- Store API keys in Secrets Manager

### 4. MongoDB Atlas Setup
- Create a free cluster
- Set up time series collections
- Configure connection string in AWS Parameter Store

### 5. Environment Variables
Create `.env` file with:
```
API_BASE_URL=https://your-api-gateway-url.amazonaws.com
```

## Running the App

```bash
flutter run
```

## Algorithm

Uses Moving Average Crossover strategy:
```
shortMA = avg(last 7 prices)
longMA = avg(last 21 prices)

if shortMA > longMA * 1.005 → BUY
if shortMA < longMA * 0.995 → SELL
else → HOLD
```

## Cost Optimization

- AWS Lambda: 1M free requests/month
- API Gateway: 1M free requests/month
- MongoDB Atlas: 512MB free tier
- Firebase FCM: Free

**Estimated Monthly Cost: $0 (within free tiers)**

## License

MIT
