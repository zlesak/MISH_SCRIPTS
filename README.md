# MISH_SCRIPTS
Scripts for automatic docker startup for full stack of MISH app

Max JDK: JDK21 - due to compatibility issues on BE side - 20.04.2025

For this to work, you need to establish a file structure on your side (**folder names must match!**).  <br />
The file structure needs to be as follows: <br />
MISH/<br />
&emsp;├── backend/ (https://github.com/Foglas/mishprototype) <br />
&emsp;├── frontend/ (https://github.com/zlesak/threejsproofofconcept) <br />
&emsp;└── MISH_SCRIPTS (https://github.com/zlesak/MISH_SCRIPTS) <br />

This repository has file structure as follows: (THIS IS ALREADY DONE BY THIS REPOSITORY)<br />
MISH_scripts/<br />
&emsp;├── backend/<br />
&emsp;├── frontend/<br />
&emsp;├── start.sh<br />
&emsp;├── start_dev.sh<br />
&emsp;└── stop.sh<br />

When the file structure is as shown in the first figure, simply start the start.sh from the cmd within the MISH_SCRIPT folder.  
If you want to run in development mode, use start_dev.sh instead. <br />

### Script start.sh has this main parts:<br />
**├── NETWORK** <br />
**├── MONGO** <br />
**├── SECURITY** <br />
**├── BACKEND** <br />
**├── FRONTEND** <br />
**├── FINAL** <br /><br />
Every part is responsible for its scope, given by its name. <br />

When in development mode, use start_dev.sh instead of start.sh. The main difference is that the script does not start the frontend part, the frontend then has to be started manually in hotswap agent mode on port 8081. <br />

Note: as of version since 29.12.2025 for development mode, there is a need to add a DNS resolve to the /etc/hosts file (all platforms) as the security is provided through Keycloak login page as of now. In example:<br />
`
echo "127.0.0.1 mock-oidc" >> /etc/hosts
` <br />
  
If you want to stop the whole stack, use stop.sh script. <br />
<br />
**__In case of edit, made changes in this script also needs to be written here in readme.md for documentation!__**
~~~~
last change: 29.12.2025 by j.zlesak - security integration
