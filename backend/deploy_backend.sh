#!/bin/bash
set -e
export AWS_PAGER=""

# Configuration
REGION="ap-northeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="bitcoin-watcher-lambda-role"
POLICY_NAME="bitcoin-watcher-lambda-policy"
API_NAME="bitcoin-watcher-api"

# Functions
print_status() {
    echo "================================================================="
    echo " $1"
    echo "================================================================="
}

check_dependencies() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed."
        exit 1
    fi
    if ! command -v zip &> /dev/null; then
        echo "Error: zip command is not installed."
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it (brew install jq)"
        exit 1
    fi
}

setup_iam() {
    print_status "Setting up IAM Roles and Policies..."

    # Create Trust Policy
    cat > lambda-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Create Role (idempotent)
    if ! aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
        aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://lambda-trust-policy.json
    else
        echo "Role $ROLE_NAME already exists."
    fi

    # Create Permission Policy
    cat > lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/bitcoin-watcher/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:bitcoin-watcher-*"
    }
  ]
}
EOF

    # Put Role Policy (inline is easier for cleanup/updates)
    aws iam put-role-policy \
        --role-name $ROLE_NAME \
        --policy-name $POLICY_NAME \
        --policy-document file://lambda-policy.json
    
    rm lambda-trust-policy.json lambda-policy.json
    
    # Wait for role propagation
    echo "Waiting for role propagation..."
    sleep 10
}

setup_secrets() {
    print_status "Checking Secrets in $REGION..."

    # Read from .env file
    if [ -f ".env" ]; then
        echo "Reading secrets from .env file..."
        export $(grep -v '^#' .env | xargs)
    else
        echo "Warning: .env file not found. Falling back to interactive mode."
    fi

    # Check for testnet secret
    if ! aws secretsmanager list-secrets --region $REGION --query "SecretList[?Name=='bitcoin-watcher-binance-testnet']" | grep "bitcoin-watcher-binance-testnet" > /dev/null; then
        echo "Creating bitcoin-watcher-binance-testnet secret..."
        
        if [ -z "$BINANCE_TESTNET_API_KEY" ] || [ -z "$BINANCE_TESTNET_API_SECRET" ]; then
             echo "Missing keys in .env, asking interactively..."
             read -p "Enter Binance Testnet API Key: " BINANCE_TESTNET_API_KEY
             read -p "Enter Binance Testnet API Secret: " BINANCE_TESTNET_API_SECRET
        fi
        
        aws secretsmanager create-secret \
            --region $REGION \
            --name bitcoin-watcher-binance-testnet \
            --secret-string "{\"api_key\":\"$BINANCE_TESTNET_API_KEY\",\"api_secret\":\"$BINANCE_TESTNET_API_SECRET\"}"
    else
        echo "Secret bitcoin-watcher-binance-testnet exists."
        # Update it anyway to ensure it matches .env
        echo "Updating secret with latest .env values..."
        if [ ! -z "$BINANCE_TESTNET_API_KEY" ] && [ ! -z "$BINANCE_TESTNET_API_SECRET" ]; then
             aws secretsmanager put-secret-value \
                --region $REGION \
                --secret-id bitcoin-watcher-binance-testnet \
                --secret-string "{\"api_key\":\"$BINANCE_TESTNET_API_KEY\",\"api_secret\":\"$BINANCE_TESTNET_API_SECRET\"}" > /dev/null
        fi
    fi

    # Check for MongoDB URI in SSM
    if ! aws ssm get-parameter --region $REGION --name "/bitcoin-watcher/mongodb-uri" &> /dev/null; then
        echo "Creating MongoDB URI parameter..."
        
        if [ -z "$MONGODB_URI" ]; then
             read -p "Enter MongoDB Connection URI: " MONGODB_URI
        fi
        
        aws ssm put-parameter \
            --region $REGION \
            --name "/bitcoin-watcher/mongodb-uri" \
            --value "$MONGODB_URI" \
            --type "SecureString"
    else
        echo "Parameter /bitcoin-watcher/mongodb-uri exists."
         # Update it anyway to ensure it matches .env
        if [ ! -z "$MONGODB_URI" ]; then
             echo "Updating MongoDB URI with latest .env value..."
             aws ssm put-parameter \
                --region $REGION \
                --name "/bitcoin-watcher/mongodb-uri" \
                --value "$MONGODB_URI" \
                --type "SecureString" \
                --overwrite > /dev/null
        fi
    fi
}

deploy_lambdas() {
    print_status "Deploying Lambda Functions to $REGION..."

    # Get script directory to ensure correct paths
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Prepare zip file
    echo "Zipping lambda package..."
    cd "$SCRIPT_DIR/lambda"
    
    # Create package directory
    mkdir -p package
    # Install dependencies
    pip3 install --target ./package -r ../requirements.txt
    
    # Remove boto3 and botocore (included in Lambda runtime) to reduce size
    rm -rf package/boto3* package/botocore* package/s3transfer*
    
    # Copy source code
    cp *.py ./package/
    cd package
    zip -r ../backend.zip . -x "*__pycache__*"
    cd ..
    rm -rf package
    cd ..

    # --- S3 Upload Strategy for Large Packages ---
    BUCKET_NAME="bitcoin-watcher-deploy-${ACCOUNT_ID}-${REGION}"
    
    print_status "Creating temporary S3 bucket: $BUCKET_NAME"
    # Create bucket (if not exists)
    if ! aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
        if [ "$REGION" == "us-east-1" ]; then
            aws s3 mb "s3://$BUCKET_NAME"
        else
            aws s3 mb "s3://$BUCKET_NAME" --region $REGION
        fi
    fi

    print_status "Uploading code to S3..."
    aws s3 cp lambda/backend.zip "s3://$BUCKET_NAME/backend.zip"

    ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"

    # Deploy Price Listener
    if aws lambda get-function --function-name bitcoin-watcher-price-listener --region $REGION &> /dev/null; then
        echo "Updating bitcoin-watcher-price-listener code..."
        aws lambda update-function-code \
            --region $REGION \
            --function-name bitcoin-watcher-price-listener \
            --s3-bucket $BUCKET_NAME \
            --s3-key backend.zip > /dev/null
            
        echo "Updating runtime config..."
        echo "Waiting for update to complete..."
        sleep 10
        aws lambda update-function-configuration \
            --region $REGION \
            --function-name bitcoin-watcher-price-listener \
            --runtime python3.11 > /dev/null
    else
        echo "Creating bitcoin-watcher-price-listener..."
        aws lambda create-function \
            --region $REGION \
            --function-name bitcoin-watcher-price-listener \
            --runtime python3.11 \
            --handler price_listener.lambda_handler \
            --role $ROLE_ARN \
            --code S3Bucket=$BUCKET_NAME,S3Key=backend.zip \
            --timeout 60
    fi

    # Deploy Signal Analyzer
    if aws lambda get-function --function-name bitcoin-watcher-signal-analyzer --region $REGION &> /dev/null; then
        echo "Updating bitcoin-watcher-signal-analyzer code..."
        aws lambda update-function-code \
            --region $REGION \
            --function-name bitcoin-watcher-signal-analyzer \
            --s3-bucket $BUCKET_NAME \
            --s3-key backend.zip > /dev/null

        echo "Updating runtime config..."
        echo "Waiting for update to complete..."
        sleep 10
        aws lambda update-function-configuration \
            --region $REGION \
            --function-name bitcoin-watcher-signal-analyzer \
            --runtime python3.11 > /dev/null
    else
        echo "Creating bitcoin-watcher-signal-analyzer..."
        aws lambda create-function \
            --region $REGION \
            --function-name bitcoin-watcher-signal-analyzer \
            --runtime python3.11 \
            --handler signal_analyzer.lambda_handler \
            --role $ROLE_ARN \
            --code S3Bucket=$BUCKET_NAME,S3Key=backend.zip \
            --timeout 60
    fi

    # Deploy API Handler
    if aws lambda get-function --function-name bitcoin-watcher-api-handler --region $REGION &> /dev/null; then
        echo "Updating bitcoin-watcher-api-handler code..."
        aws lambda update-function-code \
            --region $REGION \
            --function-name bitcoin-watcher-api-handler \
            --s3-bucket $BUCKET_NAME \
            --s3-key backend.zip > /dev/null

        echo "Updating runtime config..."
        echo "Waiting for update to complete..."
        sleep 20
        aws lambda update-function-configuration \
            --region $REGION \
            --function-name bitcoin-watcher-api-handler \
            --runtime python3.11 > /dev/null
    else
        echo "Creating bitcoin-watcher-api-handler..."
        aws lambda create-function \
            --region $REGION \
            --function-name bitcoin-watcher-api-handler \
            --runtime python3.11 \
            --handler api_handler.lambda_handler \
            --role $ROLE_ARN \
            --code S3Bucket=$BUCKET_NAME,S3Key=backend.zip \
            --timeout 30
    fi

    # Cleanup S3
    print_status "Cleaning up S3..."
    aws s3 rb "s3://$BUCKET_NAME" --force
    rm lambda/backend.zip
}

cleanup_old_resources() {
    print_status "NOTE: You may want to manually delete resources in the old region (e.g. us-east-1) to save costs."
    echo "Run: aws lambda delete-function --function-name bitcoin-watcher-price-listener --region us-east-1"
}

# Main Execution
check_dependencies

if [ ! -z "$1" ]; then
    REGION=$1
fi

echo "Deploying to AWS Region: $REGION"
echo "Account ID: $ACCOUNT_ID"

setup_iam
setup_secrets
deploy_lambdas
cleanup_old_resources

print_status "Deployment Complete!"
echo "Note: You still need to configure EventBridge rules and API Gateway manually or extend this script."
echo "Since those are stateful and complex, I recommend doing them in the console for this specific migration task to ensure correctness."
echo "Region: $REGION"
