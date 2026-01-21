<#
start_and_capture_with_tabs.ps1

Opens Windows Terminal tabs (Admin, MQTT, C2 logs, Victim logs, Admin2),
starts the compose stack (optionally rebuild), starts tcpdump in victim,
publishes do_attack, waits for capture, copies pcap and saves logs.

Usage:
  # default: start services (no rebuild), capture 50 packets
  .\start_and_capture_with_tabs.ps1

  # rebuild c2 & device before start and capture 100 packets:
  .\start_and_capture_with_tabs.ps1 -Rebuild -CaptureCount 100

Requirements:
  - Run PowerShell as Administrator
  - wt.exe (Windows Terminal) in PATH
  - Docker Desktop running
#>

param(
  [switch]$Rebuild = $false,
  [int]$CaptureCount = 50,
  [string]$ProjectPath = "M:\CCNS project work\project\iot-botnet-simulation"
)

Set-StrictMode -Version Latest

function Fail($msg) {
  Write-Host $msg -ForegroundColor Red
  exit 1
}

# 0) sanity checks
if (-not (Test-Path $ProjectPath)) { Fail "Project path '$ProjectPath' not found. Edit script param -ProjectPath if different." }

# ensure wt exists
if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
  Fail "Windows Terminal (wt.exe) not found in PATH. Install Windows Terminal from Microsoft Store or ensure 'wt' is in PATH."
}

# ensure Docker available
try {
  docker version > $null 2>&1
} catch {
  Fail "Docker not available. Start Docker Desktop and re-run."
}

# 1) optionally rebuild
if ($Rebuild) {
  Write-Host "Rebuilding c2 & device images (no-cache)..." -ForegroundColor Cyan
  docker-compose build --no-cache c2 device
  if ($LASTEXITCODE -ne 0) { Fail "docker-compose build failed." }
}

# 2) Construct wt command to open 5 tabs:
#    Tab 1: Admin  -> runs docker-compose up -d and shows docker ps
#    Tab 2: MQTT   -> runs a mosquitto_sub (live subscriber)
#    Tab 3: C2 logs-> docker logs -f for c2
#    Tab 4: Victim logs -> docker logs -f victim
#    Tab 5: Admin2 -> ready for manual actions (we also run automated actions from this script)
Write-Host "Opening Windows Terminal with named tabs..." -ForegroundColor Cyan

# Prepare commands (ensure inner single/double quotes are escaped correctly).
$adminCmd = "title Admin; Set-Location '$ProjectPath'; docker-compose up -d; docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'; Write-Host 'Admin tab ready (services started).'"
$mqttCmd = "title MQTT; Set-Location '$ProjectPath'; Write-Host 'MQTT tab: subscriber will show telemetry (Ctrl+C to stop).'; docker exec -it mosquitto sh -c ""mosquitto_sub -t 'devices/data'"" "
$c2Cmd = "title 'C2 logs'; Set-Location '$ProjectPath'; docker logs -f iot-botnet-simulation-c2-1 --tail=200"
$victimCmd = "title 'Victim logs'; Set-Location '$ProjectPath'; docker logs -f victim --tail=200"
$admin2Cmd = "title Admin2; Set-Location '$ProjectPath'; Write-Host 'Admin2 tab: for manual actions if needed. You can run: docker-compose exec mosquitto mosquitto_pub -t ''c2/commands'' -m ''do_attack'' '"

# Build the argument list for wt.exe
# We pass multiple new-tab arguments separated by ';' in a single wt invocation
$wtArg = @(
  "new-tab", "pwsh -NoExit -Command ""$adminCmd""",
  ";", "new-tab", "pwsh -NoExit -Command ""$mqttCmd""",
  ";", "new-tab", "pwsh -NoExit -Command ""$c2Cmd""",
  ";", "new-tab", "pwsh -NoExit -Command ""$victimCmd""",
  ";", "new-tab", "pwsh -NoExit -Command ""$admin2Cmd"""
) -join " "

Start-Process -FilePath wt -ArgumentList $wtArg

Write-Host "Windows Terminal tabs launched. Allow a few seconds for terminals to initialize..." -ForegroundColor Green
Start-Sleep -Seconds 4

# 3) Start docker-compose (again) to be sure services are running for automation (main script)
Write-Host "Ensuring docker-compose services are up (from main script)..." -ForegroundColor Cyan
docker-compose up -d
if ($LASTEXITCODE -ne 0) { Fail "docker-compose up -d failed." }

# 4) Prepare tcpdump inside victim
Write-Host "Installing tcpdump inside victim (apt-get) — this may take a moment..." -ForegroundColor Cyan
docker exec -u 0 victim sh -c "apt-get update >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y tcpdump >/dev/null 2>&1" 
# not failing hard if apt attempt fails — we'll try to continue and report
if ($LASTEXITCODE -ne 0) {
  Write-Host "Warning: apt install of tcpdump may have failed. Check the victim container manually." -ForegroundColor Yellow
}

# 5) Start tcpdump detached inside victim, capturing CaptureCount packets
$pcapInside = "/tmp/victim_$(Get-Date -Format 'yyyyMMdd_HHmmss').pcap"
Write-Host "Starting tcpdump inside victim to capture $CaptureCount packets to $pcapInside ..." -ForegroundColor Cyan
docker exec -d victim sh -c "tcpdump -i any port 8080 -w $pcapInside -c $CaptureCount"
Start-Sleep -Seconds 2

# 6) Confirm tcpdump started via docker top
Write-Host "Confirming tcpdump started (docker top victim)..." -ForegroundColor Cyan
$top = docker top victim 2>&1
Write-Host $top

# 7) Trigger the attack (publish do_attack) so C2 performs the GETs while capture runs
Write-Host "Publishing 'do_attack' message to c2/commands (docker-compose exec mosquitto mosquitto_pub ...) ..." -ForegroundColor Cyan
docker-compose exec mosquitto mosquitto_pub -t 'c2/commands' -m 'do_attack'
if ($LASTEXITCODE -ne 0) {
  Write-Host "Warning: publishing do_attack failed. You can publish manually from Admin2 tab." -ForegroundColor Yellow
}

# 8) Wait until tcpdump process finishes (poll docker top)
Write-Host "Waiting for tcpdump to finish capturing (polling)..." -ForegroundColor Cyan
while ($true) {
  Start-Sleep -Seconds 1
  $topOut = docker top victim 2>&1
  if ($topOut -match "tcpdump") {
    # still running
    continue
  } else {
    break
  }
}
Write-Host "tcpdump appears to have finished (or not present). Proceeding to copy pcap." -ForegroundColor Green

# 9) Copy the pcap from container to host (project folder)
$localPcap = Join-Path -Path $ProjectPath -ChildPath ("victim_capture_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".pcap")
Write-Host "Copying pcap from container ($pcapInside) to host: $localPcap" -ForegroundColor Cyan
docker cp "victim:$pcapInside" "$localPcap"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Warning: docker cp failed. Did tcpdump write the file? Check inside container." -ForegroundColor Yellow
} else {
  Write-Host "Copied pcap to: $localPcap" -ForegroundColor Green
}

# 10) Save logs and zip results
Write-Host "Saving logs to project folder and creating results zip..." -ForegroundColor Cyan
$logC2 = Join-Path $ProjectPath "c2_logs.txt"
$logDevice = Join-Path $ProjectPath "device_logs.txt"
$logMosq = Join-Path $ProjectPath "mosquitto_logs.txt"
$logVictim = Join-Path $ProjectPath "victim_logs.txt"
docker logs iot-botnet-simulation-c2-1 --tail=2000 > $logC2 2>&1
docker logs iot-botnet-simulation-device-1 --tail=2000 > $logDevice 2>&1
docker logs mosquitto --tail=2000 > $logMosq 2>&1
docker logs victim --tail=2000 > $logVictim 2>&1

$zipPath = Join-Path $ProjectPath "iot-sim-results_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
try {
  Compress-Archive -Path $localPcap, $logC2, $logDevice, $logMosq, $logVictim -DestinationPath $zipPath -Force
  Write-Host "Created results archive: $zipPath" -ForegroundColor Green
} catch {
  Write-Host "Compress-Archive failed: $_" -ForegroundColor Yellow
  Write-Host "Files are saved individually in the project folder." -ForegroundColor Yellow
}

Write-Host "`nAll done. Tabs remain open for live viewing." -ForegroundColor Green
Write-Host "Files saved in $ProjectPath:" -ForegroundColor White
Get-ChildItem -Path $ProjectPath -Filter "victim_capture*.pcap","*.txt","*.zip" | Select-Object Name, Length, LastWriteTime | Format-Table

Write-Host "`nIf you need to stop the live tails in the tabs, close those tabs. If you want to re-run without new windows, run the automation parts (tcpdump + publish) manually." -ForegroundColor Cyan
