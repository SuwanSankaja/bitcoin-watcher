# Settings Sync Implementation

## Overview
The app now supports dynamic configuration of algorithm parameters. Settings changed in the Flutter app will be stored in MongoDB and read by the Lambda function every time it analyzes prices.

## Settings Available

### Algorithm Parameters
- **Short MA Period**: Number of minutes for short-term moving average (default: 7)
- **Long MA Period**: Number of minutes for long-term moving average (default: 21)
- **Buy Threshold**: Percentage difference needed to trigger BUY signal (default: 0.5% = 0.005)
- **Sell Threshold**: Percentage difference needed to trigger SELL signal (default: 0.5% = 0.005)

### Notification Control
- **Notifications Enabled**: Toggle to enable/disable push notifications (default: true)

## Architecture

### Data Flow
```
Flutter App (Settings Screen)
    ↓ POST /settings
API Gateway → Lambda (api_handler.py)
    ↓ upsert to MongoDB
Settings Collection {_id: 'default'}
    ↑ read every 2 minutes
Lambda (signal_analyzer.py)
    → Uses dynamic thresholds/periods
    → Checks notifications_enabled flag
```

### MongoDB Collection
**Collection**: `bitcoin_watcher.settings`

**Document Structure**:
```json
{
  "_id": "default",
  "settings": {
    "notifications_enabled": true,
    "buy_threshold": 0.005,
    "sell_threshold": 0.005,
    "short_ma_period": 7,
    "long_ma_period": 21
  },
  "updated_at": ISODate("2024-01-15T10:30:00.000Z")
}
```

## Implementation Details

### Backend (Lambda)

#### api_handler.py
- **GET /settings**: Returns current settings from MongoDB (or defaults if not found)
- **POST /settings**: Validates and stores settings in MongoDB
  - Type validation: float for thresholds, int for periods, bool for notifications
  - Uses upsert to create/update document
  - Stores timestamp for audit trail

#### signal_analyzer.py
- **get_settings_from_db()**: Fetches settings at the start of each analysis cycle
  - Falls back to defaults on error
  - Merges stored settings with defaults (handles new settings additions)
- **lambda_handler()**: Passes dynamic settings to analyze_signal()
- **Notification check**: Respects notifications_enabled flag

### Frontend (Flutter)

#### services/bitcoin_service.dart
- **getSettings()**: GET /settings
- **updateSettings()**: POST /settings with JSON body

#### screens/settings_screen.dart
- Sliders for thresholds (0.1% - 5.0%)
- Sliders for MA periods (5 - 50 minutes)
- Switch for notifications
- Saves to backend via BitcoinService

## Testing

### 1. Update Settings in App
```
1. Open Flutter app
2. Navigate to Settings screen
3. Change thresholds (e.g., 0.5% → 1.0%)
4. Change MA periods (e.g., 7/21 → 10/30)
5. Toggle notifications
6. Tap Save
```

### 2. Verify MongoDB Storage
```javascript
use bitcoin_watcher;
db.settings.find({_id: 'default'}).pretty();

// Should show updated values
```

### 3. Check Lambda Logs
```bash
# Wait for next signal_analyzer run (every 2 minutes)
# Check CloudWatch logs for:
"Using MA periods: 10/30, Thresholds: 0.01/0.01"
"Using settings from MongoDB: {'notifications_enabled': True, ...}"
```

### 4. Verify Signal Generation
```
1. Wait for 30+ minutes of price data
2. Signals should use new thresholds
3. Confidence calculation reflects new settings
4. Notifications only sent if enabled
```

## Deployment

### Deploy Updated Lambda Functions
```powershell
cd backend\lambda

# Package and deploy api_handler
Remove-Item -Path api_handler.zip -ErrorAction SilentlyContinue
Compress-Archive -Path api_handler.py -DestinationPath api_handler.zip
aws lambda update-function-code `
  --function-name bitcoin-api-handler `
  --zip-file fileb://api_handler.zip `
  --region us-east-1

# Package and deploy signal_analyzer
Remove-Item -Path signal_analyzer.zip -ErrorAction SilentlyContinue
Compress-Archive -Path signal_analyzer.py -DestinationPath signal_analyzer.zip
aws lambda update-function-code `
  --function-name bitcoin-signal-analyzer `
  --zip-file fileb://signal_analyzer.zip `
  --region us-east-1
```

## Troubleshooting

### Settings Not Persisting
- Check API Gateway logs for POST /settings errors
- Verify MongoDB connection string in Parameter Store
- Check Lambda execution role has ssm:GetParameter permission

### Lambda Still Using Old Values
- Check CloudWatch logs for "Using settings from MongoDB" message
- Verify MongoDB document exists: `db.settings.find({_id: 'default'})`
- Check for error logs: "Error fetching settings from MongoDB"

### Notifications Still Sent When Disabled
- Verify MongoDB has `notifications_enabled: false`
- Check signal_analyzer logs for "Notifications disabled in settings"
- Wait for next signal cycle (2 minutes)

## Default Values

If settings collection is empty or errors occur, Lambda uses these defaults:
```python
{
    'notifications_enabled': True,
    'buy_threshold': 0.005,      # 0.5%
    'sell_threshold': 0.005,     # 0.5%
    'short_ma_period': 7,        # 7 minutes
    'long_ma_period': 21         # 21 minutes
}
```

## Notes

- Settings are read every 2 minutes (signal_analyzer EventBridge schedule)
- No app restart needed - changes take effect on next analysis cycle
- Settings are global (apply to all users/devices)
- Type validation prevents invalid values (e.g., negative thresholds)
- Merged settings pattern allows adding new settings without breaking existing code
