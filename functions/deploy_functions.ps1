# Helper script to deploy Firebase Functions with Secret management
# Run this from the project root

Write-Host "Preparing to deploy TopScore AI Functions..." -ForegroundColor Cyan

# 1. Check if firebase CLI is installed
if (!(Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Error "Firebase CLI not found. Please install it with 'npm install -g firebase-tools'"
    exit 1
}

# 2. Set up secrets if not already set
Write-Host "Checking for SMTP_PASSWORD secret..." -ForegroundColor Yellow
$secrets = firebase functions:secrets:get SMTP_PASSWORD 2>$null
if (!$secrets) {
    Write-Host "SMTP_PASSWORD secret not found. You must set it to enable emails." -ForegroundColor Red
    Write-Host "Please enter the SMTP password for admin@topscoreapp.ai:"
    $pass = Read-Host -MaskInput
    if ($pass) {
        Write-Host "Setting secret..."
        Write-Output $pass | firebase functions:secrets:set SMTP_PASSWORD
    } else {
        Write-Host "Skipping secret setup. Emails will be disabled in production." -ForegroundColor Gray
    }
} else {
    Write-Host "SMTP_PASSWORD secret is already configured." -ForegroundColor Green
}

# 3. Deploy
Write-Host "Deploying functions to elimisha-90787..." -ForegroundColor Cyan
firebase deploy --only functions

Write-Host "Done!" -ForegroundColor Green
