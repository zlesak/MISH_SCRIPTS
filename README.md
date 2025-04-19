# MISH_SCRIPTS
Scripts for automatic docker startup for full stack of MISH app

Max JDK: JDK21 - due to compatibility issues on BE side - 20.04.2025

For this to work, you need to establish a file structure on your side (folder names must match!).  <br />
The file structure needs to be as follows: <br />
MISH/<br />
&emsp;├── backend/ (https://github.com/Foglas/mishprototype) <br />
&emsp;├── frontend/ (https://github.com/zlesak/threejsproofofconcept) <br />
&emsp;└── MISH_SCRIPTS (https://github.com/zlesak/MISH_SCRIPTS) <br />

This repository has file structure as follows: (THIS IS ALREADY DONE BY THIS REPOSITORY)<br />
MISH_scripts/<br />
&emsp;├── backend/<br />
&emsp;├── frontend/<br />
&emsp;└── start.sh<br />

When the file structure is as shown in the first figure, simply start the start.sh from the cmd within the MISH_SCRIPT folder.<br /><br />
## Script has this main parts:<br />
**├── NETWORK** <br />
**├── MONGO** <br />
**├── BACKEND** <br />
**├── FRONTEND** <br />
**├── FINAL** <br /><br />
Every part is responsible for its scope, given by its name. <br />
**__In case of edit, made changes in this script also needs to be written here in readme.md for documentation!__**
