# Development Container

## Features
- Preinstalled tools (pyenv, poetry, nvm, rustup, docker)
- SSH server for remote development using Visual Studio Code or JetBrains IDEs
- Passthrough of GPG and SSH keys, along with Git configurations
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
-p 2222:22 \
-v ~/.gnupg:/volumes/.gnupg:ro \
-v ~/.gitconfig:/volumes/.gitconfig:ro \
-v ./workspaces:/workspaces \
-v home:/home/ubuntu \
ghcr.io/thaddeuskkr/dev-container:main
```
