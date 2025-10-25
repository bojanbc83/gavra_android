# Gavra Firestore MCP Server Setup Script
# Run this script in PowerShell from the mcp_server directory

Write-Host "🔥 Setting up Gavra Firestore MCP Server..." -ForegroundColor Green

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Build the project
Write-Host "🔨 Building TypeScript..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build project" -ForegroundColor Red
    exit 1
}

# Check if service account key exists
if (Test-Path "src/serviceAccountKey.json") {
    Write-Host "✅ Service account key found" -ForegroundColor Green
} else {
    Write-Host "⚠️  Service account key not found!" -ForegroundColor Yellow
    Write-Host "Please follow these steps:" -ForegroundColor Yellow
    Write-Host "1. Go to Firebase Console > Project Settings > Service accounts" -ForegroundColor White
    Write-Host "2. Click 'Generate new private key'" -ForegroundColor White
    Write-Host "3. Save the file as 'src/serviceAccountKey.json'" -ForegroundColor White
    Write-Host "4. Or rename 'serviceAccountKey.template.json' and fill in your values" -ForegroundColor White
}

Write-Host ""
Write-Host "🎉 Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Set up your Firebase service account key (see above)" -ForegroundColor White
Write-Host "2. Run 'npm start' to start the MCP server" -ForegroundColor White
Write-Host "3. Add the server to your MCP client configuration" -ForegroundColor White
Write-Host ""
Write-Host "Example Claude Desktop config:" -ForegroundColor Yellow
Get-Content "claude_desktop_config.json" | Write-Host -ForegroundColor Gray