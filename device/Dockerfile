FROM python:3.10-slim
WORKDIR /app
COPY device.py /app/device.py
RUN pip install --no-cache-dir paho-mqtt==1.6.1
CMD ["python3","-u","device.py"]
