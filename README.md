# MISH_SCRIPTS
Scripts for automatic Docker startup/deploy of the full MISH stack.

This repository has this structure:<br />
MISH_SCRIPTS/<br />
&emsp;├── backend/<br />
&emsp;│&emsp;├── Dockerfile<br />
&emsp;│&emsp;└── build_backend.sh<br />
&emsp;├── frontend/<br />
&emsp;│&emsp;├── Dockerfile<br />
&emsp;│&emsp;└── build_frontend.sh<br />
&emsp;├── nginx/<br />
&emsp;│&emsp;├── nginx.conf<br />
&emsp;│&emsp;└── ssl/<br />
&emsp;├── common.sh<br />
&emsp;├── lib.sh<br />
&emsp;├── start_all.sh<br />
&emsp;├── stop.sh<br />
&emsp;├── deploy_mongo.sh<br />
&emsp;├── deploy_redis.sh<br />
&emsp;├── deploy_security.sh<br />
&emsp;├── deploy_backend.sh<br />
&emsp;├── deploy_frontend.sh<br />
&emsp;├── deploy_gateway.sh<br />
&emsp;├── sync_backend_repo.sh<br />
&emsp;└── sync_frontend_repo.sh<br />

Max JDK: JDK 21 (BE compatibility).

For scripts to work properly, the following repositories are expected (and can be auto-cloned by scripts): <br />
MISH/<br />
&emsp;├── backend/repo (https://github.com/Foglas/mishprototype) <br />
&emsp;├── frontend/repo (https://github.com/zlesak/threejsproofofconcept) <br />
&emsp;└── MISH_SCRIPTS (this repo) <br />

(**Scripts automatically fetch FE/BE repositories into their folders if missing.**)<br />
(**When cloning is needed, you can specify `--branch-backend` and/or `--branch-frontend`.**)<br />

To run in production mode (`.env`), use: <br />
`./start_all.sh` <br />
<br />
To run with development variables (`.dev.env`), use: <br />
`./start_all.sh --dev` <br />
Note: `--dev` only switches env variables; gateway still uses unified `nginx/nginx.conf` (HTTPS). <br />
<br />
If specific branches are required (production mode): <br />
`./start_all.sh --branch-backend=<branch_name> --branch-frontend=<branch_name>` <br />
Or in development mode with specific branches: <br />
`./start_all.sh --dev --branch-backend=<branch_name> --branch-frontend=<branch_name>` <br />

Without frontend container (for manual FE hot reload): <br />
`./start_all.sh --dev --no-frontend` <br />
Note: when `--no-frontend` is used, nginx cannot proxy FE from container; run FE manually (for example on `http://localhost:8081`). <br />

Optional repo-only sync helpers: <br />
`./sync_backend_repo.sh [--dev] [--branch-backend=<branch_name>]` <br />
`./sync_frontend_repo.sh [--dev] [--branch-frontend=<branch_name>]` <br />

Important Keycloak URL setup: <br />
- `KEYCLOAK_URL` must stay internal (for container-to-container calls), e.g. `http://mock-oidc:8080/auth` <br />
- `KEYCLOAK_EXTERNAL_URL` must be public gateway URL (for browser redirects), e.g. `http://mish/auth` <br />

### Script `start_all.sh` has these main parts:<br />
**├── MONGO DEPLOY** <br />
**├── REDIS DEPLOY** <br />
**├── SECURITY DEPLOY** <br />
**├── BACKEND DEPLOY** <br />
**├── FRONTEND DEPLOY** <br />
**└── GATEWAY DEPLOY** <br /><br />

If you want to stop the whole stack, use: <br />
`./stop.sh`  <br />
If you want to stop and remove containers + volumes created by this stack (Redis/Mongo/Security compose stacks), use: <br />
`./stop.sh --down`  <br />

**__When scripts change, update this `README.md` accordingly.__**
~~~~
last change: 22.03.2026 by j.zlesak - update environment configuration, enhance nginx setup, ssl addition
~~~~
