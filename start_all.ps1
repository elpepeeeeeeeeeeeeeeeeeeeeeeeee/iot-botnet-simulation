<#
Start/prepare the IoT botnet simulation and (optionally) start tcpdump capture in victim container.
Usage examples:
  # quick start (no rebuild, no capture)
  .\start_all.ps1

  # rebuild c2 & device images and start services
  .\start_all.ps1 -Rebuild

  # start services and start a capture of 100 packets
  .\start_all.ps1 -StartCapture -CaptureCount 100

  # show help
  .\start_all.ps1 -Help
#>

param(
  [switch]$Rebuild = $false,
  [switch]$StartCapture = $false,
  [int]$CaptureCount = 100,
  [string]$ProjectPath = "M:\CCNS project work\project\iot-botnet-simulation"
)

Set-StrictMode -Version Latest

function ExitWith($msg) {
  Write-Host $msg -ForegroundColor Red
  exit 1
}

# 1) change to project folder
if (!(Test-Path $ProjectPath)) { ExitWith "Project path '$ProjectPath' not found. Edit script or provide -ProjectPath." }
Set-Location $ProjectPath

# 2) basic docker check
Write-Host "Checking Docker..." -ForegroundColor Cyan
try {
  & docker info > $null 2>&1
} catch {
  ExitWith "Docker does not appear to be running or 'docker' is not on PATH. Start Docker Desktop and re-run."
}
Write-Host "Docker OK." -ForegroundColor Green

# 3) rebuild images if requested
if ($Rebuild) {
  Write-Host "Rebuilding c2 & device images (--no-cache)..." -ForegroundColor Cyan
  & docker-compose build --no-cache c2 device
  if ($LASTEXITCODE -ne 0) { ExitWith "docker-compose build failed." }
}

# 4) start services
Write-Host "Starting services with docker-compose up -d ..." -ForegroundColor Cyan
& docker-compose up -d
if ($LASTEXITCODE -ne 0) { ExitWith "docker-compose up failed." }

# 5) wait for containers to be Up
Write-Host "Waiting for containers to be 'Up' (timeout 60s)..." -ForegroundColor Cyan
$timeout = 60
$start = Get-Date
while ((Get-Date) - $start).TotalSeconds -lt $timeout {
  $ps = & docker ps --format '{{.Names}} {{.Status}}'
  if ($ps -match 'iot-botnet-simulation-c2-1' -and $ps -match 'iot-botnet-simulation-device-1' -and $ps -match 'mosquitto' -and $ps -match 'victim') {
    if ($ps -match 'Up') { break }
  }
  Start-Sleep -Seconds 2
}
Write-Host "`nContainers:`n" -ForegroundColor Yellow
& docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# 6) show network attachments
Write-Host "`nNetwork attachments (container -> network):" -ForegroundColor Yellow
& docker inspect -f '{{ .Name }} -> {{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' $(docker ps -q) | ForEach-Object { Write-Host $_ }

# 7) dump short logs to verify (non-blocking)
Write-Host "`nSaving last 200 lines of service logs to local files..." -ForegroundColor Cyan
& docker logs iot-botnet-simulation-c2-1 --tail=200 > .\c2_last200.log 2>&1
& docker logs iot-botnet-simulation-device-1 --tail=200 > .\device_last200.log 2>&1
& docker logs mosquitto --tail=200 > .\mosquitto_last200.log 2>&1
& docker logs victim --tail=200 > .\victim_last200.log 2>&1
Write-Host "Saved: c2_last200.log, device_last200.log, mosquitto_last200.log, victim_last200.log" -ForegroundColor Green

# 8) Optional: start tcpdump inside victim
if ($StartCapture) {

  Write-Host "`nPreparing to start tcpdump in victim container..." -ForegroundColor Cyan

  # install tcpdump (apt-get) - may take a few seconds
  Write-Host "Installing tcpdump inside victim (apt-get update && apt-get install -y tcpdump)..." -ForegroundColor Cyan
  & docker exec -u 0 -it victim sh -c "apt-get update >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y tcpdump >/dev/null 2>&1"
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: installing tcpdump may have failed. You can install manually: docker exec -it victim sh -c 'apt-get update && apt-get install -y tcpdump'." -ForegroundColor Yellow
  } else {
    Write-Host "tcpdump (apt) invoked - installation attempted." -ForegroundColor Green
  }

  # start capture detached - writes to /tmp/victim.pcap inside container
  Write-Host "Starting detached tcpdump inside victim (port 8080) capturing $CaptureCount packets..." -ForegroundColor Cyan
  # Use docker exec -d to run detached; the inner sh -c runs tcpdump with the -c limit.
  & docker exec -d victim sh -c "tcpdump -i any port 8080 -w /tmp/victim.pcap -c $CaptureCount"
  Start-Sleep -Seconds 1

  # confirm tcpdump process started
  Write-Host "Confirming tcpdump is running (docker top victim)..." -ForegroundColor Cyan
  & docker top victim
  Write-Host "Capture started. File inside container: /tmp/victim.pcap" -ForegroundColor Green
  Write-Host "When done, run the 'Stop capture' and 'Copy pcap' commands (printed below)." -ForegroundColor Yellow
}

# 9) print helper commands for the user
Write-Host "`n--- Helper commands (copy-paste) ---`n" -ForegroundColor Cyan

Write-Host "Tail live logs (use in other tabs):" -ForegroundColor White
Write-Host "  docker logs -f iot-botnet-simulation-c2-1 --tail=200" -ForegroundColor Gray
Write-Host "  docker logs -f victim --tail=200" -ForegroundColor Gray
Write-Host "  docker logs -f iot-botnet-simulation-device-1 --tail=200" -ForegroundColor Gray

Write-Host "`nPublish 'do_attack' (MQTT):" -ForegroundColor White
Write-Host "  docker-compose exec mosquitto mosquitto_pub -t 'c2/commands' -m 'do_attack'" -ForegroundColor Gray

Write-Host "`nStop tcpdump (run when you want to stop capturing):" -ForegroundColor White
Write-Host "  docker exec -it victim sh -c \"pkill tcpdump || kill \$(pidof tcpdump) || true\"" -ForegroundColor Gray

Write-Host "`nCopy the pcap to host:" -ForegroundColor White
Write-Host "  docker cp victim:/tmp/victim.pcap .\\victim.pcap" -ForegroundColor Gray

Write-Host "`nSave logs for report:" -ForegroundColor White
Write-Host "  docker logs iot-botnet-simulation-c2-1 --tail=1000 > .\\c2_logs.txt" -ForegroundColor Gray
Write-Host "  docker logs iot-botnet-simulation-device-1 --tail=1000 > .\\device_logs.txt" -ForegroundColor Gray
Write-Host "  docker logs mosquitto --tail=1000 > .\\mosquitto_logs.txt" -ForegroundColor Gray
Write-Host "  docker logs victim --tail=1000 > .\\victim_logs.txt" -ForegroundColor Gray

Write-Host "`nIf you want to switch to bridge network (for service-name DNS), edit docker-compose.yml to remove network_mode: host, add 'networks: default: driver: bridge' and then run: docker-compose down && docker-compose up -d --build" -ForegroundColor Yellow

Write-Host "`nScript finished." -ForegroundColor Green
