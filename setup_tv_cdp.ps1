# setup_tv_cdp.ps1
# TradingView Desktop CDP (Chrome DevTools Protocol) enabler
# Patches app.asar to inject --remote-debugging-port=9222
# Required for TradingView MCP integration with Claude Code
#
# Usage:
#   Run as normal user (NOT admin)
#   Prerequisites: Node.js 18+, Windows Developer Mode ON
#
# After running:
#   Launch TradingView from Start Menu -> CDP is enabled on port 9222
#   Add MCP server: claude mcp add tradingview -s user -- node "<path>\tradingview-mcp\src\server.js"

$ErrorActionPreference = "Stop"

$INSTALL_DIR = "$env:USERPROFILE\TradingView_cdp"
$INJECT_CODE = @'
const { app } = require('electron');
app.commandLine.appendSwitch('remote-debugging-port', '9222');
'@

Write-Host ""
Write-Host "=== TradingView CDP Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Check Developer Mode ---
Write-Host "[1/6] Checking Windows Developer Mode..." -ForegroundColor Yellow
$devMode = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Host "  ERROR: Developer Mode is OFF." -ForegroundColor Red
    Write-Host "  Go to: Settings -> System -> For developers -> Developer Mode -> ON" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

# --- 2. Check Node.js ---
Write-Host "[2/6] Checking Node.js..." -ForegroundColor Yellow
try {
    $nodeVer = (node --version 2>&1).ToString()
    Write-Host "  OK ($nodeVer)" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Node.js not found. Install from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# --- 3. Install @electron/asar ---
Write-Host "[3/6] Installing @electron/asar..." -ForegroundColor Yellow
npm install -g @electron/asar 2>&1 | Out-Null
Write-Host "  OK" -ForegroundColor Green

# --- 4. Find TradingView Store installation ---
Write-Host "[4/6] Finding TradingView installation..." -ForegroundColor Yellow
$pkg = Get-AppxPackage *TradingView* -ErrorAction SilentlyContinue
if (-not $pkg) {
    Write-Host "  ERROR: TradingView not found. Install from Microsoft Store or tradingview.com" -ForegroundColor Red
    exit 1
}
$TV_SRC = $pkg.InstallLocation
Write-Host "  Found: $TV_SRC" -ForegroundColor Green
Write-Host "  Version: $($pkg.Version)" -ForegroundColor Green

# --- 5. Copy, patch, repack ---
Write-Host "[5/6] Patching app.asar..." -ForegroundColor Yellow

# Copy to writable location
if (Test-Path $INSTALL_DIR) {
    Remove-Item $INSTALL_DIR -Recurse -Force
}
Write-Host "  Copying files (this may take 30s)..."
Copy-Item $TV_SRC $INSTALL_DIR -Recurse

# Extract asar
$ASAR_PATH = "$INSTALL_DIR\resources\app.asar"
$ASAR_SRC  = "$INSTALL_DIR\resources\app_src"
& asar extract $ASAR_PATH $ASAR_SRC 2>&1 | Out-Null

# Inject CDP flag at top of index.js
$INDEX_JS = "$ASAR_SRC\index.js"
$original = Get-Content $INDEX_JS -Raw
$patched  = $INJECT_CODE + "`n" + $original
Set-Content $INDEX_JS $patched -Encoding UTF8 -NoNewline

# Repack
& asar pack $ASAR_SRC $ASAR_PATH 2>&1 | Out-Null

# Cleanup extracted source
Remove-Item $ASAR_SRC -Recurse -Force

Write-Host "  OK" -ForegroundColor Green

# --- 6. Unregister old, register patched ---
Write-Host "[6/6] Registering patched TradingView..." -ForegroundColor Yellow

# Unregister existing
Get-AppxPackage *TradingView* | Remove-AppxPackage -ErrorAction SilentlyContinue
Start-Sleep 2

# Register patched
Add-AppxPackage -Path "$INSTALL_DIR\AppxManifest.xml" -Register
Write-Host "  OK" -ForegroundColor Green

# --- Done ---
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Launch TradingView from Start Menu" -ForegroundColor White
Write-Host "  2. Verify CDP: curl http://localhost:9222/json/version" -ForegroundColor White
Write-Host "  3. Clone tradingview-mcp:" -ForegroundColor White
Write-Host "     git clone https://github.com/tradesdontlie/tradingview-mcp.git" -ForegroundColor White
Write-Host "     cd tradingview-mcp && npm install" -ForegroundColor White
Write-Host "  4. Add MCP:" -ForegroundColor White
Write-Host "     claude mcp add tradingview -s user -- node C:\Users\$env:USERNAME\tradingview-mcp\src\server.js" -ForegroundColor White
Write-Host ""
Write-Host "TradingView installed at: $INSTALL_DIR" -ForegroundColor DarkGray
Write-Host "To revert: reinstall TradingView from Microsoft Store" -ForegroundColor DarkGray
