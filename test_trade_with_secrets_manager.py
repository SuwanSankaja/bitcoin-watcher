"""
Test Trade Execution with AWS Secrets Manager

This script tests if your Lambda can successfully execute trades using
credentials from AWS Secrets Manager (exactly like in production).

Usage:
    python test_trade_with_secrets_manager.py
"""

import sys
import json
import boto3
from datetime import datetime

# Import your binance_trader module
sys.path.append('backend/lambda')
from binance_trader import BinanceSpotTrader, get_binance_credentials_from_aws

# Color codes
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'

def test_secrets_manager_access():
    """Test if we can fetch credentials from AWS Secrets Manager"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test 1: AWS Secrets Manager Access{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    try:
        print(f"{Colors.YELLOW}Fetching Binance testnet credentials from AWS Secrets Manager...{Colors.END}")

        credentials = get_binance_credentials_from_aws(testnet=True)

        print(f"{Colors.GREEN}✓ Successfully retrieved credentials from Secrets Manager{Colors.END}")
        print(f"{Colors.WHITE}  Secret name: bitcoin-watcher-binance-testnet_new{Colors.END}")
        print(f"{Colors.WHITE}  API Key: {credentials['api_key'][:10]}...{Colors.END}")
        print(f"{Colors.WHITE}  API Secret: {credentials['api_secret'][:10]}...{Colors.END}")

        return credentials

    except Exception as e:
        print(f"{Colors.RED}✗ Failed to fetch credentials from Secrets Manager{Colors.END}")
        print(f"{Colors.RED}  Error: {e}{Colors.END}")
        return None

def test_binance_connection(credentials):
    """Test connection to Binance testnet"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test 2: Binance Testnet Connection{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    try:
        print(f"{Colors.YELLOW}Initializing Binance Spot Trader (testnet)...{Colors.END}")

        trader = BinanceSpotTrader(
            api_key=credentials['api_key'],
            api_secret=credentials['api_secret'],
            testnet=True
        )

        print(f"{Colors.GREEN}✓ Binance Spot Trader initialized{Colors.END}")
        print(f"{Colors.WHITE}  Base URL: {trader.base_url}{Colors.END}")
        print(f"{Colors.WHITE}  Testnet: {trader.testnet}{Colors.END}")

        return trader

    except Exception as e:
        print(f"{Colors.RED}✗ Failed to initialize trader{Colors.END}")
        print(f"{Colors.RED}  Error: {e}{Colors.END}")
        return None

def test_account_info(trader):
    """Test fetching account info"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test 3: Fetch Account Information{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    try:
        print(f"{Colors.YELLOW}Fetching account information...{Colors.END}")

        account_info = trader.get_account_info()

        if account_info:
            print(f"{Colors.GREEN}✓ Account info retrieved successfully{Colors.END}")
            print(f"{Colors.WHITE}  Account Type: {account_info.get('accountType', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Can Trade: {account_info.get('canTrade', False)}{Colors.END}")

            # Get balances
            balances = trader.get_balances()
            usdt_balance = balances.get('USDT', 0)
            btc_balance = balances.get('BTC', 0)

            print(f"\n{Colors.WHITE}  Current Balances:{Colors.END}")
            print(f"{Colors.WHITE}    USDT: ${usdt_balance:,.2f}{Colors.END}")
            print(f"{Colors.WHITE}    BTC: {btc_balance:.8f}{Colors.END}")

            return balances
        else:
            print(f"{Colors.RED}✗ Failed to get account info{Colors.END}")
            return None

    except Exception as e:
        print(f"{Colors.RED}✗ Error fetching account info{Colors.END}")
        print(f"{Colors.RED}  Error: {e}{Colors.END}")
        return None

def test_small_buy_trade(trader, balances):
    """Test a small BUY trade"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test 4: Execute Small BUY Trade ($10 USDT){Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    usdt_balance = balances.get('USDT', 0)

    if usdt_balance < 10:
        print(f"{Colors.RED}✗ Insufficient USDT balance (need at least $10){Colors.END}")
        print(f"{Colors.YELLOW}  Your balance: ${usdt_balance:.2f}{Colors.END}")
        return None

    try:
        print(f"{Colors.YELLOW}Executing BUY trade: $10 USDT worth of BTC...{Colors.END}")

        result = trader.execute_buy_signal(usdt_amount=10, symbol='BTCUSDT')

        if result and result.get('orderId'):
            print(f"{Colors.GREEN}✓ BUY trade executed successfully!{Colors.END}")
            print(f"\n{Colors.WHITE}Trade Details:{Colors.END}")
            print(f"{Colors.WHITE}  Order ID: {result.get('orderId', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Symbol: {result.get('symbol', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Side: {result.get('side', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Status: {result.get('status', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Executed Qty: {result.get('executedQty', 0)} BTC{Colors.END}")
            print(f"{Colors.WHITE}  Transaction Time: {result.get('transactTime', 'N/A')}{Colors.END}")

            return result
        else:
            print(f"{Colors.RED}✗ BUY trade failed{Colors.END}")
            if result:
                print(f"{Colors.RED}  Error: {result.get('error', 'Unknown error')}{Colors.END}")
            return None

    except Exception as e:
        print(f"{Colors.RED}✗ Exception during BUY trade{Colors.END}")
        print(f"{Colors.RED}  Error: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        return None

def test_small_sell_trade(trader):
    """Test a small SELL trade"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test 5: Execute Small SELL Trade (100% of BTC){Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    try:
        # Get current BTC balance
        balances = trader.get_balances()
        btc_balance = balances.get('BTC', 0)

        if btc_balance < 0.00001:
            print(f"{Colors.RED}✗ Insufficient BTC balance to sell{Colors.END}")
            print(f"{Colors.YELLOW}  Your balance: {btc_balance:.8f} BTC{Colors.END}")
            return None

        print(f"{Colors.YELLOW}Current BTC balance: {btc_balance:.8f} BTC{Colors.END}")
        print(f"{Colors.YELLOW}Executing SELL trade: 100% of BTC...{Colors.END}")

        result = trader.execute_sell_signal(btc_percentage=100, symbol='BTCUSDT')

        if result and result.get('orderId'):
            print(f"{Colors.GREEN}✓ SELL trade executed successfully!{Colors.END}")
            print(f"\n{Colors.WHITE}Trade Details:{Colors.END}")
            print(f"{Colors.WHITE}  Order ID: {result.get('orderId', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Symbol: {result.get('symbol', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Side: {result.get('side', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Status: {result.get('status', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Executed Qty: {result.get('executedQty', 0)} BTC{Colors.END}")
            print(f"{Colors.WHITE}  Transaction Time: {result.get('transactTime', 'N/A')}{Colors.END}")

            return result
        else:
            print(f"{Colors.RED}✗ SELL trade failed{Colors.END}")
            if result:
                print(f"{Colors.RED}  Error: {result.get('error', 'Unknown error')}{Colors.END}")
            return None

    except Exception as e:
        print(f"{Colors.RED}✗ Exception during SELL trade{Colors.END}")
        print(f"{Colors.RED}  Error: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        return None

def test_final_balances(trader, initial_balances):
    """Check final balances after trades"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test 6: Final Balance Check{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    try:
        final_balances = trader.get_balances()

        initial_usdt = initial_balances.get('USDT', 0)
        initial_btc = initial_balances.get('BTC', 0)
        final_usdt = final_balances.get('USDT', 0)
        final_btc = final_balances.get('BTC', 0)

        print(f"{Colors.WHITE}Balance Comparison:{Colors.END}\n")

        print(f"{Colors.WHITE}  USDT:{Colors.END}")
        print(f"{Colors.WHITE}    Initial: ${initial_usdt:,.2f}{Colors.END}")
        print(f"{Colors.WHITE}    Final:   ${final_usdt:,.2f}{Colors.END}")

        usdt_diff = final_usdt - initial_usdt
        color = Colors.GREEN if usdt_diff >= 0 else Colors.RED
        print(f"{color}    Change:  ${usdt_diff:+,.2f}{Colors.END}")

        print(f"\n{Colors.WHITE}  BTC:{Colors.END}")
        print(f"{Colors.WHITE}    Initial: {initial_btc:.8f}{Colors.END}")
        print(f"{Colors.WHITE}    Final:   {final_btc:.8f}{Colors.END}")

        btc_diff = final_btc - initial_btc
        color = Colors.GREEN if btc_diff >= 0 else Colors.RED
        print(f"{color}    Change:  {btc_diff:+.8f}{Colors.END}")

    except Exception as e:
        print(f"{Colors.RED}Error checking final balances: {e}{Colors.END}")

def main():
    """Main test function"""

    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Test Trade Execution with AWS Secrets Manager{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    print(f"{Colors.YELLOW}This script tests the complete trade flow using AWS Secrets Manager{Colors.END}")
    print(f"{Colors.YELLOW}(exactly like your Lambda function does in production){Colors.END}\n")

    print(f"{Colors.WHITE}Test will:{Colors.END}")
    print(f"{Colors.WHITE}  1. Fetch credentials from AWS Secrets Manager{Colors.END}")
    print(f"{Colors.WHITE}  2. Connect to Binance testnet{Colors.END}")
    print(f"{Colors.WHITE}  3. Check account info and balances{Colors.END}")
    print(f"{Colors.WHITE}  4. Execute a small BUY trade ($10 USDT){Colors.END}")
    print(f"{Colors.WHITE}  5. Execute a small SELL trade (100% of BTC bought){Colors.END}")
    print(f"{Colors.WHITE}  6. Compare final balances{Colors.END}\n")

    input(f"{Colors.CYAN}Press Enter to start tests...{Colors.END}")

    try:
        # Test 1: Fetch credentials from Secrets Manager
        credentials = test_secrets_manager_access()
        if not credentials:
            print(f"\n{Colors.RED}❌ TEST FAILED: Cannot access AWS Secrets Manager{Colors.END}")
            return False

        # Test 2: Connect to Binance
        trader = test_binance_connection(credentials)
        if not trader:
            print(f"\n{Colors.RED}❌ TEST FAILED: Cannot connect to Binance{Colors.END}")
            return False

        # Test 3: Get account info
        initial_balances = test_account_info(trader)
        if not initial_balances:
            print(f"\n{Colors.RED}❌ TEST FAILED: Cannot fetch account info{Colors.END}")
            return False

        # Test 4: Small BUY trade
        buy_result = test_small_buy_trade(trader, initial_balances)
        if not buy_result:
            print(f"\n{Colors.RED}❌ TEST FAILED: BUY trade failed{Colors.END}")
            return False

        # Test 5: Small SELL trade
        sell_result = test_small_sell_trade(trader)
        if not sell_result:
            print(f"\n{Colors.RED}❌ TEST FAILED: SELL trade failed{Colors.END}")
            return False

        # Test 6: Final balances
        test_final_balances(trader, initial_balances)

        # Summary
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}Test Summary{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

        print(f"{Colors.GREEN}✓ All tests passed successfully!{Colors.END}\n")
        print(f"{Colors.WHITE}Your Lambda can now:{Colors.END}")
        print(f"{Colors.GREEN}  ✓ Access Binance credentials from AWS Secrets Manager{Colors.END}")
        print(f"{Colors.GREEN}  ✓ Connect to Binance testnet API{Colors.END}")
        print(f"{Colors.GREEN}  ✓ Execute BUY trades{Colors.END}")
        print(f"{Colors.GREEN}  ✓ Execute SELL trades{Colors.END}")
        print(f"{Colors.GREEN}  ✓ Handle trades without 'Failed to connect' errors{Colors.END}\n")

        print(f"{Colors.CYAN}Your trading bot is ready for automated trading!{Colors.END}\n")

        return True

    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Test cancelled by user{Colors.END}")
        return False
    except Exception as e:
        print(f"\n{Colors.RED}Unexpected error: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
