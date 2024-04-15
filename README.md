# Development Container
A development container running a Visual Studio Code Tunnel server for all your remote development needs.

## Features
- Preinstalled tools (pyenv, poetry, nvm, rustup, sdkman, docker)
- Passthrough of GPG keys, along with Git configurations
- Latest Ubuntu rolling release (unminimized)

## Setup
### Prerequisites:
- Docker
- Docker Compose (optional, but recommended)
### Docker Compose - recommended
1. Clone this repository and enter its directory
```
git clone https://github.com/thaddeuskkr/dev-container.git && cd dev-container
```
2. Start a container using the included `compose.yml` file
```
docker compose up -d
```
### Docker - not recommended
```
docker run -d \
--name dev-container \
--hostname dev \
--restart unless-stopped \
-e PASSWORD="YOUR_PASSWORD" \
-v ~/.gnupg:/volumes/.gnupg:ro \
-v ~/.gitconfig:/volumes/.gitconfig:ro \
-v ./workspaces:/workspaces \
-v ./data/:/data \
-v home:/home/ubuntu \
ghcr.io/thaddeuskkr/dev-container:main
```
The Docker `run` command above tries to replicate the behaviour from the Docker Compose file - there might be some discrepancies.
