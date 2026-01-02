from kafka import KafkaConsumer
import json
import requests
import os
import logging

logging.basicConfig(level=logging.INFO)

KAFKA_BROKER = os.environ.get("KAFKA_BROKER", "kafka:9092")
ELASTIC_URL = os.environ.get("ELASTIC_URL", "http://elasticsearch:9200")

logging.info("Starting Kafka consumer...")

consumer = KafkaConsumer(
    'products',
    'orders',
    'suppliers',
    bootstrap_servers=KAFKA_BROKER,
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    group_id='event-consumer-group-final',
    auto_offset_reset='earliest'
)

logging.info("Kafka consumer connected and listening")

for msg in consumer:
    topic = msg.topic
    data = msg.value

    logging.info(f"Received message from topic: {topic}")

    if topic == "products":
        index = "products-index"
    elif topic == "orders":
        index = "orders-index"
    elif topic == "suppliers":
        index = "suppliers-index"
    else:
        continue

    r = requests.post(f"{ELASTIC_URL}/{index}/_doc", json=data)
    logging.info(f"Indexed to {index}, status={r.status_code}")
