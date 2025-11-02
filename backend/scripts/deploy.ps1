# PowerShell Deployment Script for Bitcoin Watcher Lambda Functions
# Windows alternative to deploy.sh

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Bitcoin Watcher - Lambda Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Configuration
$AWS_REGION = "us-east-1"
$LAMBDA_ROLE_NAME = "bitcoin-watcher-lambda-role"
$PACKAGE_DIR = ".\packages"

# Function names
$PRICE_LISTENER_FUNCTION = "bitcoin-watcher-price-listener"
$SIGNAL_ANALYZER_FUNCTION = "bitcoin-watcher-signal-analyzer"
$API_HANDLER_FUNCTION = "bitcoin-watcher-api-handler"

# Create package directory
New-Item -ItemType Directory -Force -Path $PACKAGE_DIR | Out-Null

Write-Host ""
Write-Host "Step 1: Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -t $PACKAGE_DIR

Write-Host ""
Write-Host "Step 2: Creating deployment packages..." -ForegroundColor Yellow

# Package Price Listener
Write-Host "Packaging Price Listener..."
Set-Location $PACKAGE_DIR
Copy-Item ..\lambda\price_listener.py .
Compress-Archive -Path * -DestinationPath ..\price_listener.zip -Force
Remove-Item price_listener.py
Set-Location ..

# Package Signal Analyzer
Write-Host "Packaging Signal Analyzer..."
Set-Location $PACKAGE_DIR
Copy-Item ..\lambda\signal_analyzer.py .
Compress-Archive -Path * -DestinationPath ..\signal_analyzer.zip -Force
Remove-Item signal_analyzer.py
Set-Location ..

# Package API Handler
Write-Host "Packaging API Handler..."
Set-Location $PACKAGE_DIR
Copy-Item ..\lambda\api_handler.py .
Compress-Archive -Path * -DestinationPath ..\api_handler.zip -Force
Remove-Item api_handler.py
Set-Location ..

Write-Host ""
Write-Host "Step 3: Creating/Updating Lambda functions..." -ForegroundColor Yellow

# Function to create or update Lambda
function Deploy-Lambda {
    param(
        [string]$FunctionName,
        [string]$ZipFile,
        [string]$Handler,
        [string]$Description
    )
    
    # Check if function exists
    $functionExists = $true
    try {
        aws lambda get-function --function-name $FunctionName --region $AWS_REGION 2>$null
    } catch {
        $functionExists = $false
    }
    
    if ($functionExists) {
        Write-Host "Updating $FunctionName..."
        aws lambda update-function-code `
            --function-name $FunctionName `
            --zip-file fileb://$ZipFile `
            --region $AWS_REGION
    } else {
        Write-Host "Creating $FunctionName..."
        
        # Get Lambda role ARN
        $RoleArn = aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text
        
        aws lambda create-function `
            --function-name $FunctionName `
            --runtime python3.11 `
            --role $RoleArn `
            --handler $Handler `
            --zip-file fileb://$ZipFile `
            --timeout 30 `
            --memory-size 256 `
            --region $AWS_REGION `
            --description $Description
    }
}

# Deploy all functions
Deploy-Lambda -FunctionName $PRICE_LISTENER_FUNCTION -ZipFile "price_listener.zip" -Handler "price_listener.lambda_handler" -Description "Fetches BTC price from Binance and stores in MongoDB"
Deploy-Lambda -FunctionName $SIGNAL_ANALYZER_FUNCTION -ZipFile "signal_analyzer.zip" -Handler "signal_analyzer.lambda_handler" -Description "Analyzes prices and generates buy/sell signals"
Deploy-Lambda -FunctionName $API_HANDLER_FUNCTION -ZipFile "api_handler.zip" -Handler "api_handler.lambda_handler" -Description "API Gateway handler for Flutter app"

Write-Host ""
Write-Host "Step 4: Setting up EventBridge triggers..." -ForegroundColor Yellow

$AccountId = aws sts get-caller-identity --query Account --output text

# Create EventBridge rule for Price Listener
aws events put-rule `
    --name bitcoin-watcher-price-trigger `
    --schedule-expression "rate(1 minute)" `
    --state ENABLED `
    --region $AWS_REGION `
    --description "Triggers price listener every minute"

# Add permission for EventBridge to invoke Price Listener
try {
    aws lambda add-permission `
        --function-name $PRICE_LISTENER_FUNCTION `
        --statement-id EventBridgeInvoke `
        --action lambda:InvokeFunction `
        --principal events.amazonaws.com `
        --source-arn "arn:aws:events:${AWS_REGION}:${AccountId}:rule/bitcoin-watcher-price-trigger" `
        --region $AWS_REGION 2>$null
} catch {
    Write-Host "Permission already exists"
}

# Add target to EventBridge rule
aws events put-targets `
    --rule bitcoin-watcher-price-trigger `
    --targets "Id=1,Arn=arn:aws:lambda:${AWS_REGION}:${AccountId}:function:${PRICE_LISTENER_FUNCTION}" `
    --region $AWS_REGION

# Create EventBridge rule for Signal Analyzer
aws events put-rule `
    --name bitcoin-watcher-signal-trigger `
    --schedule-expression "rate(2 minutes)" `
    --state ENABLED `
    --region $AWS_REGION `
    --description "Triggers signal analyzer every 2 minutes"

# Add permission
try {
    aws lambda add-permission `
        --function-name $SIGNAL_ANALYZER_FUNCTION `
        --statement-id EventBridgeInvoke `
        --action lambda:InvokeFunction `
        --principal events.amazonaws.com `
        --source-arn "arn:aws:events:${AWS_REGION}:${AccountId}:rule/bitcoin-watcher-signal-trigger" `
        --region $AWS_REGION 2>$null
} catch {
    Write-Host "Permission already exists"
}

# Add target
aws events put-targets `
    --rule bitcoin-watcher-signal-trigger `
    --targets "Id=1,Arn=arn:aws:lambda:${AWS_REGION}:${AccountId}:function:${SIGNAL_ANALYZER_FUNCTION}" `
    --region $AWS_REGION

Write-Host ""
Write-Host "Step 5: Cleaning up..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $PACKAGE_DIR
Remove-Item price_listener.zip, signal_analyzer.zip, api_handler.zip

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Lambda Functions:" -ForegroundColor Cyan
Write-Host "  - $PRICE_LISTENER_FUNCTION"
Write-Host "  - $SIGNAL_ANALYZER_FUNCTION"
Write-Host "  - $API_HANDLER_FUNCTION"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Set up API Gateway for the API Handler function"
Write-Host "  2. Update Flutter app with API Gateway URL"
Write-Host "  3. Configure Firebase credentials in Secrets Manager"
Write-Host "  4. Test the functions using AWS Console"
