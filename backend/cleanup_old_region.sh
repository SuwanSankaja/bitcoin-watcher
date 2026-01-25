#!/bin/bash
set -e
export AWS_PAGER=""

# Default to us-east-1 if not specified, as that's the likely old region
REGION="us-east-1"

if [ ! -z "$1" ]; then
    REGION=$1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
API_NAME="bitcoin-watcher-api"

print_status() {
    echo "================================================================="
    echo " $1"
    echo "================================================================="
}

print_warning() {
    echo "⚠️  $1"
}

check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it (brew install jq)"
        exit 1
    fi
}

cleanup_lambdas() {
    print_status "Deleting Lambda Functions in $REGION..."
    
    FUNCTIONS=(
        "bitcoin-watcher-price-listener"
        "bitcoin-watcher-signal-analyzer"
        "bitcoin-watcher-api-handler"
    )

    for func in "${FUNCTIONS[@]}"; do
        if aws lambda get-function --function-name "$func" --region $REGION &> /dev/null; then
            aws lambda delete-function --function-name "$func" --region $REGION
            echo "Deleted $func"
        else
            echo "$func not found"
        fi
    done
}

cleanup_eventbridge() {
    print_status "Deleting EventBridge Rules in $REGION..."

    RULES=(
        "bitcoin-watcher-price-trigger"
        "bitcoin-watcher-signal-trigger"
    )

    for rule in "${RULES[@]}"; do
        if aws events describe-rule --name "$rule" --region $REGION &> /dev/null; then
            # Remove targets first
            TARGETS=$(aws events list-targets-by-rule --rule "$rule" --region $REGION --query 'Targets[].Id' --output text)
            if [ ! -z "$TARGETS" ]; then
                aws events remove-targets --rule "$rule" --ids $TARGETS --region $REGION
                echo "Removed targets from $rule"
            fi
            
            # Delete rule
            aws events delete-rule --name "$rule" --region $REGION
            echo "Deleted rule $rule"
        else
            echo "Rule $rule not found"
        fi
    done
}

cleanup_api_gateway() {
    print_status "Deleting API Gateway in $REGION..."

    # Find API by name
    API_IDS=$(aws apigateway get-rest-apis --region $REGION --query "items[?name=='$API_NAME'].id" --output text)

    for api_id in $API_IDS; do
        if [ ! -z "$api_id" ] && [ "$api_id" != "None" ]; then
            aws apigateway delete-rest-api --rest-api-id "$api_id" --region $REGION
            echo "Deleted API Gateway: $api_id"
        fi
    done
    
    if [ -z "$API_IDS" ] || [ "$API_IDS" == "None" ]; then
        echo "No API Gateway found with name $API_NAME"
    fi
}

cleanup_secrets_ssm() {
    print_status "Deleting Secrets and Parameters in $REGION..."

    # Delete Secret
    if aws secretsmanager describe-secret --secret-id bitcoin-watcher-binance-testnet --region $REGION &> /dev/null; then
        # Force delete without recovery window for immediate cleanup
        aws secretsmanager delete-secret --secret-id bitcoin-watcher-binance-testnet --force-delete-without-recovery --region $REGION
        echo "Deleted secret bitcoin-watcher-binance-testnet"
    else
        echo "Secret bitcoin-watcher-binance-testnet not found"
    fi

    # Delete SSM Parameter
    if aws ssm get-parameter --name "/bitcoin-watcher/mongodb-uri" --region $REGION &> /dev/null; then
        aws ssm delete-parameter --name "/bitcoin-watcher/mongodb-uri" --region $REGION
        echo "Deleted parameter /bitcoin-watcher/mongodb-uri"
    else
        echo "Parameter /bitcoin-watcher/mongodb-uri not found"
    fi
}

# Main Execution
check_dependencies

echo "!!! WARNING !!!"
echo "This script will PERMANENTLY DELETE resources in region: $REGION"
echo "Resources to be deleted:"
echo " - Lambda Functions"
echo " - API Gateway"
echo " - EventBridge Rules"
echo " - Secrets Manager Secrets"
echo " - SSM Parameters"
echo ""
echo "IAM Roles will NOT be deleted as they are global."
echo ""
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

cleanup_lambdas
cleanup_eventbridge
cleanup_api_gateway
cleanup_secrets_ssm

print_status "Cleanup Complete!"
print_status "NOTE: IAM Roles were preserved as they are global and used by your new deployment."
