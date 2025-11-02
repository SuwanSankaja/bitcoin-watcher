# Bitcoin Watcher - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter Mobile App                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Home Screen  │  │History Screen│  │Settings Screen│              │
│  │              │  │              │  │              │              │
│  │ - BTC Price  │  │ - Signal     │  │ - Notif      │              │
│  │ - Chart      │  │   History    │  │   Settings   │              │
│  │ - Signal     │  │ - Details    │  │ - Algorithm  │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
│         │                  │                  │                      │
│         └──────────────────┴──────────────────┘                      │
│                            │                                         │
│                    ┌───────▼────────┐                                │
│                    │ Services Layer │                                │
│                    │ - API Client   │                                │
│                    │ - FCM Service  │                                │
│                    └───────┬────────┘                                │
└────────────────────────────┼──────────────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │ Firebase Cloud   │
                    │   Messaging      │◄─────────┐
                    └──────────────────┘          │
                             │                    │
                             │                    │
                    ┌────────▼─────────┐          │
                    │  AWS API Gateway │          │
                    │   /currentPrice  │          │
                    │   /priceHistory  │          │
                    │   /signalHistory │          │
                    │   /settings      │          │
                    └────────┬─────────┘          │
                             │                    │
              ┌──────────────┼────────────────┐   │
              │              │                │   │
     ┌────────▼────────┐ ┌──▼──────────┐ ┌───▼───────────┐
     │ Lambda Function│ │Lambda Function│ │Lambda Function│
     │ Price Listener │ │Signal Analyzer│ │  API Handler  │
     │                │ │               │ │               │
     │ - Fetch BTC    │ │ - Calculate MA│ │ - REST API    │
     │   from Binance │ │ - Detect      │ │ - Query Data  │
     │ - Store in DB  │ │   Signals     │ │ - Return JSON │
     └────────┬───────┘ │ - Send FCM    │ └───────┬───────┘
              │         └───────┬───────┘         │
              │                 │                 │
              │         ┌───────▼────────┐        │
              │         │   AWS SNS      │        │
              │         │ /Firebase FCM  │────────┘
              │         └────────────────┘
              │                 │
              └─────────────────┴─────────────────┐
                                                  │
                                   ┌──────────────▼──────────────┐
                                   │    MongoDB Atlas            │
                                   │  (Time Series Database)     │
                                   │                             │
                                   │  ┌──────────────────────┐   │
                                   │  │ btc_prices           │   │
                                   │  │ {timestamp, price}   │   │
                                   │  └──────────────────────┘   │
                                   │                             │
                                   │  ┌──────────────────────┐   │
                                   │  │ signals              │   │
                                   │  │ {timestamp, type,    │   │
                                   │  │  price, confidence}  │   │
                                   │  └──────────────────────┘   │
                                   │                             │
                                   │  ┌──────────────────────┐   │
                                   │  │ notifications        │   │
                                   │  │ {timestamp, signal,  │   │
                                   │  │  title, message}     │   │
                                   │  └──────────────────────┘   │
                                   └─────────────────────────────┘

                  ┌──────────────────────────────────────┐
                  │      AWS EventBridge                  │
                  │                                       │
                  │  ┌────────────────────────────────┐   │
                  │  │ Rate(1 minute)                 │   │
                  │  │ → Trigger Price Listener       │   │
                  │  └────────────────────────────────┘   │
                  │                                       │
                  │  ┌────────────────────────────────┐   │
                  │  │ Rate(2 minutes)                │   │
                  │  │ → Trigger Signal Analyzer      │   │
                  │  └────────────────────────────────┘   │
                  └──────────────────────────────────────┘

                  ┌──────────────────────────────────────┐
                  │  AWS Secrets Manager & SSM           │
                  │                                       │
                  │  - MongoDB Connection String         │
                  │  - Firebase Admin SDK Credentials    │
                  │  - API Keys                          │
                  └──────────────────────────────────────┘
```

## Data Flow

### 1. Price Collection Flow
```
Binance API → Lambda (Price Listener) → MongoDB (btc_prices)
      ↓
EventBridge (every 1 minute)
```

### 2. Signal Analysis Flow
```
MongoDB (btc_prices) → Lambda (Signal Analyzer) → Calculate Moving Averages
                                ↓
                        Generate BUY/SELL/HOLD
                                ↓
                        Store in MongoDB (signals)
                                ↓
                        If signal changed → Send FCM notification
                                ↓
                        Store in MongoDB (notifications)
```

### 3. App Data Retrieval Flow
```
Flutter App → API Gateway → Lambda (API Handler) → MongoDB
                                ↓
                        Return JSON Response
                                ↓
                        Display in App
```

### 4. Notification Flow
```
Signal Detected → Lambda → Firebase FCM → Push Notification
                              ↓
                        All Subscribed Devices
                              ↓
                        App Receives & Displays
```

## Technology Stack

### Frontend (Mobile)
- **Framework**: Flutter 3.0+
- **Language**: Dart
- **State Management**: Provider
- **Charts**: fl_chart
- **Notifications**: firebase_messaging + flutter_local_notifications
- **HTTP Client**: http package

### Backend (Serverless)
- **Compute**: AWS Lambda (Python 3.11)
- **API**: AWS API Gateway (REST)
- **Scheduler**: AWS EventBridge
- **Secrets**: AWS Secrets Manager + Systems Manager
- **Notifications**: Firebase Cloud Messaging

### Database
- **Primary**: MongoDB Atlas (Time Series)
  - Free tier: 512MB storage
  - Collections: btc_prices, signals, notifications
  - Optimized for time-based queries

### External APIs
- **Price Data**: Binance Public API
  - Endpoint: `https://api.binance.com/api/v3/ticker/price`
  - No authentication required
  - Rate limit: 1200 requests/minute

## Algorithm Details

### Moving Average Crossover Strategy

```python
# Calculate moving averages
short_ma = average(last_7_prices)
long_ma = average(last_21_prices)

# Generate signals
if short_ma > long_ma * (1 + buy_threshold):
    signal = "BUY"
    confidence = (short_ma / long_ma - 1) / buy_threshold * 100

elif short_ma < long_ma * (1 - sell_threshold):
    signal = "SELL"
    confidence = (1 - short_ma / long_ma) / sell_threshold * 100

else:
    signal = "HOLD"
    confidence = 50
```

### Default Parameters
- Short MA Period: 7 minutes
- Long MA Period: 21 minutes
- Buy Threshold: 0.5%
- Sell Threshold: 0.5%

### Customizable via Settings
- All parameters adjustable in app
- Saved locally and synced to backend
- Real-time effect on signal generation

## Security Measures

### 1. Credentials Management
- MongoDB URI: AWS SSM Parameter Store (encrypted)
- Firebase Creds: AWS Secrets Manager
- No hardcoded secrets in code

### 2. Network Security
- HTTPS only (API Gateway enforced)
- CORS configured for API Gateway
- MongoDB: Network access controls

### 3. IAM Policies
- Least privilege access for Lambda
- Separate roles for each function
- CloudWatch logging enabled

## Performance Optimizations

### 1. Database
- Time series collection for efficient storage
- Indexes on timestamp fields
- Automatic data aggregation

### 2. API
- API Gateway caching (optional)
- Lambda cold start mitigation (keep warm)
- Connection pooling for MongoDB

### 3. Mobile App
- Local caching with shared_preferences
- Pull-to-refresh for manual updates
- Auto-refresh every 30 seconds (configurable)

## Cost Breakdown (Monthly)

```
AWS Lambda
- Price Listener: ~43,200 invocations/month (1/min)
- Signal Analyzer: ~21,600 invocations/month (1/2min)
- API Handler: ~1,000 invocations/month (estimated)
Total: ~66,000 invocations
Cost: $0 (within 1M free tier)

API Gateway
- Requests: ~1,000/month
Cost: $0 (within 1M free tier)

MongoDB Atlas
- Storage: ~50MB/month (time series)
Cost: $0 (within 512MB free tier)

Firebase FCM
- Notifications: Unlimited
Cost: $0 (always free)

Total Monthly Cost: $0
```

## Scaling Considerations

### Current Limits (Free Tier)
- Lambda: 1M requests, 400,000 GB-seconds
- API Gateway: 1M requests
- MongoDB: 512MB storage (~6 months of price data)

### When to Scale
- Add data retention policy (delete old data after 3-6 months)
- Upgrade MongoDB to M2 tier if storage exceeds 512MB
- Add API Gateway caching for high traffic
- Consider Lambda Reserved Concurrency for consistency

## Monitoring & Observability

### CloudWatch Logs
- All Lambda executions logged
- Error tracking and debugging
- Custom metrics for performance

### MongoDB Atlas Metrics
- Operations per second
- Storage usage
- Query performance

### Application Monitoring
- API response times
- Notification delivery rates
- User engagement metrics (optional)

## Future Enhancements

1. **Multi-Currency Support**
   - Add ETH, LTC, etc.
   - Currency switcher in app

2. **Advanced Algorithms**
   - RSI (Relative Strength Index)
   - MACD (Moving Average Convergence Divergence)
   - Bollinger Bands

3. **User Authentication**
   - AWS Cognito integration
   - Personal watchlists
   - Custom alert preferences

4. **Portfolio Tracking**
   - Track user holdings
   - Calculate P&L
   - Investment insights

5. **Social Features**
   - Share signals
   - Community insights
   - Expert analysis

## Development Workflow

```bash
# 1. Local Development
flutter run

# 2. Backend Testing
python backend/lambda/price_listener.py  # Local test
aws lambda invoke --function-name ... # Cloud test

# 3. Deployment
cd backend
./scripts/deploy.sh  # Deploy Lambda functions

flutter build apk --release  # Build Android
flutter build ios --release  # Build iOS

# 4. Monitoring
aws logs tail /aws/lambda/bitcoin-watcher-price-listener --follow
```

## Troubleshooting Guide

| Issue | Solution |
|-------|----------|
| No price data | Check Lambda logs, verify EventBridge rules |
| API 403 error | Enable CORS, check Lambda permissions |
| No notifications | Verify FCM config, check Secrets Manager |
| App crashes | Check Firebase init, verify google-services.json |
| Chart not showing | Ensure sufficient data (24+ data points) |

## Support Resources

- **AWS Documentation**: https://docs.aws.amazon.com/
- **MongoDB Atlas Docs**: https://docs.atlas.mongodb.com/
- **Flutter Docs**: https://flutter.dev/docs
- **Firebase Docs**: https://firebase.google.com/docs

---

**Built with ❤️ for crypto enthusiasts**
