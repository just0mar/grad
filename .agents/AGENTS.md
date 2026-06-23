*   **Remote Deployment Access:** Do not forget how to connect to the deployed code. You have full access to SSH into the remote GCP instances (`equipex-core` at `34.154.188.123` and `equipex-ai` at `34.154.162.32`) using the local SSH identity (`$HOME\.ssh\id_ed25519_deploy`). The deployment is done by running `tar -czf deploy_backend.tar.gz SportsPlatform.Auth`, uploading it via `scp`, and running `docker-compose up --build -d`.

### GCP Access Credentials
- **Username:** equipex`n- **Private Key:** ~/.ssh/id_ed25519_deploy`n- **equipex-core IP:** 34.154.188.123 (SSH Command: ssh -i ~/.ssh/id_ed25519_deploy equipex@34.154.188.123)
- **equipex-ai IP:** 34.154.162.32 (SSH Command: ssh -i ~/.ssh/id_ed25519_deploy equipex@34.154.162.32)
