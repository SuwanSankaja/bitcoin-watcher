import os
import requests
import boto3
import json
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

REGION = 'ap-northeast-1'
API_URL = os.getenv('API_BASE_URL')

def print_status(msg):
    print(f"\n{'='*60}")
    print(f" {msg}")
    print(f"{'='*60}")

def test_api_gateway():
    print_status("TEST 1: API Gateway Connectivity")
    
    if not API_URL:
        print("❌ Error: API_BASE_URL not found in .env")
        return

    print(f"Testing URL: {API_URL}/currentPrice")
    
    try:
        response = requests.get(f"{API_URL}/currentPrice")
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ API Success! Response:")
            try:
                print(json.dumps(response.json(), indent=2))
            except:
                print(response.text)
        else:
            print(f"❌ API Failed: {response.text}")

    except Exception as e:
        print(f"❌ Request Error: {e}")

def test_lambda_invocation():
    print_status("TEST 2: Direct Lambda Invocation (Price Listener)")
    print(f"Region: {REGION}")
    print("Invoking 'bitcoin-watcher-price-listener' to check Binance connectivity...")

    client = boto3.client('lambda', region_name=REGION)
    
    try:
        response = client.invoke(
            FunctionName='bitcoin-watcher-price-listener',
            InvocationType='RequestResponse'  # Wait for response
        )
        
        payload = json.loads(response['Payload'].read())
        status_code = payload.get('statusCode')
        body = payload.get('body')
        
        # Parse body if it's a string
        if isinstance(body, str):
            try:
                body = json.loads(body)
            except:
                pass

        print(f"Lambda Status Code: {response['StatusCode']}")
        print(f"Function Result Code: {status_code}")
        
        if status_code == 200:
            print("✅ Lambda Success! The function ran without errors.")
            print("Function Output:")
            print(json.dumps(body, indent=2))
            print("\nNOTE: Because this succeeded, it means:")
            print("  1. The Lambda in Tokyo can start.")
            print("  2. It could connect to MongoDB (AWS SSM/Secrets).")
            print("  3. It successfully fetched a price from Binance (No 451 Error!).")
        else:
            print("❌ Lambda execution reported an error.")
            print(json.dumps(body, indent=2))

    except Exception as e:
        print(f"❌ Invocation Failed: {e}")

if __name__ == "__main__":
    test_api_gateway()
    test_lambda_invocation()
