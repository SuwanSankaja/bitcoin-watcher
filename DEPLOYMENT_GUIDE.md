# Deployment Guide - Bitcoin Watcher Signal Analyzer Fix

## Changes Made

### 1. **Fixed Inverted BUY/SELL Logic** (CRITICAL)
- **File**: `backend/lambda/signal_analyzer.py`
- **Problem**: Signals were inverted - BUY when price high, SELL when price low
- **Fix**: Corrected logic:
  - **BUY**: When short MA < long MA (price dipping - buy opportunity)
  - **SELL**: When short MA > long MA (price peaking - take profit)

### 2. **Improved Default Settings - DAY TRADING**
- **Files**: `backend/lambda/signal_analyzer.py`, `bitcoin_watcher.settings.json`
- **Changes**:
  - `buy_threshold`: 0.005 → 0.008 (0.8% for day trading)
  - `sell_threshold`: 0.005 → 0.008 (0.8% for day trading)
  - `short_ma_period`: 7 → 5 (fast reaction)
  - `long_ma_period`: 21 → 15 (quick trend detection)
- **Note**: These are DAY TRADING settings (3-8 signals/day). See [DAY_TRADING_CONFIG.md](DAY_TRADING_CONFIG.md) for alternatives.

---

## Deployment Steps

### Option A: AWS Lambda Console (Easiest)

#### Step 1: Update Lambda Function Code

1. **Go to AWS Console** → **Lambda** → Find your `signal_analyzer` function

2. **Update the code**:
   - Click on the **Code** tab
   - Find the `signal_analyzer.py` file in the editor
   - Copy the entire content from your local file:
     ```
     backend/lambda/signal_analyzer.py
     ```
   - Paste it into the Lambda console editor
   - Click **Deploy** button (top right)

3. **Wait for deployment**:
   - You'll see "Successfully deployed" message
   - This usually takes 5-10 seconds

#### Step 2: Update MongoDB Settings (IMPORTANT)

You need to update your MongoDB database with the new settings:

1. **Connect to MongoDB**:
   - Using MongoDB Compass, mongosh, or your preferred client
   - Connect using your connection string

2. **Update the settings collection**:
   ```javascript
   use bitcoin_watcher

   // DAY TRADING SETTINGS (3-8 signals per day)
   db.settings.updateOne(
     { "_id": "default" },
     {
       $set: {
         "settings.buy_threshold": 0.008,
         "settings.sell_threshold": 0.008,
         "settings.short_ma_period": 5,
         "settings.long_ma_period": 15,
         "updated_at": new Date()
       }
     }
   )
   ```

   **Alternative: For Swing Trading (1-3 signals per week):**
   ```javascript
   db.settings.updateOne(
     { "_id": "default" },
     {
       $set: {
         "settings.buy_threshold": 0.015,
         "settings.sell_threshold": 0.015,
         "settings.short_ma_period": 12,
         "settings.long_ma_period": 26,
         "updated_at": new Date()
       }
     }
   )
   ```

3. **Verify the update**:
   ```javascript
   db.settings.findOne({ "_id": "default" })
   ```

   You should see (Day Trading):
   ```json
   {
     "_id": "default",
     "settings": {
       "notifications_enabled": true,
       "buy_threshold": 0.008,
       "sell_threshold": 0.008,
       "short_ma_period": 5,
       "long_ma_period": 15
     },
     "updated_at": ISODate("...")
   }
   ```

#### Step 3: Test the Deployment

1. **Manual Test** (Optional):
   - In AWS Lambda console, click **Test** tab
   - Create a test event (if not exists) with empty JSON: `{}`
   - Click **Test**
   - Check the output logs for any errors

2. **Monitor CloudWatch Logs**:
   - Go to **CloudWatch** → **Log groups**
   - Find `/aws/lambda/signal_analyzer` (or your function name)
   - Check recent logs after the next scheduled run
   - Look for the line: `Using MA periods: 5/15, Thresholds: 0.008/0.008` (Day Trading)

3. **Wait for Next Signal**:
   - Your EventBridge rule should trigger the function automatically
   - Check the `notifications` collection in MongoDB for new signals
   - Verify the logic is correct:
     - BUY signals appear when price is dipping
     - SELL signals appear when price is rising

---

### Option B: AWS CLI Deployment

If you prefer command-line deployment:

#### Step 1: Package the Lambda Function

```bash
cd backend/lambda

# Create deployment package
zip -r signal_analyzer.zip signal_analyzer.py

# If you have dependencies
cd ../packages
zip -r ../lambda/signal_analyzer.zip .
cd ../lambda
```

#### Step 2: Deploy to AWS Lambda

```bash
aws lambda update-function-code \
  --function-name signal_analyzer \
  --zip-file fileb://signal_analyzer.zip \
  --region your-region
```

Replace `your-region` with your AWS region (e.g., `us-east-1`).

#### Step 3: Update MongoDB Settings

Same as Option A, Step 2.

---

### Option C: Infrastructure as Code (Terraform/SAM)

If you're using IaC, update your code and redeploy:

```bash
# For SAM
sam build
sam deploy

# For Terraform
terraform apply
```

Then update MongoDB settings as per Option A, Step 2.

---

## Post-Deployment Verification

### 1. Check Lambda Logs (CloudWatch)

```bash
aws logs tail /aws/lambda/signal_analyzer --follow
```

Look for:
- ✅ `Using MA periods: 12/26, Thresholds: 0.015/0.015`
- ✅ `Signal analyzed successfully`
- ❌ No error messages

### 2. Monitor Signal Quality

Over the next few days, observe:
- **Fewer false signals**: With 1.5% threshold, you should see less noise
- **Correct timing**:
  - BUY signals during price dips
  - SELL signals during price peaks
- **Signal stability**: Less frequent signal changes

### 3. Verify in Mobile App

- Open your Flutter app
- Check notifications
- Verify signal types match market conditions

---

## Rollback Plan (If Needed)

If something goes wrong:

### Rollback Lambda Code:

1. **AWS Console**:
   - Lambda → Your function → **Versions** tab
   - Find previous version
   - Click **Actions** → **Publish new version**

2. **Restore Old Settings**:
   ```javascript
   db.settings.updateOne(
     { "_id": "default" },
     {
       $set: {
         "settings.buy_threshold": 0.005,
         "settings.sell_threshold": 0.005,
         "settings.short_ma_period": 7,
         "settings.long_ma_period": 21
       }
     }
   )
   ```

---

## Expected Behavior After Fix

### Before Fix (OLD - WRONG):
- BUY at $100,504 → Price drops to $99,148 ❌ (Loss)
- SELL at $110,736 → Price drops to $105,884 ❌ (Sold into falling market)

### After Fix (NEW - CORRECT):
- BUY when price dips below moving average ✅ (Buy low)
- SELL when price rises above moving average ✅ (Sell high)

---

## Troubleshooting

### Issue: Lambda doesn't update
**Solution**:
- Check Lambda execution role has permissions
- Ensure deployment package is correct
- Check CloudWatch logs for errors

### Issue: Settings not changing
**Solution**:
- Verify MongoDB connection from Lambda
- Check MongoDB settings collection
- Ensure SSM parameter for MongoDB URI is correct

### Issue: Still getting wrong signals
**Solution**:
- Clear signals collection: `db.signals.deleteMany({})`
- Wait for fresh data (30+ minutes)
- Verify code was actually deployed (check version in Lambda console)

---

## Questions?

If you encounter any issues:
1. Check CloudWatch logs first
2. Verify MongoDB settings
3. Test Lambda function manually
4. Check EventBridge rule is enabled

---

## Summary Checklist

- [ ] Deploy updated `signal_analyzer.py` to AWS Lambda
- [ ] Update MongoDB `settings` collection
- [ ] Verify deployment in CloudWatch logs
- [ ] Monitor signals for correctness
- [ ] Test mobile app notifications
- [ ] Celebrate fixing the bug! 🎉
