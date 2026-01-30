# Twingate + Socat

Twingate headless client paired with Socat port forwarding feature

Inspired by [docker-twingate-headless](https://github.com/Docker-Collection/docker-twingate-headless)

### Components

Building blocks:
- Twingate headless client connecting to a private network like a "Service",
- Socat as a Port Forwarder making connections to a remote TCP listener possible,
- everything packed in a Docker container.

### Reasoning

Twingate's Docker networking stack can be shared with other containers (see [docs](https://www.twingate.com/docs/linux-headless#sharing-networking-stacks)):
```yaml
services:
  twingate-service:
    #...
    
  prometheus-node-exporter:
    #...
    network_mode: "service:twingate-service"
    ports:
      - "9100:9100" # WARNING: Not supported when 'network_mode' is used!
```
but `network_mode` makes usage of port mappings impossible. Thus, software like Prometheus Exporter turn harder to configure.

So, the idea is to create a Twingate Service Docker image with embedded Port Forwarder. The container will publish ports with forwarded remote data sources so consumers can easily get data, still staying "outside" the private network.

### Features

- Logs in unified format (all components publish logs in Twingate format)
- Optionally redirect Twingate log into Docker container's log (for connectivity issues debugging)
- Optionally to log list of available Twingate resources after successful connect

### Requirements

- [Twingate Service Account](https://www.twingate.com/docs/service-accounts-guide) with "Service Key" (json file).

### How to run

Create a Docker compose file (`compose.yml`) like this:
```yaml
services:
  twingate-service:
    image: twingate_service:latest
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - 'SERVICE_KEY={ "version": "1", "network": "<secret>.twingate.com", "service_account_id": "<secret uuid>", "private_key": "-----BEGIN PRIVATE KEY-----\n<whole bag of secrets>\n-----END PRIVATE KEY-----", "key_id": "<secret token>", "expires_at": "2027-01-01T00:00:00+00:00", "login_path": "/api/v4/headless/login" }'
      - PORT_MAPPINGS=80:sensors.raspberrypi.private:80;81:smarthome.raspberrypi.private:81
      - LOG_RESOURCES=1
      # Debugging Twingate connectivity issues:
      #- LOG_TWINGATE=1
      #- LOG_TWINGATE_TRUNCATE=1 # doesn't work without LOG_TWINGATE
    ports:
      - 8080:80
      - 8081:81
    restart: unless-stopped
```

> [!Note]  
> The "twingate_service" Docker image mentioned above is not published to any registry - you'll need to build it yourself by running the `Dockerfile_build.ps1` script.

Then run it:
```powershell
docker compose up
```

**OR**

Create an `.env` file in the **PARENT** directory, for example:
```ini
SERVICE_KEY={ "version": "1", "network": "<secret>.twingate.com", "service_account_id": "<secret uuid>", "private_key": "-----BEGIN PRIVATE KEY-----\n<whole bag of secrets>\n-----END PRIVATE KEY-----", "key_id": "<secret token>", "expires_at": "2027-01-01T00:00:00+00:00", "login_path": "/api/v4/headless/login" }'
PORT_MAPPINGS=80:sensors.raspberrypi.private:80;81:smarthome.raspberrypi.private:81
```
and use `compose.yml` from this project by running:
```powershell
./compose_run.ps1
```

### Environment variables

- `SERVICE_KEY` (string) - the Twingate's Service Key (the whole json as one line)
- `SERVICE_KEY_PATH` (string) - a path to a json file containing the Twingate's Service Key. This is an alternative way to specify credentials
- `PORT_MAPPINGS` (string) - ports to map in the format of "LOCAL_PORT:REMOTE_HOST:REMOTE_PORT;..." 
  - Example: `PORT_MAPPINGS="80:sensors.raspberrypi.private:80;81:smarthome.raspberrypi.private:81"`
- `LOG_TWINGATE` (bool or int) - redirect Twingate log to a Docker container's log
- `LOG_TWINGATE_TRUNCATE` (bool or int) - truncate Twingate log before starting (requires `LOG_TWINGATE` to be set as well)
- `LOG_RESOURCES` (bool or int) - log available Twingate resources after successfull connection

### Known issues

Won't fix:
- Though the projects aims to make logs of all its components look the same (see `log_transformer_*.sh` scripts), there are still some leftovers related to Twingate (some of its early log messages aren't well-formatted and thus left as is)
- For some reason `--disable-colors` parameter doesn't work and "Twingate has been started" message appears green in logs

### Possible future improvements

- [Userspace Networking](https://www.twingate.com/docs/linux-userspace-networking) - allows to run without "TUN" device and root user.

### Project status

![Portfolio](https://img.shields.io/badge/Status-Portfolio-lightgrey?style=flat-square)

This is a weekend project born from a fleeting idea I got while experimenting with Twingate Services.  
The project is in the "Portfolio" status - no feature PRs are expected.  
If you have ideas, feel free to open a discussion via "Issues".

### Software Bill of Materials

![Twingate](https://img.shields.io/badge/Twingate-Twingate-007ACC?style=flat-square&logo=twingate&logoColor=white)
![Socat](https://img.shields.io/badge/Socat-socat-4FC08D?style=flat-square&logo=socat&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-docker_compose-blue?style=flat-square&logo=docker&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)

- Twingate
- Socat
- Docker
- Bash

### Alternatives

- [Twingate Linux Headless Client (Docker Image)](https://github.com/Twingate-Solutions/twingate-custom-client-container) - this image provides a lightweight, self-contained way to run the Twingate Linux Client in headless mode using a Service Key.
- [Headless Client Gateway](https://github.com/Twingate-Solutions/general-scripts/tree/main/twingate-headless-client-gateway) - setup of a whole network Internet Gateway, utilizing the Twingate Headless Client.
