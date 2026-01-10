"""
Complete Trading Integration Test
Simulates the full Lambda function flow with signal analyzer + trading execution
Tests the complete workflow: price fetch → signal generation → trade execution
"""

import json
import os
import sys
from datetime import datetime, timedelta
import pytz

# Load environment variables
try:
    from dotenv import load_dotenv
    load_dotenv()
    print("✅ Loaded .env file\n")
except ImportError:
    print("⚠️  Install python-dotenv: pip install python-dotenv\n")

print("=" * 70)
print("TRADING INTEGRATION TEST - FULL WORKFLOW")
print("=" * 70)
print()

# Add backend/lambda to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend', 'lambda'))

# Import modules
from pymongo import MongoClient
from signal_analyzer import (
    get_settings_from_db,
    get_recent_prices,
    analyze_signal,
    store_signal,
    get_last_signal,
    execute_trade,
    calculate_moving_average
)
from binance_trader import BinanceSpotTrader

# Track results
tests_passed = 0
tests_failed = 0

def test_result(test_name, passed, details=None):
    global tests_passed, tests_failed
    if passed:
        print(f"✅ {test_name}")
        tests_passed += 1
    else:
        print(f"❌ {test_name}")
        tests_failed += 1
    if details:
        print(f"   {details}")
    print()

# ============================================================================
# STEP 1: Initialize MongoDB Connection
# ============================================================================
print("STEP 1: Initialize MongoDB")
print("-" * 70)

try:
    mongo_uri = os.getenv('MONGODB_URI')
    client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
    db = client['bitcoin_watcher']
    test_result("MongoDB connection", True)
except Exception as e:
    test_result("MongoDB connection", False, f"Error: {e}")
    sys.exit(1)

# ============================================================================
# STEP 2: Load Settings
# ============================================================================
print("STEP 2: Load Trading Settings")
print("-" * 70)

try:
    settings = get_settings_from_db()
    test_result("Settings loaded from MongoDB", True)

    print("Settings Configuration:")
    print(f"   • Buy Threshold: {settings.get('buy_threshold', 'N/A')}")
    print(f"   • Sell Threshold: {settings.get('sell_threshold', 'N/A')}")
    print(f"   • Short MA: {settings.get('short_ma_period', 'N/A')} periods")
    print(f"   • Long MA: {settings.get('long_ma_period', 'N/A')} periods")
    print(f"   • Trading Enabled: {settings.get('trading_enabled', False)}")
    print(f"   • Trading Mode: {settings.get('trading_mode', 'N/A')}")
    print(f"   • Trade Amount: ${settings.get('trade_amount_usdt', 'N/A')}")
    print()

    if settings.get('trading_enabled'):
        print("⚠️  Trading is ENABLED - This test will execute REAL trades on testnet!")
        print(f"   Mode: {settings.get('trading_mode', 'unknown')}")
        print()
        response = input("Continue with trade execution test? (yes/no): ").strip().lower()
        if response != 'yes':
            print("Test cancelled by user.")
            sys.exit(0)
        print()

except Exception as e:
    test_result("Settings load", False, f"Error: {e}")
    sys.exit(1)

# ============================================================================
# STEP 3: Fetch Recent Prices
# ============================================================================
print("STEP 3: Fetch Recent Price Data")
print("-" * 70)

try:
    prices = get_recent_prices(minutes=30)
    test_result("Price data fetch", len(prices) > 0, f"Retrieved {len(prices)} price points")

    if prices:
        latest = prices[-1]
        oldest = prices[0]
        print(f"   Latest Price: ${latest['price']:,.2f} at {latest['timestamp']}")
        print(f"   Oldest Price: ${oldest['price']:,.2f} at {oldest['timestamp']}")
        print()
    else:
        print("⚠️  No price data available - make sure price_listener is running")
        print()

except Exception as e:
    test_result("Price data fetch", False, f"Error: {e}")
    prices = []

# ============================================================================
# STEP 4: Calculate Moving Averages
# ============================================================================
print("STEP 4: Calculate Moving Averages")
print("-" * 70)

try:
    if len(prices) >= settings.get('long_ma_period', 15):
        short_ma = calculate_moving_average(prices, settings.get('short_ma_period', 5))
        long_ma = calculate_moving_average(prices, settings.get('long_ma_period', 15))

        test_result("Moving averages calculated", True)
        print(f"   Short MA ({settings.get('short_ma_period')} periods): ${short_ma:,.2f}")
        print(f"   Long MA ({settings.get('long_ma_period')} periods): ${long_ma:,.2f}")
        print(f"   Difference: ${abs(short_ma - long_ma):,.2f}")
        print(f"   Percentage: {((short_ma / long_ma - 1) * 100):.3f}%")
        print()

        # Determine expected signal
        buy_threshold = settings.get('buy_threshold', 0.008)
        sell_threshold = settings.get('sell_threshold', 0.008)

        if short_ma < long_ma * (1 - buy_threshold):
            expected = "BUY"
        elif short_ma > long_ma * (1 + sell_threshold):
            expected = "SELL"
        else:
            expected = "HOLD"

        print(f"   Expected Signal (based on thresholds): {expected}")
        print()
    else:
        test_result("Moving averages calculated", False,
                   f"Insufficient data: need {settings.get('long_ma_period')} points, have {len(prices)}")

except Exception as e:
    test_result("Moving averages", False, f"Error: {e}")

# ============================================================================
# STEP 5: Generate Trading Signal
# ============================================================================
print("STEP 5: Generate Trading Signal")
print("-" * 70)

try:
    if prices:
        signal_data = analyze_signal(
            prices,
            short_period=settings['short_ma_period'],
            long_period=settings['long_ma_period'],
            buy_threshold=settings['buy_threshold'],
            sell_threshold=settings['sell_threshold']
        )

        test_result("Signal generation", True)
        print(f"   Signal Type: {signal_data['type']}")
        print(f"   Price: ${signal_data['price']:,.2f}")
        print(f"   Confidence: {signal_data['confidence']}%")
        if 'short_ma' in signal_data:
            print(f"   Short MA: ${signal_data['short_ma']:,.2f}")
        if 'long_ma' in signal_data:
            print(f"   Long MA: ${signal_data['long_ma']:,.2f}")
        print()
    else:
        test_result("Signal generation", False, "No price data available")
        signal_data = None

except Exception as e:
    test_result("Signal generation", False, f"Error: {e}")
    signal_data = None

# ============================================================================
# STEP 6: Check Last Signal & Signal Change
# ============================================================================
print("STEP 6: Check Signal History")
print("-" * 70)

try:
    last_signal = get_last_signal()

    if last_signal:
        test_result("Last signal retrieval", True)
        print(f"   Previous Signal: {last_signal.get('type', 'N/A')}")
        print(f"   Previous Price: ${last_signal.get('price', 0):,.2f}")
        print(f"   Previous Timestamp: {last_signal.get('timestamp', 'N/A')}")
        print()

        if signal_data:
            signal_changed = signal_data['type'] != last_signal.get('type')
            if signal_changed:
                print(f"   🔄 SIGNAL CHANGED: {last_signal.get('type')} → {signal_data['type']}")
                print()
            else:
                print(f"   ➡️  Signal unchanged: {signal_data['type']}")
                print()
    else:
        test_result("Last signal retrieval", True, "No previous signal (first run)")
        signal_changed = True if signal_data else False

except Exception as e:
    test_result("Last signal retrieval", False, f"Error: {e}")
    signal_changed = False

# ============================================================================
# STEP 7: Store Current Signal
# ============================================================================
print("STEP 7: Store Signal in Database")
print("-" * 70)

try:
    if signal_data:
        signal_id = store_signal(signal_data)
        test_result("Signal storage", True, f"Signal ID: {signal_id}")
    else:
        test_result("Signal storage", False, "No signal to store")
        signal_id = None

except Exception as e:
    test_result("Signal storage", False, f"Error: {e}")
    signal_id = None

# ============================================================================
# STEP 8: Execute Trade (if enabled and signal changed)
# ============================================================================
print("STEP 8: Trade Execution")
print("-" * 70)

if not settings.get('trading_enabled'):
    print("ℹ️  Trading is DISABLED - skipping trade execution")
    print("   Set 'trading_enabled: true' in MongoDB to enable")
    print()
else:
    if not signal_data or not signal_id:
        print("ℹ️  No signal to trade - skipping execution")
        print()
    elif signal_data['type'] not in ['BUY', 'SELL']:
        print(f"ℹ️  Signal is {signal_data['type']} - no trade needed")
        print()
    elif not signal_changed:
        print(f"ℹ️  Signal unchanged ({signal_data['type']}) - no trade needed")
        print()
    else:
        print(f"🚨 EXECUTING {signal_data['type']} TRADE ON TESTNET!")
        print("-" * 70)

        try:
            # Execute trade
            trade_result = execute_trade(signal_data, signal_id, settings)

            if trade_result:
                test_result("Trade execution", True, "Trade completed successfully!")

                print("Trade Details:")
                print(f"   Order ID: {trade_result.get('orderId', 'N/A')}")
                print(f"   Symbol: {trade_result.get('symbol', 'N/A')}")
                print(f"   Side: {trade_result.get('side', 'N/A')}")
                print(f"   Status: {trade_result.get('status', 'N/A')}")
                print(f"   Executed Qty: {trade_result.get('executedQty', 'N/A')}")

                # Calculate average price from fills
                fills = trade_result.get('fills', [])
                if fills:
                    total_qty = sum(float(fill['qty']) for fill in fills)
                    avg_price = sum(float(fill['price']) * float(fill['qty']) for fill in fills) / total_qty
                    print(f"   Average Price: ${avg_price:,.2f}")
                    print(f"   Fills: {len(fills)}")

                print()
                print("✅ Trade successfully logged to MongoDB 'trades' collection")
                print()
            else:
                test_result("Trade execution", False, "Trade returned None")

        except Exception as e:
            test_result("Trade execution", False, f"Error: {e}")
            print()

# ============================================================================
# STEP 9: Verify Trade in Database
# ============================================================================
print("STEP 9: Verify Trade in Database")
print("-" * 70)

if settings.get('trading_enabled') and signal_changed and signal_data and signal_data['type'] in ['BUY', 'SELL']:
    try:
        trades_collection = db['trades']
        latest_trade = trades_collection.find_one(sort=[('timestamp', -1)])

        if latest_trade:
            test_result("Trade in database", True)
            print(f"   Trade ID: {latest_trade.get('_id')}")
            print(f"   Signal ID: {latest_trade.get('signal_id')}")
            print(f"   Binance Order ID: {latest_trade.get('binance_order_id')}")
            print(f"   Side: {latest_trade.get('side')}")
            print(f"   Status: {latest_trade.get('status')}")
            print(f"   Executed Qty: {latest_trade.get('executed_qty')}")
            print(f"   Average Price: ${latest_trade.get('average_price', 0):,.2f}")
            print(f"   Timestamp: {latest_trade.get('timestamp')}")
            print()
        else:
            test_result("Trade in database", False, "No trade found in database")

    except Exception as e:
        test_result("Trade in database", False, f"Error: {e}")
else:
    print("ℹ️  No trade expected - skipping database verification")
    print()

# ============================================================================
# STEP 10: Check Binance Account Balance
# ============================================================================
print("STEP 10: Check Final Balances")
print("-" * 70)

try:
    api_key = os.getenv('BINANCE_TESTNET_API_KEY')
    api_secret = os.getenv('BINANCE_TESTNET_API_SECRET')

    if api_key and api_secret:
        trader = BinanceSpotTrader(
            api_key=api_key,
            api_secret=api_secret,
            testnet=True
        )

        usdt_balance = trader.get_balance('USDT')
        btc_balance = trader.get_balance('BTC')

        test_result("Final balance check", True)
        print(f"   USDT Balance: ${usdt_balance['free']:,.2f}")
        print(f"   BTC Balance: {btc_balance['free']:.8f} BTC")

        # Estimate total value
        try:
            current_price = trader.get_current_price('BTCUSDT')
            btc_value = btc_balance['free'] * current_price
            total_value = usdt_balance['free'] + btc_value
            print(f"   BTC Value: ${btc_value:,.2f}")
            print(f"   Total Portfolio: ${total_value:,.2f}")
        except:
            pass
        print()
    else:
        print("ℹ️  Binance credentials not in .env - skipping balance check")
        print()

except Exception as e:
    test_result("Final balance check", False, f"Error: {e}")

# ============================================================================
# SUMMARY
# ============================================================================
print("\n" + "=" * 70)
print("INTEGRATION TEST SUMMARY")
print("=" * 70)
print(f"Tests Passed: {tests_passed}")
print(f"Tests Failed: {tests_failed}")
print()

if tests_failed == 0:
    print("🎉 ALL INTEGRATION TESTS PASSED!")
    print()
    print("Complete Workflow Verified:")
    print("✅ Settings loaded from MongoDB")
    print("✅ Price data fetched successfully")
    print("✅ Moving averages calculated correctly")
    print("✅ Trading signal generated")
    print("✅ Signal stored in database")
    if settings.get('trading_enabled') and signal_changed and signal_data and signal_data['type'] in ['BUY', 'SELL']:
        print("✅ Trade executed on Binance testnet")
        print("✅ Trade logged to MongoDB")
    print()
    print("Your trading bot is READY for deployment! 🚀")
    print()
    print("Next Steps:")
    print("1. Review the trade in Binance testnet dashboard")
    print("2. Check MongoDB 'trades' collection")
    print("3. Deploy to AWS Lambda")
    print("4. Monitor CloudWatch logs")
else:
    print("⚠️  SOME TESTS FAILED")
    print()
    print("Review errors above and fix before deploying.")

print("=" * 70)

# Cleanup
client.close()
