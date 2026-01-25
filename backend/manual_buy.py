import os
import sys
from dotenv import load_dotenv

# Add lambda directory to path to import binance_trader
sys.path.append(os.path.join(os.path.dirname(__file__), 'lambda'))

from binance_trader import BinanceSpotTrader

# Load environment variables
load_dotenv()

def print_header(msg):
    print(f"\n{'='*50}")
    print(f" {msg}")
    print(f"{'='*50}")

def main():
    print_header("MANUAL BUY SCRIPT (TESTNET)")

    # 1. Get credentials from .env
    api_key = os.getenv('BINANCE_TESTNET_API_KEY')
    api_secret = os.getenv('BINANCE_TESTNET_API_SECRET')

    if not api_key or not api_secret:
        print("❌ Error: Missing BINANCE_TESTNET_API_KEY or BINANCE_TESTNET_API_SECRET in .env")
        return

    # 2. Initialize Trader
    try:
        trader = BinanceSpotTrader(
            api_key=api_key,
            api_secret=api_secret,
            testnet=True
        )
        trader.test_connection()
    except Exception as e:
        print(f"❌ Failed to connect to Binance: {e}")
        return

    # 3. Check Balances
    print("\n🔍 Checking Account Balances...")
    try:
        balances = trader.get_balances()
        btc_balance = balances.get('BTC', 0.0)
        usdt_balance = balances.get('USDT', 0.0)
        
        print(f"   BTC Balance:  {btc_balance:.8f}")
        print(f"   USDT Balance: {usdt_balance:.2f}")

        if usdt_balance <= 10:
            print("\n❌ Error: Insufficient USDT. You need at least 10 USDT to trade.")
            return

    except Exception as e:
        print(f"❌ Failed to fetch balances: {e}")
        return

    # 4. Ask for Amount
    print_header("ENTER AMOUNT")
    try:
        amount_input = input(f"Enter USDT amount to spend (Max: {usdt_balance:.2f}): ")
        amount = float(amount_input)
        
        if amount <= 0 or amount > usdt_balance:
            print("❌ Invalid amount.")
            return
    except ValueError:
        print("❌ Invalid input.")
        return

    # 5. Confirm Buy
    print(f"\nYou are about to buy BTC with ${amount:.2f} USDT.")
    confirm = input("Type 'BUY' to confirm: ")

    if confirm.strip() != 'BUY':
        print("❌ Buy cancelled.")
        return

    # 6. Execute Buy
    print("\n🚀 Executing market buy...")
    try:
        result = trader.execute_buy_signal(usdt_amount=amount)
        
        if result:
            print("\n✅ SUCCESS! Bought BTC.")
            print("New Balances:")
            new_balances = trader.get_balances()
            print(f"   BTC Balance:  {new_balances.get('BTC', 0.0):.8f}")
            print(f"   USDT Balance: {new_balances.get('USDT', 0.0):.2f}")
    except Exception as e:
        print(f"\n❌ Buy failed: {e}")

if __name__ == "__main__":
    main()
