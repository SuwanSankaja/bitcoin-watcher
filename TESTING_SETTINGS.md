# Check Bitcoin Watcher Settings

## Method 1: Check MongoDB
```powershell
# Run the test script (update MONGO_URI first)
python test_check_settings.py
```

## Method 2: Check CloudWatch Logs
```powershell
# View latest signal_analyzer logs
aws logs tail /aws/lambda/bitcoin-signal-analyzer --follow --region us-east-1

# Look for lines like:
# "Using settings from MongoDB: {'notifications_enabled': True, 'buy_threshold': 0.001, ...}"
# "Using MA periods: 7/21, Thresholds: 0.001/0.001"
```

## Method 3: Test from Flutter App
1. Change a setting in the app (e.g., threshold 0.5% → 0.1%)
2. Tap Save
3. Close and reopen the app
4. Settings should still show 0.1% (persisted)

## Method 4: Check via API Endpoint
```powershell
# GET current settings
curl https://25sm56ym2c.execute-api.us-east-1.amazonaws.com/prod/settings

# Should return:
# {
#   "notifications_enabled": true,
#   "buy_threshold": 0.001,
#   "sell_threshold": 0.001,
#   "short_ma_period": 7,
#   "long_ma_period": 21
# }
```

## Method 5: Manual Lambda Test
```powershell
# Invoke signal_analyzer manually
aws lambda invoke --function-name bitcoin-signal-analyzer --region us-east-1 response.json

# Check response.json for settings used
cat response.json

# Then check CloudWatch logs
aws logs tail /aws/lambda/bitcoin-signal-analyzer --since 1m --region us-east-1
```

## What to Look For

### If Settings Are Working:
- CloudWatch shows: `"Using MA periods: 7/21, Thresholds: 0.001/0.001"` (your values)
- API returns your custom thresholds
- MongoDB has document with your settings

### If Settings Aren't Working:
- CloudWatch shows: `"No settings found in MongoDB, using defaults"`
- CloudWatch shows: `"Using MA periods: 7/21, Thresholds: 0.005/0.005"` (defaults)
- API returns 404 or empty response
