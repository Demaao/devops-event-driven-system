# Event‑Driven DevOps Project (AWS, Kubernetes, Kafka, Elasticsearch)
By : Dema Omar 

## Overview

This project implements a **practical, end‑to‑end event‑driven architecture** that simulates real‑world DevOps responsibilities.
The system supports ingesting **Products, Orders, and Suppliers** through two different entry paths (real‑time API and batch file upload), processes the events using **Kafka**, runs workloads on **Kubernetes**, and provides **centralized logging and monitoring** using **Elasticsearch and Kibana**.

All infrastructure is provisioned using **Terraform**, following Infrastructure‑as‑Code (IaC) principles.

---

## High‑Level Architecture
The system is built as an event‑driven pipeline:
1. **External Ingestion**
   * HTTP requests via **API Gateway**
   * Batch uploads via **S3 bucket**

2. **Event Routing**
   * AWS **Lambda** functions validate and route events
   * Events are forwarded to a **Producer microservice**

3. **Messaging Backbone**
   * **Apache Kafka** with separate topics for:
     * `products`
     * `orders`
     * `suppliers`

4. **Processing Layer**
   * Kafka **Consumers** running as Kubernetes workloads
   * Events are indexed into **Elasticsearch**

5. **Observability**
   * Logs collected by **Fluent Bit**
   * Visualized using **Kibana dashboards**

---

## Data Flow
### 1. API‑Based Ingestion (Real‑Time)

1. Client sends an HTTP request to API Gateway
2. API Gateway triggers `lambda_api.py`
3. Lambda validates the entity type (`product`, `order`, `supplier`)
4. Lambda forwards the event to the Producer service via HTTP
5. Producer publishes the event to the correct Kafka topic
6. Consumer reads the event and indexes it into Elasticsearch

### 2. S3‑Based Ingestion (Batch)
1. A JSON file is uploaded to an S3 bucket
2. `lambda_function.py` is triggered automatically
3. Lambda determines the entity type from the file name
4. Each item in the file is converted into an event
5. Events are sent to the Producer service
6. Kafka → Consumer → Elasticsearch (same pipeline as API ingestion)

---

## Detailed Code Behavior and Implementation Logic:

### API Lambda (`lambda_api.py`)
The API Lambda serves as the real-time ingestion entry point.

**Behavior inside the code:**
- Receives HTTP requests forwarded from API Gateway.
- Parses the request body as JSON.
- Extracts the `type` field to identify the entity (`product`, `order`, or `supplier`).
- Validates that the entity type is supported.
- Wraps the data into a unified event structure.
- Forwards the event via HTTP to the Producer microservice.

**Design decision:**
The Lambda does not publish directly to Kafka. Kafka access is centralized in the Producer service, reducing coupling between AWS services and Kafka.

---

### S3 Lambda (`lambda_function.py`)
The S3 Lambda enables batch ingestion.

**Behavior inside the code:**
- Triggered automatically when a file is uploaded to S3.
- Determines the entity type based on the file name.
- Reads the uploaded JSON file from S3.
- Assumes the file contains a JSON array.
- Iterates over each item and converts it into an event.
- Sends each event to the Producer service using HTTP.

**Design decision:**
Batch ingestion uses the same downstream pipeline as real-time API ingestion, ensuring consistency across the system.

---

### Producer Service (`producer.py`)
The Producer is a Flask-based microservice running inside Kubernetes.

**Behavior inside the code:**
- Exposes a `/produce` HTTP endpoint.
- Validates incoming payloads.
- Maps entity types to Kafka topics:
  - `product` → `products`
  - `order` → `orders`
  - `supplier` → `suppliers`
- Serializes messages as JSON.
- Publishes messages to Kafka using a Kafka producer.
- Flushes messages to guarantee delivery.
- Exposes a `/health` endpoint for Kubernetes health checks.

---

## Kafka – Messaging Backbone
Kafka acts as the core messaging layer of the system.

**Implementation details:**
- Three topics are defined: `products`, `orders`, and `suppliers`.
- Topics separate entity types logically.
- Kafka provides asynchronous communication, decoupling producers from consumers.
- Kafka and Zookeeper run inside Kubernetes for simplicity.

---

### Consumer (`consumer.py`)
The Consumer processes events and indexes them into Elasticsearch.

**Behavior inside the code:**
- Subscribes to all Kafka topics using a consumer group.
- Deserializes JSON messages.
- Determines the Elasticsearch index based on the topic.
- Indexes each event as a document in Elasticsearch.

---

## Kubernetes Deployment Logic
Kubernetes orchestrates all runtime services.

**Implementation details:**
- Producer and Consumer run as Deployments.
- Services enable internal communication and service discovery.
- Kafka and Zookeeper run in a dedicated namespace.
- Configuration is injected using environment variables.

---

## Logging Pipeline – Fluent Bit, Elasticsearch, and Kibana
**Behavior inside the system:**
- All services write logs to standard output.
- Fluent Bit runs as a DaemonSet on each node.
- Fluent Bit collects logs from all containers.
- Logs are forwarded to Elasticsearch.
- Kibana dashboards visualize logs and events.

---

## Component Breakdown

### Terraform (`main.tf`, `variables.tf`, `outputs.tf`)
* Provisions all AWS infrastructure
* Includes VPC, networking, IAM roles, API Gateway, S3 bucket, and Lambda functions

### API Lambda (`lambda_api.py`)
* Entry point for HTTP requests
* Validates entity type
* Forwards events to the Producer service

### S3 Lambda (`lambda_function.py`)
* Triggered by file uploads to S3
* Determines entity type from file name
* Reads JSON arrays and emits events per item
* Supports bulk ingestion

### Producer Service (`producer.py`)
* Flask‑based microservice
* Central Kafka Producer
* Maps entity types to Kafka topics

### Kafka
* Three topics: `products`, `orders`, `suppliers`
* Provides decoupling and scalability

### Consumer Service (`consumer.py`)
* Kafka consumer subscribed to all topics
* Runs inside Kubernetes
* Writes events into Elasticsearch indices

### Kubernetes Manifests
* Deployments and Services for Producer and Consumer
* Kafka and Zookeeper deployed in a dedicated namespace
* Designed for scalability and isolation

### Logging & Monitoring
* Fluent Bit collects logs from all Pods
* Logs are forwarded to Elasticsearch
* Kibana dashboards provide visibility and filtering

---

## Elasticsearch Indexing
Separate indices are used for each entity type:
* `products-index`
* `orders-index`
* `suppliers-index`
This separation improves clarity, querying, and monitoring.

---

## Observability with Kibana
Kibana dashboards allow:
* Viewing ingested events
* Filtering by entity type
* Searching logs
* Monitoring system behavior end‑to‑end

---

## Assumptions & Design Decisions
* Lambdas do not publish directly to Kafka (decoupling)
* Producer service centralizes Kafka access
* Kafka runs with Zookeeper for simplicity
* Elasticsearch is used for indexing and log storage
* CI/CD and container registries are excluded by design

---

