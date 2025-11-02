# PowerShell script to update EventBridge schedule to run every 1 minute
# Requires AWS CLI to be installed and configured

Write-Host "Updating EventBridge rule to trigger every 1 minute..." -ForegroundColor Yellow

# Update the schedule expression
aws events put-rule `
    --name "bitcoin-watcher-price-trigger" `
    --schedule-expression "rate(1 minute)" `
    --state "ENABLED" `
    --description "Trigger price_listener Lambda every minute"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ SUCCESS! EventBridge rule updated to run every 1 minute" -ForegroundColor Green
    Write-Host ""
    Write-Host "The Lambda will now be triggered every minute." -ForegroundColor Cyan
    Write-Host "Wait 2-3 minutes, then check MongoDB for new price records." -ForegroundColor Cyan
} else {
    Write-Host "❌ ERROR: Failed to update EventBridge rule" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please make sure:" -ForegroundColor Yellow
    Write-Host "  1. AWS CLI is installed (run: aws --version)" -ForegroundColor Yellow
    Write-Host "  2. AWS credentials are configured (run: aws configure)" -ForegroundColor Yellow
    Write-Host "  3. You have permission to update EventBridge rules" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or update manually in AWS Console:" -ForegroundColor Cyan
    Write-Host "  EventBridge → Rules → bitcoin-watcher-price-trigger → Edit" -ForegroundColor Cyan
    Write-Host "  Set schedule to: rate(1 minute)" -ForegroundColor Cyan
}
