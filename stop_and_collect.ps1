<#
stop_and_collect.ps1
Stops tcpdump in victim container, copies /tmp/victim.pcap to host,
saves service logs and creates iot-sim-results.zip

Usage:
  From project folder:
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\stop_and_collect.ps1
#>

Set-StrictMode -Version Latest

$ProjectPath = "M:\CCNS project work\project\iot-botnet-simulation"
if (!(Test-Path $ProjectPath)) {
  Write-Host "Project path not found: $ProjectPath" -ForegroundColor Red
  exit 1
}
Set-Location $ProjectPath

function Run($cmd) {
  Write-Host "`n> $cmd" -ForegroundColor Cyan
  & cmd /c $cmd
  return $LASTEXITCODE
}

Write-Host "Stopping tcpdump inside victim container (if running)..." -ForegroundColor Yellow
# best-effort kill
docker exec -it victim sh -c "pkill tcpdump || kill \$(pidof tcpdump) || true" 2>$null

Start-Sleep -Seconds 1

# Check pcap exists
Write-Host "Checking for /tmp/victim.pcap inside victim..." -ForegroundColor Cyan
$exists = docker exec victim sh -c "test -f /tmp/victim.pcap && echo present || echo missing" 2>&1
Write-Host "victim pcap status: $exists" -ForegroundColor Green

if ($exists -match "present") {
  Write-Host "Copying /tmp/victim.pcap to host folder..." -ForegroundColor Cyan
  docker cp victim:/tmp/victim.pcap .\victim.pcap
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Copied to: .\victim.pcap" -ForegroundColor Green
  } else {
    Write-Host "docker cp failed. Check permissions." -ForegroundColor Red
  }
} else {
  Write-Host "No pcap found at /tmp/victim.pcap — skipping copy." -ForegroundColor Yellow
}

# Save last 2000 lines of logs (adjust count if needed)
Write-Host "`nSaving logs to files..." -ForegroundColor Cyan
docker logs iot-botnet-simulation-c2-1 --tail=2000 > .\c2_logs.txt 2>&1
docker logs iot-botnet-simulation-device-1 --tail=2000 > .\device_logs.txt 2>&1
docker logs mosquitto --tail=2000 > .\mosquitto_logs.txt 2>&1
docker logs victim --tail=2000 > .\victim_logs.txt 2>&1
Write-Host "Saved: c2_logs.txt, device_logs.txt, mosquitto_logs.txt, victim_logs.txt" -ForegroundColor Green

# Create zip
$zipname = ".\iot-sim-results.zip"
if (Test-Path $zipname) { Remove-Item $zipname -Force }
Write-Host "`nCompressing files to $zipname..." -ForegroundColor Cyan
try {
  Compress-Archive -Path .\victim.pcap,.\c2_logs.txt,.\device_logs.txt,.\mosquitto_logs.txt,.\victim_logs.txt -DestinationPath $zipname -Force
  Write-Host "Created $zipname" -ForegroundColor Green
} catch {
  Write-Host "Compress-Archive failed: $_" -ForegroundColor Red
  Write-Host "You can manually zip the files found in the project folder." -ForegroundColor Yellow
}

Write-Host "`nDone. Files in: $ProjectPath" -ForegroundColor Green
Write-Host "Open the project folder and check victim.pcap and iot-sim-results.zip." -ForegroundColor White
