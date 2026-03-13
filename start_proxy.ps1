# Forward Proxy Server — PowerShell launcher
# Usage:
#   .\start_proxy.ps1
#   .\start_proxy.ps1 -Port 2222
#   .\start_proxy.ps1 -Port 2222 -NoLog

param(
    [int]$Port = 1111,
    [string]$Bind = "0.0.0.0",
    [switch]$NoLog
)

$env:PROXY_PORT = $Port
$env:PROXY_BIND = $Bind
$env:PROXY_LOG = if ($NoLog) { "false" } else { "true" }

Write-Host "Starting proxy on ${Bind}:${Port} ..." -ForegroundColor Green
Write-Host "Stop with Ctrl+C" -ForegroundColor Yellow
Write-Host ""

python proxy_server.py
