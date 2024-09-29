FROM ubuntu:rolling

LABEL title="dev-container"
LABEL description="A development container running the latest rolling release of Ubuntu."
LABEL maintainer="Thaddeus Kuah <tk@tkkr.dev>"
LABEL source="https://github.com/thaddeuskkr/dev-container"

USER root

# System: Install unminimize
RUN apt-get update -y && apt-get install -y unminimize

# System: Unminimize
RUN yes | unminimize

# System: Install packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    sudo nano wget curl lsof htop git ack ca-certificates build-essential locales ufw rsyslog strace unzip zip gzip tar command-not-found screen bc fzf ffmpeg jq needrestart unattended-upgrades cloc \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev 

# System: Install the latest version of fastfetch
RUN wget https://github.com/fastfetch-cli/fastfetch/releases/download/$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')/fastfetch-linux-aarch64.deb && \
    dpkg -i fastfetch-linux-aarch64.deb && \
    rm -rf fastfetch-linux-aarch64.deb

# System: Install Code CLI (Visual Studio Code)
RUN curl -sL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64" -o /tmp/vscode-cli.tar.gz && \
    tar -xf /tmp/vscode-cli.tar.gz -C /usr/bin && \
    rm -rf /tmp/vscode-cli.tar.gz && \
    mkdir -p /data/cli && \
    mkdir -p /data/server && \
    mkdir -p /data/extensions

# System: Install Docker
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
RUN groupadd docker; exit 0
RUN usermod -aG docker ubuntu

# System: Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh

# System: Configure passwords and groups
RUN usermod -aG sudo ubuntu && \
    usermod -aG docker ubuntu && \
    echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' | EDITOR='tee -a' visudo

# System: Reconfigure locales
RUN locale-gen --purge en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# System: Add workspaces directory
RUN mkdir /workspaces

USER ubuntu

# Python: Install pyenv and latest Python 3
RUN curl https://pyenv.run | bash
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc && \
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.profile && \
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.profile
RUN export PYENV_ROOT="$HOME/.pyenv" && \
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH" && \
    eval "$(pyenv init -)" && \ 
    eval "$(pyenv virtualenv-init -)" && \
    pyenv install $(pyenv latest --known 3) && \
    pyenv global 3

USER ubuntu
# Node: Install latest nvm and latest LTS of Node
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')/install.sh | bash
RUN export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" && \
    nvm install --lts

# Rust: Install rustup
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Bun: Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Java / Kotlin: Install SDKMAN
RUN curl -s "https://get.sdkman.io" | bash

USER root

# Python: Install Poetry
RUN su - ubuntu -c 'curl -sSL https://install.python-poetry.org | python3 -'

COPY init /.init

CMD ["/.init"]
