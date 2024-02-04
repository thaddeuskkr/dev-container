FROM ubuntu:rolling

USER root

# System: Unminimize
RUN yes | unminimize

# System: Install essentials
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y \
    openssh-server \
    sudo nano wget curl git ca-certificates \
    neofetch build-essential \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# System: Install Docker
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# System: Configure passwords and groups
RUN usermod -aG sudo ubuntu && \
    usermod -aG docker ubuntu && \
    echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' | EDITOR='tee -a' visudo

# System: Add workspaces directory and set owner
RUN mkdir /workspaces

USER ubuntu

# Python: Install pyenv
RUN curl https://pyenv.run | bash
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.profile

# Node: Install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Rust: Install rustup
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

USER root

COPY init /.init

EXPOSE 22

CMD ["/.init"]
