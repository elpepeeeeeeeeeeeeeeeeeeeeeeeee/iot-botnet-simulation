import os, time, json, random
import paho.mqtt.client as mqtt

BROKER_HOST = os.getenv("BROKER_HOST", "localhost")
BROKER_PORT = int(os.getenv("BROKER_PORT", "1883"))
CLIENT_ID   = os.getenv("CLIENT_ID", "device-1")

def on_connect(client, userdata, flags, rc):
    print(f"device connected rc={rc}")

client = mqtt.Client(client_id=CLIENT_ID)
client.on_connect = on_connect

while True:
    try:
        client.connect(BROKER_HOST, BROKER_PORT, keepalive=30)
        break
    except Exception as e:
        print(f"connect failed: {e}; retry in 2s")
        time.sleep(2)

client.loop_start()
while True:
    temp = round(20 + random.random()*10, 2)
    payload = {"device": CLIENT_ID, "temp": temp, "ts": time.time()}
    client.publish("devices/data", json.dumps(payload))
    time.sleep(2)
