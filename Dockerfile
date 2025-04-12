FROM ubuntu:rolling

USER root

# Unminimize Ubuntu
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y unminimize 
RUN yes | unminimize

# Install packages and dependencies
RUN apt-get install -y \
    sudo nano wget curl lsof htop git ack locales unzip zip gzip tar bc fzf jq openssh-server tzdata \
    ca-certificates build-essential command-not-found screen cloc needrestart unattended-upgrades \
    zlib1g-dev pkg-config libz3-dev libxml2-dev libstdc++-13-dev libsqlite3-0 libpython3-dev libncurses-dev \
    libgcc-13-dev libedit2 libcurl4-openssl-dev libc6-dev gnupg2 binutils

# Define target platform
ARG TARGETPLATFORM

# Install Visual Studio Code CLI
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    curl -sL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64" -o /tmp/vscode-cli.tar.gz; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    curl -sL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64" -o /tmp/vscode-cli.tar.gz; \
    fi && \
    tar -xf /tmp/vscode-cli.tar.gz -C /usr/bin && \
    rm -rf /tmp/vscode-cli.tar.gz && \
    mkdir -p /data/cli && \
    mkdir -p /data/server && \
    mkdir -p /data/extensions

# Install fastfetch
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    curl -sL https://github.com/fastfetch-cli/fastfetch/releases/download/$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')/fastfetch-linux-aarch64.deb -o /tmp/fastfetch.deb; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    curl -sL https://github.com/fastfetch-cli/fastfetch/releases/download/$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')/fastfetch-linux-amd64.deb -o /tmp/fastfetch.deb; \
    fi && \
    dpkg -i /tmp/fastfetch.deb && \
    rm -rf /tmp/fastfetch.deb

# Install Docker Engine and GitHub CLI
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
RUN apt-get update && apt-get install -y gh docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure permissions
RUN usermod -aG sudo ubuntu && \
    echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' | EDITOR='tee -a' visudo

# Configure locales
RUN locale-gen --purge en_US.UTF-8 && \
update-locale LANG=en_US.UTF-8

# Add workspaces directory
RUN mkdir /workspaces && \
    chown -R ubuntu:ubuntu /workspaces

USER ubuntu

# Install Swift
RUN SWIFT_VERSION="$(curl -s https://www.swift.org/api/v1/install/releases.json | jq -r '.[-1].name')" && \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    curl -sL https://download.swift.org/swift-$SWIFT_VERSION-release/ubuntu2404-aarch64/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-ubuntu24.04-aarch64.tar.gz -o /tmp/swift.tar.gz && \
    tar -xzf /tmp/swift.tar.gz -C /tmp && \
    mkdir -p /home/ubuntu/.local && \
    mv /tmp/swift-$SWIFT_VERSION-RELEASE-ubuntu24.04-aarch64 ~/.local/swift; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    curl -sL https://download.swift.org/swift-$SWIFT_VERSION-release/ubuntu2404/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-ubuntu24.04.tar.gz -o /tmp/swift.tar.gz && \
    tar -xzf /tmp/swift.tar.gz -C /tmp && \
    mkdir -p /home/ubuntu/.local && \
    mv /tmp/swift-$SWIFT_VERSION-RELEASE-ubuntu24.04 /home/ubuntu/.local/swift; \
    fi && \
    rm -rf /tmp/swift.tar.gz && \
    echo 'export PATH=/home/ubuntu/.local/swift/usr/bin:"${PATH}"' >> ~/.bashrc

# Install nvm and the latest node LTS
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')/install.sh | bash
RUN export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" && \
    nvm install --lts

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Install Deno
RUN curl -fsSL https://deno.land/install.sh | sh -s -- -y

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

USER root

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
