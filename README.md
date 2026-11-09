# Precision Auto Care - SOA Microservices Application

Production-ready, modular Service-Oriented Architecture (SOA) application built with **Spring Boot 4**, **Spring Cloud 2025**, **Netflix Eureka**, and **Spring Cloud Gateway**.

---

## Architecture Overview

```
                                [ Client / Web / Mobile ]
                                            │
                                            ▼
                    ┌──────────────────────────────────────────────┐
                    │          API GATEWAY (:8080)                 │
                    │  - Global JWT AuthenticationFilter           │
                    │  - Path Routing & Header Injection           │
                    │  - Global CORS Configuration                 │
                    └──────────────────────┬───────────────────────┘
                                           │
         ┌───────────────────┬─────────────┴─────────────┬───────────────────┐
         │                   │                           │                   │
         ▼                   ▼                           ▼                   ▼
┌──────────────────┐┌──────────────────┐       ┌──────────────────┐┌──────────────────┐
│   AUTH SERVICE   ││ BOOKING SERVICE  │       │  RECORD SERVICE  ││ BILLING SERVICE  │
│      (:8081)     ││     (:8082)      │       │     (:8083)      ││     (:8084)      │
│ - BCrypt & JWT   ││ - Feign Intercep │──────▶│ - Feign Intercep │──────▶│ - Invoicing      │
│ - /login         ││ - @Transactional │ Open  │ - @Transactional │ Open  │ - Auto-date/status│
│ - /register      ││ - Input Validat. │ Feign │ - Input Validat. │ Feign │ - Input Validat. │
│ - /validate      ││ - Sec Filter     │       │ - Sec Filter     │       │ - Sec Filter     │
└──────────────────┘└──────────────────┘       └──────────────────┘└──────────────────┘
         │                   │                           │                   │
         └───────────────────┴─────────────┬─────────────┴───────────────────┘
                                           │ Service Registration & Heartbeats
                                           ▼
                    ┌──────────────────────────────────────────────┐
                    │           EUREKA SERVER (:8761)              │
                    │           Service Discovery Hub              │
                    └──────────────────────────────────────────────┘
```

---

## Services & Ports

| Service | Port | Description |
| :--- | :---: | :--- |
| **Eureka Server** | `8761` | Service Registry & Discovery server |
| **API Gateway** | `8080` | Unified Entry Point with JWT Security Filter & CORS |
| **Auth Service** | `8081` | Authentication, BCrypt hashing, JWT generation & validation |
| **Booking Service** | `8082` | Vehicle service bookings & orchestrator to Record Service |
| **Record Service** | `8083` | Vehicle service records & orchestrator to Billing Service |
| **Billing Service** | `8084` | Invoicing & financial tracking |

---

## Security Architecture

1. **Perimeter Defense (API Gateway)**:
   - Validates JWT tokens on all protected routes (`/api/bookings/**`, `/api/records/**`, `/api/billing/**`).
   - Whitelists public endpoints (`/api/auth/**`, `/actuator/**`).
   - Rejects invalid, expired, or missing tokens with `HTTP 401 Unauthorized`.
   - Injects authenticated user claims into downstream headers: `X-Auth-User` and `X-Auth-Role`.

2. **Defense-in-Depth (Microservice Security)**:
   - Downstream services enforce stateless Spring Security filters (`JwtAuthenticationFilter`).
   - Direct requests bypassing the Gateway are still authenticated against the token.

3. **Secure Inter-Service Communication**:
   - `FeignClientInterceptor` automatically propagates the `Authorization` Bearer token and user context headers through downstream OpenFeign calls:
     $$\text{Client} \xrightarrow[\text{Bearer JWT}]{\text{Gateway}} \text{Booking Service} \xrightarrow[\text{Bearer JWT}]{\text{Feign}} \text{Record Service} \xrightarrow[\text{Bearer JWT}]{\text{Feign}} \text{Billing Service}$$

---

## Database Configuration

All database services support zero-friction standalone development via embedded H2 database (`MODE=PostgreSQL`) while fully supporting external PostgreSQL via standard environment variables:

| Environment Variable | Default Value | Description |
| :--- | :--- | :--- |
| `SPRING_DATASOURCE_URL` | `jdbc:h2:mem:<name>_db...` | JDBC Connection URL |
| `SPRING_DATASOURCE_USERNAME` | `sa` | Database Username |
| `SPRING_DATASOURCE_PASSWORD` | *(empty)* | Database Password |
| `SPRING_DATASOURCE_DRIVER_CLASS_NAME` | `org.h2.Driver` | JDBC Driver Class |
| `JWT_SECRET` | `PrecisionAutoCare...` | 256-bit HMAC secret |

---

## Quick Start Guide

### 1. Run Automated Unit & Integration Tests (52 Tests)
```powershell
# From the project root:
cd .\api-gateway; .\mvnw.cmd test; cd ..
cd .\auth-service; .\mvnw.cmd test; cd ..
cd .\booking-service; .\mvnw.cmd test; cd ..
cd .\record-service; .\mvnw.cmd test; cd ..
cd .\billing-service; .\mvnw.cmd test; cd ..
cd .\eureka-server; .\mvnw.cmd test; cd ..
```

### 2. Start All Microservices
```powershell
powershell -ExecutionPolicy Bypass -File .\start-all.ps1
```
* Eureka Dashboard: [http://localhost:8761](http://localhost:8761)
* API Gateway: [http://localhost:8080](http://localhost:8080)

### 3. Run Live End-to-End Architectural Verification
```powershell
powershell -ExecutionPolicy Bypass -File .\run-e2e-demo.ps1
```

### 4. Stop All Microservices
```powershell
powershell -ExecutionPolicy Bypass -File .\stop-all.ps1
```
