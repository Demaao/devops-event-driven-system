FROM python:3.10-slim

WORKDIR /app

COPY consumer.py .

RUN pip install kafka-python requests

CMD ["python", "-u", "consumer.py"]
