## IMPORTANT!! You can use the temporary jenkins/id_rsa key only for local builds.

### You can create a new ssh key pair following the instruction:

#### Linux/MacOS:
```
1. Chenge directory to the docker-shop-suite
2. ssh-keygen -b 2048 -m PEM -t rsa -f jenkins/id_rsa -q -N ""
```
#### Windows:
```
Git Bash:
1. Download and install Git Windows: https://git-scm.com/download/win
   a. Select to Use Git from the Windows Command Prompt.
   b. Select to Use OpenSSL library.
   c. Accept extra option configuration by clicking Install.
2. Launching GitBash
   a. Chenge directory to the docker-shop-suite
   b. ssh-keygen.exe -b 2048 -m PEM -t rsa -f jenkins/id_rsa -q -N ""
```
