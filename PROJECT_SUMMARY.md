# Bitcoin Watcher - Project Summary

## 🎯 Project Overview

Bitcoin Watcher is a **real-time cryptocurrency tracking application** that monitors Bitcoin prices, analyzes market trends using moving average algorithms, and sends intelligent buy/sell notifications to users. Built with Flutter for cross-platform mobile deployment and AWS serverless backend for cost-effective scalability.

## ✨ Key Features

### Mobile App (Flutter)
- 📊 **Real-time BTC price tracking** with auto-refresh
- 📈 **Interactive 24-hour price chart** using fl_chart
- 🎯 **Buy/Sell/Hold signal indicator** with confidence levels
- 📜 **Complete notification history** with detailed signal information
- ⚙️ **Customizable algorithm settings** (thresholds, MA periods)
- 🔔 **Push notifications** for important signals via Firebase
- 🌙 **Dark mode UI** optimized for readability

### Backend (AWS Serverless)
- ⚡ **Price collection** every minute from Binance API
- 🧠 **Signal analysis** every 2 minutes using moving averages
- 🔄 **REST API** for mobile app data retrieval
- 📦 **Time-series storage** in MongoDB Atlas
- 💰 **Zero cost** using free tiers (AWS, MongoDB, Firebase)

### Algorithm
- **Moving Average Crossover Strategy**
  - Short MA: 7-minute average
  - Long MA: 21-minute average
  - Configurable thresholds: 0.5% default
  - Confidence calculation for each signal

## 📁 Project Structure

```
bitcoin-watcher/
├── lib/                          # Flutter app source
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── btc_price.dart
│   │   ├── signal.dart
│   │   ├── notification_item.dart
│   │   └── app_settings.dart
│   ├── services/                 # Business logic
│   │   ├── api_client.dart
│   │   ├── bitcoin_service.dart
│   │   └── notification_service.dart
│   ├── screens/                  # UI screens
│   │   ├── home_screen.dart
│   │   ├── history_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/                  # Reusable components
│   │   ├── signal_badge.dart
│   │   ├── loading_indicator.dart
│   │   └── error_view.dart
│   └── utils/                    # Helpers
│       ├── api_config.dart
│       ├── formatters.dart
│       └── theme.dart
├── backend/                      # AWS Lambda functions
│   ├── lambda/
│   │   ├── price_listener.py     # Fetch BTC price
│   │   ├── signal_analyzer.py    # Analyze & send notifications
│   │   └── api_handler.py        # REST API endpoints
│   ├── scripts/
│   │   ├── deploy.sh             # Linux/Mac deployment
│   │   └── deploy.ps1            # Windows deployment
│   ├── mongodb/
│   │   └── SETUP.md              # MongoDB configuration
│   └── requirements.txt          # Python dependencies
├── android/                      # Android configuration
├── ios/                          # iOS configuration
├── README.md                     # Project overview
├── SETUP_GUIDE.md                # Detailed setup instructions
├── QUICKSTART.md                 # Quick setup guide
├── ARCHITECTURE.md               # System architecture
└── pubspec.yaml                  # Flutter dependencies
```

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Mobile** | Flutter 3.0+ | Cross-platform UI |
| | Dart | Programming language |
| | Provider | State management |
| | fl_chart | Interactive charts |
| | Firebase Messaging | Push notifications |
| **Backend** | AWS Lambda | Serverless compute |
| | Python 3.11 | Lambda runtime |
| | API Gateway | REST API |
| | EventBridge | Scheduled triggers |
| **Database** | MongoDB Atlas | Time-series storage |
| | Free Tier | 512MB storage |
| **External** | Binance API | BTC price data |
| | Firebase FCM | Notifications |
| **DevOps** | AWS CLI | Deployment |
| | Git | Version control |

## 💰 Cost Analysis

**Total Monthly Cost: $0** (100% free tier usage)

| Service | Usage | Free Tier | Cost |
|---------|-------|-----------|------|
| AWS Lambda | ~66K invocations/month | 1M free | $0 |
| API Gateway | ~1K requests/month | 1M free | $0 |
| MongoDB Atlas | ~50MB storage | 512MB free | $0 |
| Firebase FCM | Unlimited notifications | Always free | $0 |
| EventBridge | 2 rules | Always free | $0 |

## 📊 Performance Metrics

- **Price Update Frequency**: Every 60 seconds
- **Signal Analysis**: Every 120 seconds
- **API Response Time**: < 500ms average
- **Data Retention**: 3-6 months (configurable)
- **App Startup Time**: < 2 seconds
- **Push Notification Delay**: < 5 seconds

## 🔒 Security Features

- ✅ Encrypted credentials in AWS Secrets Manager
- ✅ HTTPS-only API communication
- ✅ MongoDB Atlas network security
- ✅ IAM role-based access control
- ✅ No hardcoded secrets in codebase
- ✅ Firebase authentication ready

## 📱 Supported Platforms

- ✅ Android 5.0+ (API 21+)
- ✅ iOS 12.0+
- 🔄 Web (with modifications)
- 🔄 Desktop (Flutter desktop support)

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone https://github.com/yourusername/bitcoin-watcher.git
cd bitcoin-watcher

# 2. Install Flutter dependencies
flutter pub get

# 3. Set up MongoDB Atlas (5 min)
# - Create free cluster
# - Get connection string

# 4. Deploy AWS backend (10 min)
cd backend
./scripts/deploy.sh  # or deploy.ps1 on Windows

# 5. Configure Firebase (5 min)
# - Create project
# - Download google-services.json
# - Place in android/app/

# 6. Update API URL
# Edit lib/utils/api_config.dart

# 7. Run app
flutter run
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | Project overview and features |
| [QUICKSTART.md](QUICKSTART.md) | 30-minute setup guide |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | Comprehensive setup instructions |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design and data flow |
| [backend/AWS_SETUP.md](backend/AWS_SETUP.md) | AWS configuration details |
| [backend/mongodb/SETUP.md](backend/mongodb/SETUP.md) | MongoDB setup guide |

## 🧪 Testing

### Backend Testing
```bash
# Test Price Listener
aws lambda invoke --function-name bitcoin-watcher-price-listener output.json

# Test Signal Analyzer
aws lambda invoke --function-name bitcoin-watcher-signal-analyzer output.json

# Test API
curl https://YOUR-API-GATEWAY-URL/prod/currentPrice
```

### Frontend Testing
```bash
# Run Flutter tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart
```

## 🔄 CI/CD Pipeline (Optional)

```yaml
# .github/workflows/deploy.yml
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy Lambda
        run: cd backend && ./scripts/deploy.sh
      - name: Build Flutter
        run: flutter build apk --release
```

## 📈 Roadmap

### Phase 1: Core Features ✅
- [x] Real-time price tracking
- [x] Moving average algorithm
- [x] Push notifications
- [x] Signal history
- [x] Settings customization

### Phase 2: Enhancements 🚧
- [ ] Multiple cryptocurrency support
- [ ] Advanced technical indicators (RSI, MACD)
- [ ] User authentication
- [ ] Portfolio tracking
- [ ] Price alerts

### Phase 3: Advanced Features 🔮
- [ ] Social features (share signals)
- [ ] Machine learning predictions
- [ ] News sentiment analysis
- [ ] Trading integration
- [ ] Web dashboard

## 🤝 Contributing

This is a personal project, but contributions are welcome!

```bash
# Fork the repository
git checkout -b feature/amazing-feature
git commit -m 'Add amazing feature'
git push origin feature/amazing-feature
# Create Pull Request
```

## 📄 License

MIT License - feel free to use this project for learning or commercial purposes.

## 🙏 Acknowledgments

- **Binance** for free price API
- **MongoDB Atlas** for generous free tier
- **AWS** for serverless infrastructure
- **Firebase** for notification services
- **Flutter community** for excellent packages

## 📞 Support

For issues or questions:
1. Check [SETUP_GUIDE.md](SETUP_GUIDE.md) troubleshooting section
2. Review AWS CloudWatch logs
3. Check MongoDB Atlas logs
4. Review Flutter logs: `flutter logs`

## 🎓 Learning Resources

This project demonstrates:
- Flutter app development with real-time data
- AWS serverless architecture (Lambda, API Gateway, EventBridge)
- MongoDB time-series database usage
- Firebase Cloud Messaging integration
- Moving average trading algorithm implementation
- Mobile app notification handling

Perfect for learning:
- Mobile app development
- Serverless backend design
- Cryptocurrency data analysis
- Cloud infrastructure deployment
- Real-time data processing

---

**Built with Flutter, AWS, and MongoDB**

**Author**: Your Name  
**Date**: November 2025  
**Version**: 1.0.0
