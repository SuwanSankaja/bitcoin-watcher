#!/bin/bash
set -e
export AWS_PAGER=""

# Configuration
REGION="ap-northeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
API_NAME="bitcoin-watcher-api"

print_status() {
    echo "================================================================="
    echo " $1"
    echo "================================================================="
}

check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it (brew install jq)"
        exit 1
    fi
}

setup_eventbridge() {
    print_status "Setting up EventBridge Rules..."

    # 1. Price Listener (Every 1 minute)
    echo "Configuring Price Listener trigger..."
    aws events put-rule \
        --name bitcoin-watcher-price-trigger \
        --schedule-expression "rate(1 minute)" \
        --state ENABLED \
        --region $REGION

    # Add permission for EventBridge to invoke Lambda
    aws lambda add-permission \
        --function-name bitcoin-watcher-price-listener \
        --statement-id EventBridgeInvoke-Price \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn "arn:aws:events:$REGION:$ACCOUNT_ID:rule/bitcoin-watcher-price-trigger" \
        --region $REGION || echo "Permission already exists"

    # Add target
    aws events put-targets \
        --rule bitcoin-watcher-price-trigger \
        --targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:bitcoin-watcher-price-listener" \
        --region $REGION

    # 2. Signal Analyzer (Every 2 minutes)
    echo "Configuring Signal Analyzer trigger..."
    aws events put-rule \
        --name bitcoin-watcher-signal-trigger \
        --schedule-expression "rate(2 minutes)" \
        --state ENABLED \
        --region $REGION

    # Add permission
    aws lambda add-permission \
        --function-name bitcoin-watcher-signal-analyzer \
        --statement-id EventBridgeInvoke-Signal \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn "arn:aws:events:$REGION:$ACCOUNT_ID:rule/bitcoin-watcher-signal-trigger" \
        --region $REGION || echo "Permission already exists"

    # Add target
    aws events put-targets \
        --rule bitcoin-watcher-signal-trigger \
        --targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:bitcoin-watcher-signal-analyzer" \
        --region $REGION
}

setup_api_gateway() {
    print_status "Setting up API Gateway..."

    # Check if API exists
    EXISTING_API=$(aws apigateway get-rest-apis --region $REGION --query "items[?name=='$API_NAME'].id" --output text)
    
    if [ ! -z "$EXISTING_API" ] && [ "$EXISTING_API" != "None" ]; then
        API_ID=$EXISTING_API
        echo "Found existing API with I: $API_ID"
    else
        echo "Creating new REST API..."
        API_ID=$(aws apigateway create-rest-api --name "$API_NAME" --region $REGION --query 'id' --output text)
        echo "Created API with ID: $API_ID"
    fi

    # Get Root Resource ID
    ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query "items[?path=='/'].id" --output text)

    # --- Setup /currentPrice endpoint ---
    echo "Setting up /currentPrice..."
    
    # Check if resource exists
    RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query "items[?path=='/currentPrice'].id" --output text)
    
    if [ -z "$RESOURCE_ID" ] || [ "$RESOURCE_ID" == "None" ]; then
        RESOURCE_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part currentPrice --region $REGION --query 'id' --output text)
    fi

    # Setup GET method
    aws apigateway put-method \
        --rest-api-id $API_ID \
        --resource-id $RESOURCE_ID \
        --http-method GET \
        --authorization-type NONE \
        --region $REGION || true

    # Setup Integration with Lambda
    LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:bitcoin-watcher-api-handler"
    aws apigateway put-integration \
        --rest-api-id $API_ID \
        --resource-id $RESOURCE_ID \
        --http-method GET \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
        --region $REGION

    # Add Permission for API Gateway to invoke Lambda
    aws lambda add-permission \
        --function-name bitcoin-watcher-api-handler \
        --statement-id "APIGatewayInvoke" \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/GET/currentPrice" \
        --region $REGION || echo "Permission already exists"

    # --- Deploy API ---
    echo "Deploying API..."
    aws apigateway create-deployment \
        --rest-api-id $API_ID \
        --stage-name prod \
        --region $REGION

    API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
    print_status "API Setup Complete!"
    echo "Base URL: $API_URL"
    
    # Verify .env update
    if [ -f ".env" ]; then
        echo ""
        echo "Updating .env file..."
        # Use sed to replace the line, handling both Linux and Mac syntax
        sed -i.bak "s|API_BASE_URL=.*|API_BASE_URL=$API_URL|" .env
        rm .env.bak
        echo "Updated .env with new API URL"
    fi
}

# Main
check_dependencies
if [ ! -z "$1" ]; then
    REGION=$1
fi

echo "Setting up infrastructure in Region: $REGION"
setup_eventbridge
setup_api_gateway

print_status "Infrastructure Setup Complete! 🚀"
echo "Your backend is now fully operational in $REGION."
