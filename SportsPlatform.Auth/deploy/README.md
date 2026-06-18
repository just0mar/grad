# Distributed Docker Deployment

This deployment runs the platform on three machines while keeping each service's
state on its own host.

```text
Clients
   |
   v
Backend machine :5122
  - ASP.NET API
  - PostgreSQL (private Docker network)
  - basketball stats extractor (private Docker network)
   |                         ^
   | webhook / chat proxy   | PDFs and live team data
   v                         |
Chatbot machine :8000 -------+
  - FastAPI chatbot
  - Celery workers
  - Redis (private Docker network)
   |
   | authenticated retrain + prediction reads
   v
Prediction machine :8101
  - FastAPI prediction API
  - FIBA model code and persisted per-team artifacts
   |
   | authenticated PDF pulls
   +-------------------------> Backend machine :5122
```

## Network Contract

Use private DNS names, a VPN, or private cloud addresses. The examples use:

- `backend.internal:5122`
- `chatbot.internal:8000`
- `prediction.internal:8101`

Firewall rules should allow:

- Backend `5122`: application clients, chatbot machine, and prediction machine.
- Chatbot `8000`: backend machine only.
- Prediction `8101`: chatbot machine only.
- PostgreSQL `5432` and Redis `6379`: do not expose them outside Docker.

For traffic crossing an untrusted network, put TLS reverse proxies in front of all
three HTTP services or connect the machines through a private VPN. The Compose files
use HTTP because TLS termination and certificates are environment-specific.

## 1. Prepare All Machines

Install Docker Engine with the Compose v2 plugin and deploy the same repository commit
to each machine. Configure DNS or each machine's hosts file so the three private names
resolve correctly.

Generate two independent random service tokens. In PowerShell:

```powershell
[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
```

Token A authenticates backend/chatbot calls and prediction-to-backend PDF pulls.
Token B authenticates chatbot/prediction calls.

## 2. Backend Machine

Create the runtime environment file from `deploy/backend/.env.example` and set:

- Database and JWT secrets.
- `CHATBOT_BASE_URL=http://chatbot.internal:8000`.
- `BACKEND_PUBLIC_BASE_URL=http://backend.internal:5122`. This exact host must be
  reachable by both Python machines because it is embedded in PDF pull URLs.
- `BACKEND_CHATBOT_SERVICE_TOKEN` to Token A.

Start the backend stack:

```powershell
docker compose --env-file deploy/backend/.env -f deploy/backend/docker-compose.yml up -d --build
```

The backend stack persists PostgreSQL, uploaded files, and ASP.NET data-protection
keys in named volumes. The stats extractor is reachable only by the API container at
`http://stats-extractor:8100`.

## 3. Prediction Machine

Create `deploy/prediction/.env` from the example and set:

- `BACKEND_BASE_URL=http://backend.internal:5122`.
- `BACKEND_CHATBOT_SERVICE_TOKEN` to Token A.
- `CHATBOT_PREDICTION_SERVICE_TOKEN` to Token B.

Start the prediction service:

```powershell
docker compose --env-file deploy/prediction/.env -f deploy/prediction/docker-compose.yml up -d --build
```

The prediction machine owns downloaded model PDFs, trained model state, training CSVs,
and prediction CSVs in the `prediction_data` named volume. Training concurrency
defaults to one CPU-heavy training job at a time and can be adjusted with
`MAX_CONCURRENT_TRAININGS`.

## 4. Chatbot Machine

Create `deploy/chatbot/.env` from the example and set:

- Groq credentials and model.
- `BACKEND_BASE_URL=http://backend.internal:5122`.
- `PREDICTION_BASE_URL=http://prediction.internal:8101`.
- `BACKEND_CHATBOT_SERVICE_TOKEN` to Token A.
- `CHATBOT_PREDICTION_SERVICE_TOKEN` to Token B.

Start the chatbot stack:

```powershell
docker compose --env-file deploy/chatbot/.env -f deploy/chatbot/docker-compose.yml up -d --build
```

The chatbot API, Celery workers, and Redis share a private Docker network. Chatbot
project data is persisted in `chatbot_data`; Redis state is persisted separately.

## 5. Verify

Check public liveness endpoints:

```powershell
curl http://backend.internal:5122/api/health
curl http://chatbot.internal:8000/health
curl http://prediction.internal:8101/health
```

Check authenticated prediction status from the chatbot or an administrator machine:

```powershell
$headers = @{ Authorization = "Bearer TOKEN_B" }
Invoke-RestMethod -Headers $headers http://prediction.internal:8101/teams/TEAM_ID/status
```

Inspect container status and logs on each host:

```powershell
docker compose --env-file deploy/backend/.env -f deploy/backend/docker-compose.yml ps
docker compose --env-file deploy/chatbot/.env -f deploy/chatbot/docker-compose.yml logs -f chatbot-worker
docker compose --env-file deploy/prediction/.env -f deploy/prediction/docker-compose.yml logs -f prediction-api
```

## Runtime Flow

1. A basketball PDF is uploaded to the backend.
2. The backend stores it and sends an authenticated webhook to the chatbot.
3. A chatbot worker pulls the PDFs from the backend, rebuilds RAG data, and sends the
   same authenticated match payload to the prediction machine.
4. The prediction machine validates that every pull URL belongs to the configured
   backend host, downloads the PDFs, retrains the team model, and persists artifacts.
5. Prediction questions cause the chatbot to fetch prediction rows from the prediction
   API. Live injuries, schedules, fitness, and availability still come from the backend.
6. Users communicate only with the backend; the backend proxies chatbot requests and
   keeps the Python service ports out of the public application contract.

## Updates And Backups

Pull the same application version on all machines, then rerun the corresponding
`docker compose ... up -d --build` command. Back up these named volumes:

- Backend: `backend_postgres_data`, `backend_uploads`, `backend_data_protection_keys`.
- Chatbot: `chatbot_data`, `chatbot_redis_data`.
- Prediction: `prediction_data`.

Do not reuse the example passwords or tokens. Existing secrets that have ever been
committed to source control should be rotated before this deployment is exposed.
