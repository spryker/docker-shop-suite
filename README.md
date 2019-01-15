## Docker container solution for Spryker deploy
There is Dockerfile for build Yves and Zed docker containers and additional services container configurations for run Spyrker shop suite.
## Quick installation
# Create a new SSH key pair:
Linux/MacOS:

```
ssh-keygen -b 2048 -m PEM -t rsa -f jenkins/id_rsa -q -N ""
```

Windows: 

```
Git Bash:
1. Download and install Git for Windows: https://git-scm.com/download/win
  a. Select to Use Git from the Windows Command Prompt.
  b. Select to Use OpenSSL library.
  c. Accept the default extra option configuration by clicking Install.
2. Launching GitBash
  a. Chenge directory to the docker-shop-suite
  b. ssh-keygen.exe  -b 2048 -m PEM -t rsa -f jenkins/id_rsa -q -N ""
```

# Run buid and start docker-compose

```
docker-compose build
docker-compose up -d
```

# NewRelic usage
If you plan to use the [NewRelic](https://newrelic.com/) for monitoring please define the `NEWRELIC_KEY` as the environment variable of the application container.

# Spryker cronjobs
The [Spryker cronjobs sheduling](https://academy.spryker.com/developing_with_spryker/resources_and_developer_tools/cronjob_scheduling.html) should be correctly setup for shop suite publish and sync working.
The jenkins container setup for this needs, but now the console command:
```
vendor/bin/console setup:jenkins:generate
```
works correctly if Jenkins is installed on the same server as Zed. But in our case we have Jenkins in the separate Docker container, out of Zed. So you need to add [jobs](https://github.com/spryker-shop/suite/blob/master/config/Zed/cronjobs/jobs.php) to your Jenkins container:
```
http://os.de.demoshop.local:9090/
```
and this jobs should run remotely on Zed server, for example with the [Jenkins SSH plugin](https://wiki.jenkins.io/display/JENKINS/SSH+plugin).

## Documentation
[Spryker Documentation](https://academy.spryker.com)
