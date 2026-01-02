FROM python:3.10-slim

WORKDIR /app

COPY producer.py .

RUN pip install flask kafka-python

EXPOSE 8080

CMD ["python", "producer.py"]
