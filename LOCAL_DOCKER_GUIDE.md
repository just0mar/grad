# Local Docker Deployment Guide

This project contains two architectures that run together using Docker Compose. Since the application is split into two primary components (Core Server and AI Microservice), they can be run locally using the provided Docker Compose files.

## Prerequisites
- **Docker Desktop** (or Docker Engine + Docker Compose) installed on your machine.
- Your `.env` and `appsettings.json` configured with your local paths or Google Cloud Storage keys as necessary.
- Create a `.env` file in the root directory containing your `GROQ_API_KEY=gsk_...` so the AI Chatbot can run.

## Running the Application Locally

The project uses two separate Docker Compose files. To run everything simultaneously on a single local machine, you will start both.

### 1. Start the Core Services
The Core Services (`docker-compose.core.yml`) includes:
- PostgreSQL Database (`db`)
- `.NET` Core API (`api`)

**Command:**
```bash
docker-compose -f docker-compose.core.yml up --build -d
```
*Note: The `.NET` API will be accessible on `http://127.0.0.1:5000`*

### 2. Start the AI Microservices
The AI Microservices (`docker-compose.ai.yml`) includes:
- Python Chatbot / RAG Service (`chatbot`)
- (Optional) Prediction Models (`prediction_service`)

**Command:**
```bash
docker-compose -f docker-compose.ai.yml up --build -d
```
*Note: The Python Chatbot will be accessible on `http://127.0.0.1:8000`*

## Stopping the Application

To shut down all running services without losing database data:

```bash
docker-compose -f docker-compose.core.yml down
docker-compose -f docker-compose.ai.yml down
```

## Troubleshooting
- **Database Connection Issues:** Ensure `docker-compose.core.yml` is running before starting the AI services if the AI services need to communicate with the Core API immediately.
- **Port Conflicts:** Ensure ports `5000`, `8000`, and `5432` are not already being used by other applications on your computer.
