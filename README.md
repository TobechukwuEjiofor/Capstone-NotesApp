# Notes App — Three-Tier Azure Deployment

A small ticket/notes tracker deployed as a three-tier application on Azure, provisioned entirely through Terraform and deployed automatically via GitHub Actions.

## Architecture

```
Browser
   |
   v
[ Presentation tier ]  Nginx (frontend container) — public, port 80
   |  proxies /api/* internally
   v
[ Application tier ]   Node/Express API (backend container) — NOT exposed publicly
   |
   v
[ Data tier ]          Azure Database for PostgreSQL Flexible Server — managed, not a container
```

The frontend and backend run as separate Docker containers on a single Azure VM via Docker Compose. Only the frontend container's port (80) is exposed to the internet. The backend is reachable only from the frontend container, over the Compose-internal Docker network. The database is a managed Azure service, not a container, and its firewall only accepts connections from the VM's exact public IP — nothing else on the internet can reach it.

## Requirements met

- **Three-tier separation** — enforced at the network level, not just architecturally: the backend container has no published port, and the database firewall allows only the VM's IP.
- **Infrastructure as Code** — every Azure resource (resource group, VNet, subnet, NSG, public IP, VM, Postgres server, container registry, monitor agent, alert rule) is created by Terraform in `infrastructure/`. Nothing was created through the Azure Portal.
- **CI/CD** — a push to `main` triggers GitHub Actions to build both Docker images, push them to Azure Container Registry, and deploy them to the VM over SSH. No manual `docker` commands are run after the pipeline exists.
- **Docker end-to-end** — `backend/Dockerfile` and `frontend/Dockerfile` build each tier independently. `docker-compose.yml` (local dev, includes a Postgres container) and `docker-compose.prod.yml` (production, points at the managed Azure database instead) cover both environments.
- **No secrets in the repo** — all credentials (registry login, VM SSH key, database credentials, Azure service principal) live in GitHub Actions secrets. `terraform.tfvars` (containing the DB password) and Terraform's local state files are excluded via `.gitignore` and never committed.
- **Monitoring** — the Azure Monitor Linux Agent is installed on the VM via Terraform's VM extension resource, and a metric alert rule (`high-cpu-usage`, fires above 80% average CPU) is defined in `infrastructure/monitoring.tf`. Both are provisioned as code; a live CPU-spike test to visually confirm the alert firing was not performed for this submission, but the rule itself is active and correctly configured.

## Intentional deviations (documented, not oversights)

1. **No domain name or TLS.** The app is served over plain HTTP on the VM's static public IP (`http://<vm_public_ip>`), rather than a domain with HTTPS. This is an accepted deviation for groups without an existing domain, per the assignment. Because of this, the NSG only opens port 80 (and SSH) — port 443 is intentionally not opened.

2. **One non-Terraform step: Docker installation on first boot.** The VM's `custom_data` (cloud-init) script installs Docker and the Compose plugin the first time the VM boots. This can't be a separate Terraform resource because the container runtime has to exist before anything Docker-based could be automated on the VM — it's a one-time bootstrap, not an ongoing manual step, and it's defined entirely inside `infrastructure/vm.tf` (i.e., still version-controlled code, just not a discrete `azurerm_*` resource).

3. **A temporary CI-only firewall rule for deploys.** The NSG's SSH rule is permanently locked to the group's own IP (`allowed_ssh_ip` in `terraform.tfvars`), as required. Since GitHub Actions runs from Microsoft-hosted runners with their own changing IPs, the deploy job in `.github/workflows/deploy.yml` opens a narrow, single-IP SSH rule for its own run using a scoped Azure service principal, deploys, then removes that rule immediately afterward (`if: always()`, so it's removed even if the deploy fails). SSH access from arbitrary IPs is never left open.

## Running locally

```bash
docker compose up --build
```

Open `http://localhost:8080`. This uses `docker-compose.yml`, which includes a local Postgres container — no Azure account needed for local development.

## Environment variables

| Variable | Used by | Purpose |
|---|---|---|
| `DB_HOST` | backend | Postgres server hostname |
| `DB_PORT` | backend | Postgres port (5432) |
| `DB_USER` | backend | Postgres admin username |
| `DB_PASSWORD` | backend | Postgres admin password |
| `DB_NAME` | backend | Database name (`notesdb`) |
| `DB_SSL` | backend | Set to `true` in production (required by Azure Postgres) |
| `REGISTRY` | CI/CD | Azure Container Registry login server |
| `TAG` | CI/CD | Image tag, set to the git commit SHA |

## How the CI/CD pipeline works

On every push to `main`:

1. **`build-and-push`** builds the backend and frontend Docker images and pushes both to Azure Container Registry, tagged with the commit SHA.
2. **`deploy`** logs into Azure using a scoped service principal, temporarily opens SSH for its own IP (see deviation #3 above), copies the production compose file to the VM, SSHes in, writes a fresh `.env` file with the current image tag and database credentials (pulled from GitHub secrets, never stored in the repo), pulls the new images, and restarts the containers with `docker compose up -d`. The temporary SSH rule is removed as the final step regardless of outcome.

## Infrastructure

All Azure resources live in `infrastructure/`:

| File | Creates |
|---|---|
| `providers.tf` | Terraform provider configuration |
| `variables.tf` | Input variables (location, VM size, SSH key path, etc.) |
| `network.tf` | Resource group, VNet, subnet, static public IP, NSG |
| `vm.tf` | Network interface, NSG association, the VM itself, Docker boot script |
| `database.tf` | Azure Database for PostgreSQL Flexible Server, locked to the VM's IP |
| `registry.tf` | Azure Container Registry |
| `monitoring.tf` | Azure Monitor agent extension, action group, CPU alert rule |
| `outputs.tf` | Prints the VM IP, database hostname, and registry details after apply |

`terraform.tfvars` (real IP, password, email) is intentionally excluded from git via `.gitignore`, as are `.terraform/` and the `terraform.tfstate*` files (the state file stores resource details, including the database password, in plain text).