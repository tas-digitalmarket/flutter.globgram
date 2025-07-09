#!/usr/bin/env pwsh
# PowerShell script to set up Firestore testing rules and run the app

Write-Host "🔧 Setting up Firestore Testing Rules..." -ForegroundColor Yellow

# Check if Firebase CLI is installed
if (-not (Get-Command "firebase" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "npm install -g firebase-tools" -ForegroundColor Cyan
    exit 1
}

# Apply testing rules
Write-Host "📋 Applying permissive testing rules..." -ForegroundColor Blue
Copy-Item "firestore-testing.rules" "firestore.rules" -Force

# Deploy rules
Write-Host "🚀 Deploying rules to Firebase..." -ForegroundColor Blue
firebase deploy --only firestore:rules

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Rules deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  WARNING: These rules allow unrestricted access!" -ForegroundColor Yellow
    Write-Host "   Use ONLY for development and testing." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🌐 Starting Flutter web app..." -ForegroundColor Blue
    flutter run -d web-server --web-port 8080
} else {
    Write-Host "❌ Failed to deploy rules. Check your Firebase setup." -ForegroundColor Red
    exit 1
}
