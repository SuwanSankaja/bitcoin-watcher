# Bitcoin Watcher 📈

A Flutter app that monitors Bitcoin prices and trading signals in real-time, with push notifications via Firebase Cloud Messaging. Ships in **two versions** that can be deployed independently:

| Version | Focus | Branch | Entry Point |
|---|---|---|---|
| **Original** | Buy / Sell / Hold signals | `prod` | `lib/main.dart` |
| **Hodler** | Accumulation score & DCA buying | `hodler` | `lib_hodler/main_hodler.dart` |

---

## Features

### Original (Buy/Sell)
- Live BTC price & buy/sell/hold signals
- 24-hour price history chart
- Push notifications for signal changes
- Configurable alert thresholds

### Hodler (Accumulation)
- **Accumulation Score** (0–100) computed from 5 indicators: RSI, MA crossover, Bollinger Bands, Fear & Greed Index, Dip Depth
- **DCA-scaled buying** — buy amount scales with score strength
- **Portfolio tracking** — total BTC stack, average cost basis, unrealized P&L
- **Market sentiment dashboard** — RSI, Fear & Greed, dip-from-high tiles
- **Buy Zone detection** with animated gauge and pulse badge
- Push notifications enriched with accumulation score

---

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
| Trading | Binance API (testnet + production) |

---

## Project Structure

```
├── lib/                         # Original Flutter app (buy/sell)
│   ├── models/
│   ├── screens/                 # Home, Trades, History, Settings
│   ├── services/
│   ├── utils/
│   └── widgets/
│
├── lib_hodler/                  # Hodler Flutter app (accumulation)
│   ├── models/                  # Extended models (+ PortfolioSummary)
│   ├── screens/                 # Home (score gauge), Portfolio, Settings (DCA), Trades, History
│   ├── services/                # BitcoinService (+ getPortfolio)
│   ├── utils/                   # ApiConfig (HODLER_API_BASE_URL)
│   ├── widgets/
│   └── main_hodler.dart         # Entry point (5-tab nav)
│
├── backend/
│   ├── lambda/                  # Original Lambda functions
│   │   ├── api_handler.py
│   │   ├── price_listener.py
│   │   ├── signal_analyzer.py
│   │   └── binance_trader.py
│   ├── lambda_hodler/           # Hodler Lambda functions
│   │   ├── api_handler.py       # + /portfolio endpoint
│   │   ├── price_listener.py    # + 24h volume
│   │   ├── signal_analyzer.py   # Accumulation score engine
│   │   └── binance_trader.py    # + execute_scaled_buy()
│   ├── tests/
│   │   ├── test_api.py          # Original integration tests
│   │   └── test_api_hodler.py   # Hodler integration tests
│   ├── requirements.txt
│   └── requirements_hodler.txt
│
├── .github/workflows/
│   ├── deploy.yml               # Deploys lambda/ on push to prod
│   └── hodler_deploy.yml        # Deploys lambda_hodler/ on push to hodler
│
├── flutter_run.sh
└── pytest.ini
```

---

## Running the App

### Prerequisites
- Flutter SDK
- Python 3.11+
- Doppler CLI (`brew install dopplerhq/cli/doppler`)
- Android emulator or device

### Original Version (Buy/Sell)

```bash
# Using Doppler (recommended) — runs lib/main.dart by default
./flutter_run.sh

# Or manually
flutter run -t lib/main.dart

# With a specific device
flutter run -t lib/main.dart -d <device-id>
```

### Hodler Version (Accumulation)

```bash
# Run the hodler app with default API
flutter run -t lib_hodler/main_hodler.dart

# With a custom hodler API base URL
flutter run -t lib_hodler/main_hodler.dart \
  --dart-define=HODLER_API_BASE_URL=https://your-hodler-api.amazonaws.com/prod

# With a specific device
flutter run -t lib_hodler/main_hodler.dart -d <device-id>
```

> **Note:** Both versions share the same `pubspec.yaml` and dependencies. The `-t` flag selects which entry point to use.

### Building for Release

```bash
# Original
flutter build apk -t lib/main.dart

# Hodler
flutter build apk -t lib_hodler/main_hodler.dart \
  --dart-define=HODLER_API_BASE_URL=https://your-hodler-api.amazonaws.com/prod
```

---

## Running API Tests

```bash
# Original tests
APIGW_REST_API_ID=o9tic8ti7h pytest backend/tests/test_api.py -v

# Hodler tests (includes /portfolio, enriched signal, new settings keys)
APIGW_REST_API_ID=o9tic8ti7h pytest backend/tests/test_api_hodler.py -v
```

---

## CI/CD

### Original (`deploy.yml`)
On push to `prod` (when `backend/lambda/**` files change):
1. **Deploy** — packages `backend/lambda/` code, uploads to S3, updates all 3 Lambda functions, re-deploys API Gateway
2. **Integration Tests** — runs pytest tests against the live API

Requires: `DOPPLER_TOKEN` in the `prod` GitHub environment.

### Hodler (`hodler_deploy.yml`)
On push to `hodler` (when `backend/lambda_hodler/**` files change):
1. **Deploy** — packages `backend/lambda_hodler/` code with `requirements_hodler.txt`, uploads to S3, updates all 3 Lambda functions, re-deploys API Gateway
2. **Integration Tests** — runs hodler-specific pytest tests against the live API

Requires: `DOPPLER_TOKEN` in the `hodler` GitHub environment.

---

## API Endpoints

Base URL: `https://<APIGW_REST_API_ID>.execute-api.ap-northeast-1.amazonaws.com/prod`

### Shared Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/currentPrice` | GET | Latest BTC price and signal |
| `/priceHistory?hours=N` | GET | Price history for last N hours |
| `/signalHistory?limit=N` | GET | Last N signal notifications |
| `/tradesHistory?limit=N` | GET | Last N executed trades |
| `/settings` | GET / POST | App configuration |

### Hodler-Only Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/portfolio` | GET | Accumulated BTC stack, avg cost basis, unrealized P&L, trade history |

### Hodler Enriched Responses

The hodler version enriches the `/currentPrice` signal with additional fields:

```json
{
  "signal": {
    "type": "BUY",
    "accumulation_score": 78.5,
    "buy_zone": true,
    "rsi": 28.3,
    "bb_lower": 62150.0,
    "fear_greed_index": 22,
    "fear_greed_label": "Extreme Fear",
    "dip_depth": 5.2,
    "confidence": 78.5
  }
}
```
