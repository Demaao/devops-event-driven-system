from flask import Flask, request, jsonify
from kafka import KafkaProducer
import json
import os

app = Flask(__name__)

KAFKA_BROKER = os.environ.get("KAFKA_BROKER", "kafka:9092")

producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKER,
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

TOPIC_MAP = {
    "product": "products",
    "order": "orders",
    "supplier": "suppliers"
}

@app.route("/produce", methods=["POST"])
def produce():
    data = request.get_json()

    entity_type = data.get("type")
    payload = data.get("data")

    if entity_type not in TOPIC_MAP:
        return jsonify({"error": "Invalid type"}), 400

    if payload is None:
        return jsonify({"error": "Missing data field"}), 400

    topic = TOPIC_MAP[entity_type]

    producer.send(topic, payload)
    producer.flush()

    print(f"Sent event to Kafka topic '{topic}': {payload}")

    return jsonify({"status": "sent", "topic": topic}), 200


@app.route("/health", methods=["GET"])
def health():
    return "ok", 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
