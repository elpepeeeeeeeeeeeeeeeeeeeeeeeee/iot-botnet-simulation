FROM python:3.10-slim
WORKDIR /app
COPY c2.py /app/c2.py
RUN pip install --no-cache-dir paho-mqtt==1.6.1 requests
CMD ["python3","-u","c2.py"]
