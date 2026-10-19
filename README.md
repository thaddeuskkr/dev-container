# Development Container

[![Workflow Status](https://github.com/thaddeuskkr/dev-container/actions/workflows/build.yml/badge.svg)](https://github.com/thaddeuskkr/dev-container/actions/workflows/build.yml)

An Ubuntu container running an SSH server, along with a Visual Studio Code Tunnel for all your remote development needs. Comes with multiple [preinstalled tools](#preinstalled-tools) to make your life easier.

## Features

- Passthrough of SSH and GPG keys, along with Git configurations
- Latest Ubuntu LTS release (unminimized)
- Built for multiple architectures
- Daily scheduled builds
- Slightly configurable

## Preinstalled Tools

- [Visual Studio Code CLI](https://code.visualstudio.com/docs/editor/command-line)
- [Docker Engine](https://docs.docker.com/engine/)
- [GitHub CLI](https://cli.github.com/)
- [Bun](https://bun.sh/)
- [Deno](https://deno.com)
- [Node Version Manager (nvm)](https://github.com/nvm-sh/nvm)
- [`uv`](https://github.com/astral-sh/uv)
- [`fastfetch`](https://github.com/fastfetch-cli/fastfetch)
- [`cloc`](https://github.com/AlDanial/cloc)

## Setup

### Prerequisites

- Docker
- Docker Compose (optional, but recommended)

### Docker Compose - recommended

1. Clone this repository and enter its directory

```sh
git clone https://github.com/thaddeuskkr/dev-container.git && cd dev-container
```

1. Start a container using the included `compose.yml` file

```sh
docker compose up -d
```

### Docker - not recommended

```sh
docker run -d \
--name dev-container \
--hostname dev \
--restart unless-stopped \
-e PASSWORD="YOUR_PASSWORD" \
-e DOCKER_GROUP="$(getent group docker | cut -d: -f3)" \
-e KEYS="$(cat ~/.ssh/authorized_keys)" \
-e SSH_PASSWORD_AUTH="false" \
-e SSH_ROOT_LOGIN="false" \
-p 2222:22 \
-v ~/.gnupg:/volumes/.gnupg:ro \
-v ~/.gitconfig:/volumes/.gitconfig:ro \
-v ./workspaces:/workspaces \
-v ./data/:/data \
-v home:/home/ubuntu \
-v /var/run/docker.sock:/var/run/docker.sock \
ghcr.io/thaddeuskkr/devc
```

The Docker `run` command above tries to replicate the behaviour from the Docker Compose file - there might be some discrepancies.

## Updating Ubuntu without losing development data

The image uses `ubuntu:latest`, which follows the [latest Ubuntu LTS release](https://hub.docker.com/_/ubuntu). Building it with a freshly pulled base image picks up the LTS release currently referenced by that tag. To follow every Ubuntu release, including interim releases, use `ubuntu:rolling` instead. The published image is built daily; once a build with the newer base succeeds, update your deployment from the same Compose directory and with the same Compose project name:

```sh
docker compose pull dev_container
docker compose up -d dev_container
```

Compose replaces the container when its image changes and reuses its existing mounts. The included configuration already preserves:

| Container path | Storage | Contents |
| --- | --- | --- |
| `/home/ubuntu` | Named volume `home` | User settings, SSH keys, nvm versions, and tools installed in the home directory |
| `/workspaces` | Host directory `./workspaces` | Projects and working files |
| `/data` | Host directory `./data` | VS Code tunnel state, server data, and extensions |

Back up these locations before a release change. Keep the existing Compose project name so Compose selects the same home volume, and keep the bind mounts pointed at the same host directories. Do not use `docker compose down -v` when updating: it deletes the Compose-managed home volume.

Files elsewhere in the container, including packages installed manually with APT, changes under `/etc`, and files under `/root`, are not preserved when the container is replaced. Add system packages and configuration to the Dockerfile or entrypoint so they can be recreated. Upgrade by rebuilding/replacing the image rather than running an Ubuntu release upgrade inside the running container. Home-installed tools with native binaries may need rebuilding or reinstalling for the newer Ubuntu release.

An existing home volume also hides the home directory supplied by a newer image. Image updates therefore do not refresh tools already stored there, and removing the automatic Node.js installation from the Dockerfile does not uninstall versions already in `~/.nvm`. Manage those versions with nvm inside the container.

Docker documents these persistence and mount behaviours in its [volume guide](https://docs.docker.com/engine/storage/volumes/).
