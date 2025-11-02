#!/bin/bash

# AWS Lambda Deployment Script for Bitcoin Watcher
# This script packages and deploys all three Lambda functions

set -e

echo "========================================="
echo "Bitcoin Watcher - Lambda Deployment"
echo "========================================="

# Configuration
AWS_REGION="us-east-1"
LAMBDA_ROLE_NAME="bitcoin-watcher-lambda-role"
PACKAGE_DIR="./packages"

# Function names
PRICE_LISTENER_FUNCTION="bitcoin-watcher-price-listener"
SIGNAL_ANALYZER_FUNCTION="bitcoin-watcher-signal-analyzer"
API_HANDLER_FUNCTION="bitcoin-watcher-api-handler"

# Create package directory
mkdir -p $PACKAGE_DIR

echo ""
echo "Step 1: Installing Python dependencies..."
pip install -r requirements.txt -t $PACKAGE_DIR/

echo ""
echo "Step 2: Creating deployment packages..."

# Package Price Listener
echo "Packaging Price Listener..."
cd $PACKAGE_DIR
cp ../lambda/price_listener.py .
zip -r ../price_listener.zip . > /dev/null
rm price_listener.py
cd ..

# Package Signal Analyzer
echo "Packaging Signal Analyzer..."
cd $PACKAGE_DIR
cp ../lambda/signal_analyzer.py .
zip -r ../signal_analyzer.zip . > /dev/null
rm signal_analyzer.py
cd ..

# Package API Handler
echo "Packaging API Handler..."
cd $PACKAGE_DIR
cp ../lambda/api_handler.py .
zip -r ../api_handler.zip . > /dev/null
rm api_handler.py
cd ..

echo ""
echo "Step 3: Creating/Updating Lambda functions..."

# Function to create or update Lambda
deploy_lambda() {
    local FUNCTION_NAME=$1
    local ZIP_FILE=$2
    local HANDLER=$3
    local DESCRIPTION=$4
    
    # Check if function exists
    if aws lambda get-function --function-name $FUNCTION_NAME --region $AWS_REGION 2>/dev/null; then
        echo "Updating $FUNCTION_NAME..."
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb://$ZIP_FILE \
            --region $AWS_REGION
    else
        echo "Creating $FUNCTION_NAME..."
        
        # Get Lambda role ARN
        ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text)
        
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime python3.11 \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --zip-file fileb://$ZIP_FILE \
            --timeout 30 \
            --memory-size 256 \
            --region $AWS_REGION \
            --description "$DESCRIPTION"
    fi
}

# Deploy all functions
deploy_lambda $PRICE_LISTENER_FUNCTION "price_listener.zip" "price_listener.lambda_handler" "Fetches BTC price from Binance and stores in MongoDB"
deploy_lambda $SIGNAL_ANALYZER_FUNCTION "signal_analyzer.zip" "signal_analyzer.lambda_handler" "Analyzes prices and generates buy/sell signals"
deploy_lambda $API_HANDLER_FUNCTION "api_handler.zip" "api_handler.lambda_handler" "API Gateway handler for Flutter app"

echo ""
echo "Step 4: Setting up EventBridge triggers..."

# Create EventBridge rule for Price Listener (every 1 minute)
aws events put-rule \
    --name bitcoin-watcher-price-trigger \
    --schedule-expression "rate(1 minute)" \
    --state ENABLED \
    --region $AWS_REGION \
    --description "Triggers price listener every minute"

# Add permission for EventBridge to invoke Price Listener
aws lambda add-permission \
    --function-name $PRICE_LISTENER_FUNCTION \
    --statement-id EventBridgeInvoke \
    --action lambda:InvokeFunction \
    --principal events.amazonaws.com \
    --source-arn arn:aws:events:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):rule/bitcoin-watcher-price-trigger \
    --region $AWS_REGION 2>/dev/null || echo "Permission already exists"

# Add target to EventBridge rule
aws events put-targets \
    --rule bitcoin-watcher-price-trigger \
    --targets "Id"="1","Arn"="arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):function:$PRICE_LISTENER_FUNCTION" \
    --region $AWS_REGION

# Create EventBridge rule for Signal Analyzer (every 2 minutes)
aws events put-rule \
    --name bitcoin-watcher-signal-trigger \
    --schedule-expression "rate(2 minutes)" \
    --state ENABLED \
    --region $AWS_REGION \
    --description "Triggers signal analyzer every 2 minutes"

# Add permission for EventBridge to invoke Signal Analyzer
aws lambda add-permission \
    --function-name $SIGNAL_ANALYZER_FUNCTION \
    --statement-id EventBridgeInvoke \
    --action lambda:InvokeFunction \
    --principal events.amazonaws.com \
    --source-arn arn:aws:events:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):rule/bitcoin-watcher-signal-trigger \
    --region $AWS_REGION 2>/dev/null || echo "Permission already exists"

# Add target to EventBridge rule
aws events put-targets \
    --rule bitcoin-watcher-signal-trigger \
    --targets "Id"="1","Arn"="arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):function:$SIGNAL_ANALYZER_FUNCTION" \
    --region $AWS_REGION

echo ""
echo "Step 5: Cleaning up..."
rm -rf $PACKAGE_DIR
rm price_listener.zip signal_analyzer.zip api_handler.zip

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Lambda Functions:"
echo "  - $PRICE_LISTENER_FUNCTION"
echo "  - $SIGNAL_ANALYZER_FUNCTION"
echo "  - $API_HANDLER_FUNCTION"
echo ""
echo "Next steps:"
echo "  1. Set up API Gateway for the API Handler function"
echo "  2. Update Flutter app with API Gateway URL"
echo "  3. Configure Firebase credentials in Secrets Manager"
echo "  4. Test the functions using AWS Console"
echo ""
