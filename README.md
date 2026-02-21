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

## Assumptions & Design Decisions
* Lambdas do not publish directly to Kafka (decoupling)
* Producer service centralizes Kafka access
* Kafka runs with Zookeeper for simplicity
* Elasticsearch is used for indexing and log storage
* CI/CD and container registries are excluded by design

---


