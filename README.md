# Development Container

[![Workflow Status](https://github.com/thaddeuskkr/dev-container/actions/workflows/build.yml/badge.svg)](https://github.com/thaddeuskkr/dev-container/actions/workflows/build.yml)

An Ubuntu container running an SSH server, along with a Visual Studio Code Tunnel for all your remote development needs. Comes with multiple [preinstalled tools](#preinstalled-tools) to make your life easier.

## Features

- Passthrough of SSH and GPG keys, along with Git configurations
- Latest Ubuntu rolling release (unminimized)
- Built for multiple architectures
- Daily scheduled builds
- Slightly configurable

## Preinstalled Tools

- [Visual Studio Code CLI](https://code.visualstudio.com/docs/editor/command-line)
- [Docker Engine](https://docs.docker.com/engine/)
- [GitHub CLI](https://cli.github.com/)
- [Swift](https://www.swift.org/) (latest)
- [Bun](https://bun.sh/)
- [Deno](https://deno.com)
- [Node Version Manager (nvm)](https://github.com/nvm-sh/nvm) / [Node.js](https://nodejs.org/)
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
