# BloodTrack360 — Reactive BECS MVP

**Author:** Venkat Yarlagadda  
**Purpose:** This project is built to showcase my hands-on knowledge of the technologies listed in ARC-One’s Senior Full-Stack Engineer job description and to support my interview preparation.

---

## 📌 Project Description

BloodTrack360 is a **local, interview-focused MVP** that simulates a slice of a Blood Establishment Computer Software (BECS) platform. It demonstrates modern, production-minded patterns that ARC-One values:

- **Reactive Java backend** using **Spring Boot WebFlux**
- **API discoverability** via **Swagger (springdoc)**
- **Operational readiness** via **Actuator** (health, info, metrics)
- **Event-driven design** with **Apache Kafka**
- **Relational persistence** via **PostgreSQL + R2DBC**
- **Secure access** using **Spring Security (JWT)**
- **Containerized developer experience** with **Docker / Docker Compose**
- **Automated quality gates** via **JUnit 5** (and optional Testcontainers)
- **CI skeleton** using **GitHub Actions** (local builds/tests only)

The goal is to model the **end-to-end lifecycle** of a donated blood unit (registration → testing → inventory update) using reactive APIs and Kafka events, with auditability and clear documentation.

---

## 🎯 Objectives

1. Demonstrate **architecture thinking and implementation** in a regulated-style SaaS context.
2. Show mastery of **Spring WebFlux**, **Kafka**, **Postgres (R2DBC)**, **Angular**, and **JWT**.
3. Provide **discoverable APIs** (Swagger) and **operational visibility** (Actuator).
4. Keep everything **local** (no cloud) and **interview-ready** within 24 hours.

---

## 🧰 Tech Stack

**Backend**
- Java 23, Spring Boot 3 (WebFlux, Actuator, Security/JWT)
- Spring Data R2DBC (PostgreSQL)
- Spring for Apache Kafka
- springdoc-openapi (Swagger UI)

**Frontend**
- Angular 18, RxJS, Angular Material (later step)

**Data & Messaging**
- PostgreSQL
- Apache Kafka

**Dev & Ops**
- Docker, Docker Compose
- Gradle (Kotlin DSL)
- JUnit 5 (optional: Testcontainers)
- GitHub Actions (local CI)

---

## 🗺️ Scope for the MVP

- **Reactive REST endpoints** (e.g., `/api/patients`, `/api/units`)
- **Swagger UI** for API exploration (`/swagger-ui/index.html`)
- **Actuator endpoints** for health and metrics
- **PostgreSQL schema migrations** (Flyway)
- **Kafka events** for lab results and inventory updates
- **JWT-based auth** (role-based routes)
- **Angular dashboard** to list/add patients and view unit statuses
- **Docker Compose** to run Postgres, Kafka, Backend, and Frontend locally
- **Basic CI workflow** (build + test) via GitHub Actions

> **Note:** Cloud and AI integrations are intentionally **out of scope** for this MVP.

---

## 🧪 What Will Be Done (Step Plan)

1. **GitHub Setup** (this step)
2. **Backend Skeleton**: Spring Boot WebFlux + Swagger + Actuator
3. **PostgreSQL Integration**: R2DBC + Flyway migrations + CRUD for `Patient`
4. **Frontend Scaffold**: Angular app with a simple Patient screen
5. **Kafka**: Local Kafka via Docker Compose; wire producer/consumer
6. **Spring for Apache Kafka**: publish/consume lab-result events
7. **Security**: Spring Security + JWT; protect `/api/**`
8. **E2E Sanity**: Donor → Lab Result → Inventory update path
9. **GitHub Actions**: Local build/test CI (no deploy)
10. **Docs & Polish**: README examples, curl scripts, architecture notes

---

## ⏭️ Next Logical Steps (Post-MVP)

- Add more bounded contexts (Donor, Lab, Inventory) with DDD patterns
- Enrich audit logging and immutable event history
- Add BDD (Cucumber) acceptance tests
- Observability: structured logs, tracing, and dashboards
- (Future) Cloud deployment and infra-as-code (out of scope for interview)

---

## 🚦 Local Development (quick start)

> Detailed run commands and Docker compose files will be added as each step is completed.
Start backend (dev):
  ```bash
    cd backend
    ./gradlew bootRun
    # Swagger: http://localhost:8080/swagger-ui/index.html
    # Actuator: http://localhost:8080/actuator/health
  ```

---

## 🐳 Once Docker Compose files are in place:
  ```bash
    cd docker
    docker compose up --build
  ```

---

## 🔐 Usage, Permissions, and License

This repository is created **solely for interview and demonstration purposes**.  
It **cannot be replicated, distributed, or used** in any form without the knowledge and written permission of the creator, **Venkat Yarlagadda**.

All rights are reserved under the license terms defined in the [LICENSE](LICENSE) file.

For permission requests or inquiries, please contact:  
📧 **hire.venkat.yarlagadda@gmail.com**
---
