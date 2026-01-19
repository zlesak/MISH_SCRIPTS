# MISH_SCRIPTS
Scripts for automatic docker startup for full stack of MISH app

Tato repositář má následující strukturu souborů:<br />
MISH_SCRIPTS/<br />
&emsp;├── backend/<br />
&emsp;│&emsp;├── Dockerfile<br />
&emsp;│&emsp;└── build_backend.sh<br />
&emsp;├── frontend/<br />
&emsp;│&emsp;├── Dockerfile<br />
&emsp;│&emsp;└── build_frontend.sh<br />
&emsp;├── nginx/<br />
&emsp;│&emsp;└── nginx.conf<br />
&emsp;├── common.sh<br />
&emsp;├── start_all.sh<br />
&emsp;└── stop.sh<br />

Max JDK: JDK21 - due to compatibility issues on BE side - 20.04.2025

For scripts to work properly, there needs to be file structure present as follows: <br />
MISH/<br />
&emsp;├── backend/ (https://github.com/Foglas/mishprototype) <br />
&emsp;├── frontend/ (https://github.com/zlesak/threejsproofofconcept) <br />
&emsp;└── MISH_SCRIPTS (https://github.com/zlesak/MISH_SCRIPTS) <br />

(**script fetches FE or BE to its proper folder automatically on their default branch if folders not present**): <br />
(**When folder are not present, you can specify arguments --branch-backend or --branch-frontend for the wanted branch from which to clone from**): <br />

To run in production mode on master branches (environmental values for production needs to be added manually into .env!), use: <br />
`./start_all.sh` <br />
<br />
Or if you want to run in with .dev.env variables, use: <br />
`./start_all.sh --dev` <br />
<br />
If specific branches are wanted for production, use: <br />
`./start_all.sh --branch-backend=<branch_name> --branch-frontend=<branch_name>` <br />
OR to run in development mode with .dev.env variables, use: <br />
`./start_all.sh --dev --branch-backend=<branch_name> --branch-frontend=<branch_name>` <br />
This will start the whole stack with specified branches **if folders are not already present!**. <br />
<br />
Without fronted started automatically, to be started manually in hotswap mode for dev purposes on port 8081, use: <br />
`./start_all.sh --dev --no-frontend` <br />
Note: when --no-frontend is used and FE run manually, the nginx won't be able to forward to the FE as not run in container, use static access to FE via http://localhost:8081 <br />
Note 2: When running with .dev.env, add mish to /etc/hosts to resolve to the nginx on port 80, e.g.: <br />
`
echo "127.0.0.1 mish" >> /etc/hosts
` <br />

### Script start_all.sh has these main parts:<br />
**├── INITIAL OPERATIONS** <br />
**├── NETWORK** <br />
**├── MONGO** <br />
**├── SECURITY** <br />
**├── BACKEND** <br />
**├── FRONTEND** <br />
**├── GATEWAY** <br />
**└── FINAL** <br /><br />
Every part is responsible for its scope, given by its name. <br />

Note: as of version since 29.12.2025 for development mode, there is a need to add a DNS resolve to the /etc/hosts file (all platforms) as the security is provided through Keycloak login page as of now. In example:<br />
`
echo "127.0.0.1 mock-oidc" >> /etc/hosts
` <br />
  
If you want to stop the whole stack, use stop.sh script: <br />
`./stop.sh`  <br />
If you want to stop and remove all containers, and volumes created by the start_all.sh script, use: <br />
`./stop.sh --down`  <br />
<br />
**__In case of edit, made changes in this script also needs to be written here in readme.md for documentation!__**
~~~~
last change: 19.01.2026 by j.zlesak - start all script with params instead of separate dev script, README updated
                                    - nginx added for proper serving on one endpoint, use mish with .dev.env, see updated instructions
~~~~
