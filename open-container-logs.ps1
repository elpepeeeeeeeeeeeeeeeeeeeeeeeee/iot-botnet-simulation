
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f mosquitto"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f victim"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f iot-botnet-simulation-c2-1"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f iot-botnet-simulation-device-1"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f iot-botnet-simulation-device-2"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f iot-botnet-simulation-device-3"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f iot-botnet-simulation-device-4"
Start-Sleep -Seconds 1
Start-Process powershell -ArgumentList "-NoExit", "-Command docker logs -f iot-botnet-simulation-device-5"
