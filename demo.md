\# Demo Guide (5–10 minutes)



This demo shows an IoT botnet lab running end-to-end using Docker Compose.



\## Components (as seen in docker ps)

\- MQTT monitoring: mosquitto-exporter

\- C2 Server: iot-botnet-simulation-c2-1

\- IoT Device Simulator: iot-botnet-simulation-device-1

\- Victim Service: victim

\- Monitoring UI: graf (Grafana), cadvisor



---



\## Prerequisites

\- Docker Desktop installed and running

\- Run commands from the project root directory



---



\## 1) Start the lab

```bash

docker compose up -d --build

Expected:



All containers start without errors



2\) Verify running containers

bash

Copy code

docker ps

Expected containers:



iot-botnet-simulation-c2-1



iot-botnet-simulation-device-1



victim



mosquitto-exporter



graf



cadvisor



3\) View C2 server logs

bash

Copy code

docker logs -f iot-botnet-simulation-c2-1

Expected:



MQTT connection successful



Heartbeat / command handling logs



Press Ctrl + C to exit.



4\) View device simulator logs

bash

Copy code

docker logs -f iot-botnet-simulation-device-1

Expected:



Periodic telemetry messages



MQTT publish activity



Press Ctrl + C to exit.



5\) View victim service logs

bash

Copy code

docker logs -f victim

Expected:



Incoming HTTP requests triggered by C2



Press Ctrl + C to exit.



6\) Scale IoT devices (optional but impressive)

bash

Copy code

docker compose up -d --scale device=5

Expected:



Multiple device containers running



Increased telemetry volume



Verify:



bash

Copy code

docker ps

7\) Stop the lab

bash

Copy code

docker compose down

Expected:



All containers stopped cleanly



Notes

Generated logs, pcaps, and IDS outputs are intentionally excluded from GitHub.



This project is a controlled academic simulation for security learning.

