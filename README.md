# Bitcoin Watcher 📈

A Flutter app that monitors Bitcoin prices and trading signals in real-time, with push notifications via Firebase Cloud Messaging.

## Features
- Live BTC price & buy/sell/hold signals
- 24-hour price history chart
- Push notifications for signal changes
- Configurable alert thresholds

## Tech Stack
| Layer | Tech |
|---|---|
| Mobile | Flutter (Android) |
| Backend | AWS Lambda (Python 3.11) |
| API | AWS API Gateway (ap-northeast-1) |
| Database | MongoDB Atlas |
| Secrets | Doppler |
| CI/CD | GitHub Actions |
| Notifications | Firebase Cloud Messaging |

## Project Structure
```
├── lib/                    # Flutter app
│   ├── models/             # Data models
│   ├── screens/            # UI screens (Home, History, Settings)
│   ├── services/           # API client & notification service
│   ├── utils/              # Theme, formatters, API config
│   └── widgets/            # Reusable widgets
├── backend/
│   ├── lambda/             # AWS Lambda functions
│   │   ├── api_handler.py        # REST API (all endpoints)
│   │   ├── price_listener.py     # Fetches BTC price (scheduled)
│   │   ├── signal_analyzer.py    # Computes buy/sell signals (scheduled)
│   │   └── binance_trader.py     # Binance trading logic
│   ├── tests/
│   │   └── test_api.py     # API integration tests (pytest)
│   └── requirements.txt
├── .github/workflows/
│   └── deploy.yml          # CI/CD: deploy Lambda + test APIs on push to prod
├── flutter_run.sh          # Run app with Doppler-injected secrets
└── pytest.ini
```

## Local Development

### Prerequisites
- Flutter SDK
- Python 3.11+
- Doppler CLI (`brew install dopplerhq/cli/doppler`)
- Android emulator or device

### Running the app
```bash
# Run with secrets from Doppler (recommended)
./flutter_run.sh

# Or with specific device
./flutter_run.sh run -d <device-id>
```

The `flutter_run.sh` script reads `DOPPLER_SERVICE_TOKEN` from `.env` and injects all secrets at build time via `--dart-define-from-file`.

### Running API tests
```bash
APIGW_REST_API_ID=o9tic8ti7h pytest backend/tests/test_api.py -v
```

## CI/CD

On push to `prod` (when `backend/` files change):
1. **Deploy** — packages Lambda code, uploads to S3, updates all 3 functions, re-deploys API Gateway
2. **Integration Tests** — runs 21 pytest tests against the live API

Requires one GitHub Actions secret: `DOPPLER_TOKEN` (stored in the `prod` environment).

## API Endpoints

Base URL: `https://o9tic8ti7h.execute-api.ap-northeast-1.amazonaws.com/prod`

| Endpoint | Method | Description |
|---|---|---|
| `/currentPrice` | GET | Latest BTC price and signal |
| `/priceHistory?hours=N` | GET | Price history for last N hours |
| `/signalHistory?limit=N` | GET | Last N buy/sell/hold signals |
| `/settings` | GET / POST | App configuration |
