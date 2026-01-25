# AWS Backend Setup for Bitcoin Watcher

## 🚀 Automated Deployment (Recommended)

To fix "451 Unavailable For Legal Reasons" errors or deploy to a new region, use the automated script:

```bash
# Deploy to Tokyo (ap-northeast-1) - Recommended for Binance
./backend/deploy_backend.sh ap-northeast-1

# Deploy to Singapore (ap-southeast-1)
./backend/deploy_backend.sh ap-southeast-1

# Deploy to Mumbai (ap-south-1) - WARNING: May be blocked by Binance
./backend/deploy_backend.sh ap-south-1
```

The script will:
1. Create/Update IAM Roles
2. Deploy Lambda functions
3. Setup Secrets (it will prompt you if they don't exist)

**Post-Script Steps:**
1. Go to AWS Console -> API Gateway -> Create API (if not exists)
2. Go to AWS Console -> EventBridge -> Create Rules (if not exists)
3. Update your `.env` file with the new API Gateway URL.

---

## Manual Setup (Legacy)

### Lambda Execution Role Policy

Create a custom policy with these permissions:

```json
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
```

## Setup Commands

### Create IAM Role
```bash
# Create trust policy
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

# Create role
aws iam create-role \
  --role-name bitcoin-watcher-lambda-role \
  --assume-role-policy-document file://lambda-trust-policy.json
```

### Create Custom Policy
```bash
# Create policy document
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

# Create policy
aws iam create-policy \
  --policy-name bitcoin-watcher-lambda-policy \
  --policy-document file://lambda-policy.json

# Attach policy to role (replace ACCOUNT_ID)
aws iam attach-role-policy \
  --role-name bitcoin-watcher-lambda-role \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/bitcoin-watcher-lambda-policy
```

### Attach AWS Managed Policies
```bash
# Basic Lambda execution
aws iam attach-role-policy \
  --role-name bitcoin-watcher-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

## API Gateway Setup

### Create REST API
1. Go to AWS Console → API Gateway
2. Create API → REST API → Build
3. API Name: `bitcoin-watcher-api`
4. Endpoint Type: Regional
5. Create API

### Create Resources and Methods

For each endpoint:

#### /currentPrice
```bash
aws apigateway create-resource \
  --rest-api-id YOUR_API_ID \
  --parent-id YOUR_ROOT_RESOURCE_ID \
  --path-part currentPrice

aws apigateway put-method \
  --rest-api-id YOUR_API_ID \
  --resource-id RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE

aws apigateway put-integration \
  --rest-api-id YOUR_API_ID \
  --resource-id RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:REGION:ACCOUNT_ID:function:bitcoin-watcher-api-handler/invocations
```

#### Enable CORS
```bash
aws apigateway put-method \
  --rest-api-id YOUR_API_ID \
  --resource-id RESOURCE_ID \
  --http-method OPTIONS \
  --authorization-type NONE

aws apigateway put-method-response \
  --rest-api-id YOUR_API_ID \
  --resource-id RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters "method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true,method.response.header.Access-Control-Allow-Origin=true"
```

### Deploy API
```bash
aws apigateway create-deployment \
  --rest-api-id YOUR_API_ID \
  --stage-name prod
```

## EventBridge Rules

### Price Listener (Every 1 minute)
```bash
aws events put-rule \
  --name bitcoin-watcher-price-trigger \
  --schedule-expression "rate(1 minute)" \
  --state ENABLED

aws lambda add-permission \
  --function-name bitcoin-watcher-price-listener \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:REGION:ACCOUNT_ID:rule/bitcoin-watcher-price-trigger

aws events put-targets \
  --rule bitcoin-watcher-price-trigger \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT_ID:function:bitcoin-watcher-price-listener"
```

### Signal Analyzer (Every 2 minutes)
```bash
aws events put-rule \
  --name bitcoin-watcher-signal-trigger \
  --schedule-expression "rate(2 minutes)" \
  --state ENABLED

aws lambda add-permission \
  --function-name bitcoin-watcher-signal-analyzer \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:REGION:ACCOUNT_ID:rule/bitcoin-watcher-signal-trigger

aws events put-targets \
  --rule bitcoin-watcher-signal-trigger \
  --targets "Id"="1","Arn"="arn:aws:lambda:REGION:ACCOUNT_ID:function:bitcoin-watcher-signal-analyzer"
```

## Clean Up Resources

To delete all resources:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name bitcoin-watcher-price-listener
aws lambda delete-function --function-name bitcoin-watcher-signal-analyzer
aws lambda delete-function --function-name bitcoin-watcher-api-handler

# Delete EventBridge rules
aws events remove-targets --rule bitcoin-watcher-price-trigger --ids "1"
aws events delete-rule --name bitcoin-watcher-price-trigger
aws events remove-targets --rule bitcoin-watcher-signal-trigger --ids "1"
aws events delete-rule --name bitcoin-watcher-signal-trigger

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id YOUR_API_ID

# Delete IAM role and policies
aws iam detach-role-policy --role-name bitcoin-watcher-lambda-role --policy-arn POLICY_ARN
aws iam delete-role --role-name bitcoin-watcher-lambda-role

# Delete parameters
aws ssm delete-parameter --name "/bitcoin-watcher/mongodb-uri"
aws secretsmanager delete-secret --secret-id bitcoin-watcher-firebase-creds
```
