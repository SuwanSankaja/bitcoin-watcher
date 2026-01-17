"""
Binance Connection Diagnostic Script

Tests your Binance API connection to identify the issue causing
"Failed to connect to Binance API" error.

Usage:
    python test_binance_connection.py
"""

import os
import sys
import hmac
import hashlib
import time
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

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

def test_binance_connection():
    """Test Binance API connection and diagnose issues"""

    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}Binance API Connection Diagnostic{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

    # Test 1: Check environment variables
    print(f"{Colors.BOLD}{Colors.BLUE}Test 1: Environment Variables{Colors.END}")

    api_key = os.getenv('BINANCE_TESTNET_API_KEY')
    api_secret = os.getenv('BINANCE_TESTNET_API_SECRET')

    if not api_key:
        print(f"{Colors.RED}✗ BINANCE_TESTNET_API_KEY not found in .env{Colors.END}")
        return False
    else:
        print(f"{Colors.GREEN}✓ BINANCE_TESTNET_API_KEY found: {api_key[:10]}...{Colors.END}")

    if not api_secret:
        print(f"{Colors.RED}✗ BINANCE_TESTNET_API_SECRET not found in .env{Colors.END}")
        return False
    else:
        print(f"{Colors.GREEN}✓ BINANCE_TESTNET_API_SECRET found: {api_secret[:10]}...{Colors.END}")

    print()

    # Test 2: Test public endpoint (no auth required)
    print(f"{Colors.BOLD}{Colors.BLUE}Test 2: Public API Endpoint (No Authentication){Colors.END}")

    testnet_url = "https://testnet.binance.vision"

    try:
        response = requests.get(f"{testnet_url}/api/v3/ping", timeout=10)
        if response.status_code == 200:
            print(f"{Colors.GREEN}✓ Can reach Binance testnet{Colors.END}")
            print(f"{Colors.WHITE}  URL: {testnet_url}{Colors.END}")
        else:
            print(f"{Colors.RED}✗ Binance testnet returned error: {response.status_code}{Colors.END}")
            print(f"{Colors.WHITE}  Response: {response.text}{Colors.END}")
            return False
    except requests.exceptions.Timeout:
        print(f"{Colors.RED}✗ Connection timeout - Network issue or firewall blocking{Colors.END}")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"{Colors.RED}✗ Connection error: {e}{Colors.END}")
        return False
    except Exception as e:
        print(f"{Colors.RED}✗ Unexpected error: {e}{Colors.END}")
        return False

    print()

    # Test 3: Get server time
    print(f"{Colors.BOLD}{Colors.BLUE}Test 3: Server Time Sync{Colors.END}")

    try:
        response = requests.get(f"{testnet_url}/api/v3/time", timeout=10)
        if response.status_code == 200:
            server_time = response.json()['serverTime']
            local_time = int(time.time() * 1000)
            time_diff = abs(server_time - local_time)

            print(f"{Colors.GREEN}✓ Server time retrieved{Colors.END}")
            print(f"{Colors.WHITE}  Server time: {server_time}{Colors.END}")
            print(f"{Colors.WHITE}  Local time:  {local_time}{Colors.END}")
            print(f"{Colors.WHITE}  Difference:  {time_diff}ms{Colors.END}")

            if time_diff > 5000:
                print(f"{Colors.YELLOW}  ⚠ Time difference > 5 seconds - may cause signature errors{Colors.END}")
        else:
            print(f"{Colors.RED}✗ Failed to get server time: {response.status_code}{Colors.END}")
            return False
    except Exception as e:
        print(f"{Colors.RED}✗ Error getting server time: {e}{Colors.END}")
        return False

    print()

    # Test 4: Test authenticated endpoint (account info)
    print(f"{Colors.BOLD}{Colors.BLUE}Test 4: Authenticated API Request (Account Info){Colors.END}")

    try:
        # Generate signature
        timestamp = int(time.time() * 1000)
        query_string = f"timestamp={timestamp}"
        signature = hmac.new(
            api_secret.encode('utf-8'),
            query_string.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        url = f"{testnet_url}/api/v3/account?{query_string}&signature={signature}"
        headers = {
            'X-MBX-APIKEY': api_key
        }

        print(f"{Colors.WHITE}  Sending authenticated request...{Colors.END}")
        response = requests.get(url, headers=headers, timeout=10)

        if response.status_code == 200:
            account_info = response.json()
            print(f"{Colors.GREEN}✓ Authentication successful!{Colors.END}")
            print(f"{Colors.WHITE}  Account Type: {account_info.get('accountType', 'N/A')}{Colors.END}")
            print(f"{Colors.WHITE}  Can Trade: {account_info.get('canTrade', False)}{Colors.END}")

            # Show balances
            balances = account_info.get('balances', [])
            non_zero = [b for b in balances if float(b['free']) > 0 or float(b['locked']) > 0]

            if non_zero:
                print(f"\n{Colors.WHITE}  Balances:{Colors.END}")
                for balance in non_zero[:5]:  # Show first 5
                    free = float(balance['free'])
                    locked = float(balance['locked'])
                    print(f"{Colors.WHITE}    {balance['asset']}: {free:.8f} (locked: {locked:.8f}){Colors.END}")

            return True

        elif response.status_code == 401:
            print(f"{Colors.RED}✗ Authentication failed (401 Unauthorized){Colors.END}")
            print(f"{Colors.YELLOW}  Possible causes:{Colors.END}")
            print(f"{Colors.WHITE}    - Invalid API key or secret{Colors.END}")
            print(f"{Colors.WHITE}    - API keys are for production, not testnet{Colors.END}")
            print(f"{Colors.WHITE}    - API keys expired or revoked{Colors.END}")
            print(f"\n{Colors.WHITE}  Response: {response.text}{Colors.END}")
            return False

        elif response.status_code == -1021:
            print(f"{Colors.RED}✗ Timestamp error (-1021){Colors.END}")
            print(f"{Colors.YELLOW}  Your system clock is out of sync with Binance{Colors.END}")
            return False

        else:
            print(f"{Colors.RED}✗ API request failed: {response.status_code}{Colors.END}")
            print(f"{Colors.WHITE}  Response: {response.text}{Colors.END}")
            return False

    except requests.exceptions.Timeout:
        print(f"{Colors.RED}✗ Request timeout during authentication{Colors.END}")
        return False
    except Exception as e:
        print(f"{Colors.RED}✗ Error during authentication: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        return False

    print()

def main():
    """Main function"""
    try:
        success = test_binance_connection()

        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}Diagnostic Summary{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*80}{Colors.END}\n")

        if success:
            print(f"{Colors.GREEN}✓ All tests passed! Your Binance API connection is working.{Colors.END}\n")
            print(f"{Colors.WHITE}The 'Failed to connect to Binance API' error is likely happening in Lambda.{Colors.END}\n")
            print(f"{Colors.YELLOW}Possible Lambda issues:{Colors.END}")
            print(f"{Colors.WHITE}  1. AWS Secrets Manager doesn't have the testnet credentials{Colors.END}")
            print(f"{Colors.WHITE}  2. Lambda doesn't have permission to access Secrets Manager{Colors.END}")
            print(f"{Colors.WHITE}  3. Lambda VPC settings blocking outbound internet access{Colors.END}")
            print(f"{Colors.WHITE}  4. Incorrect secret name in Lambda code{Colors.END}\n")
            print(f"{Colors.CYAN}Next steps:{Colors.END}")
            print(f"{Colors.WHITE}  1. Check AWS Secrets Manager has 'bitcoin-watcher-binance-testnet' secret{Colors.END}")
            print(f"{Colors.WHITE}  2. Verify Lambda has SecretsManagerReadWrite policy{Colors.END}")
            print(f"{Colors.WHITE}  3. Check Lambda is not in a VPC (or has NAT gateway if it is){Colors.END}")
        else:
            print(f"{Colors.RED}✗ Connection test failed!{Colors.END}\n")
            print(f"{Colors.YELLOW}Common solutions:{Colors.END}")
            print(f"{Colors.WHITE}  1. Verify API keys are from testnet.binance.vision (not production){Colors.END}")
            print(f"{Colors.WHITE}  2. Check .env file has correct BINANCE_TESTNET_API_KEY and SECRET{Colors.END}")
            print(f"{Colors.WHITE}  3. Regenerate API keys at https://testnet.binance.vision{Colors.END}")
            print(f"{Colors.WHITE}  4. Ensure no firewall blocking access to testnet.binance.vision{Colors.END}")

        print()

    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Test cancelled{Colors.END}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Colors.RED}Unexpected error: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
