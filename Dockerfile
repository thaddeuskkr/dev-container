# syntax=docker/dockerfile:1
FROM ubuntu:latest AS base

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Restore standard Ubuntu documentation and utilities for both variants.
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y unminimize && yes | unminimize

# SSH and general tools are shared; keep VS Code and runtime managers out of base.
RUN apt-get install -y --no-install-recommends \
    bash-completion build-essential ca-certificates curl fd-find file fzf git \
    gnupg2 gzip htop iproute2 jq less locales lsof nano openssh-client openssh-server openssl \
    pkg-config procps python3 python3-pip python3-venv pipx ripgrep rsync \
    shellcheck sudo tar tmux tree tzdata unzip wget xz-utils zip && \
    locale-gen --purge en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    usermod -aG sudo ubuntu && \
    echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    mkdir -p /workspaces && chown ubuntu:ubuntu /workspaces && \
    ln -s /usr/bin/fdfind /usr/local/bin/fd && \
    rm -f /etc/ssh/ssh_host_* && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
EXPOSE 22

FROM base AS sandbox

# Small, distro-maintained CLI/development and security inspection toolkit.
# All packages are available for both amd64 and arm64; no Kali repositories.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bind9-dnsutils binutils gobuster iputils-ping netcat-openbsd nmap \
    socat tcpdump traceroute whois xxd yara && \
    rm -rf /var/lib/apt/lists/*

USER ubuntu
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Load nvm in interactive and noninteractive Bash; expose Node to direct commands.
ENV NVM_DIR=/home/ubuntu/.nvm \
    BASH_ENV=/home/ubuntu/.bash_env \
    NVM_SYMLINK_CURRENT=true
RUN touch "$BASH_ENV" && \
    sed -i '1i . /home/ubuntu/.bash_env' /home/ubuntu/.bashrc && \
    NVM_VERSION=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -er '.tag_name') && \
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | PROFILE="$BASH_ENV" bash
RUN . "$BASH_ENV" && \
    nvm install --lts && nvm alias default 'lts/*' && nvm use default && \
    nvm cache clear

ENV PATH="/home/ubuntu/.local/bin:${NVM_DIR}/current/bin:${PATH}"
RUN curl -fsSL https://astral.sh/uv/install.sh | \
    env UV_INSTALL_DIR=/home/ubuntu/.local/bin UV_NO_MODIFY_PATH=1 sh

USER root
COPY --chmod=0755 sandbox-entrypoint.sh /sandbox-entrypoint.sh
WORKDIR /workspaces
# SSH runs in the foreground; alternate commands run as ubuntu.
ENTRYPOINT ["/sandbox-entrypoint.sh"]
CMD ["sshd"]

# Keep dev last so a plain docker build retains the existing dev default.
FROM base AS dev

# Retain the existing remote-development services.
RUN apt-get update && apt-get install -y \
    ack bc command-not-found screen cloc needrestart neovim \
    unattended-upgrades binutils-gold libc6-dev libcurl4-openssl-dev libedit2 \
    libncurses-dev libpython3-dev libsqlite3-0 libxml2-dev libz3-dev zlib1g-dev

# Define target platform
ARG TARGETPLATFORM

# Install Visual Studio Code CLI
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-arm64" -o /tmp/vscode-cli.tar.gz; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64" -o /tmp/vscode-cli.tar.gz; \
    fi && \
    tar -xf /tmp/vscode-cli.tar.gz -C /usr/bin && \
    rm -rf /tmp/vscode-cli.tar.gz && \
    mkdir -p /data/cli && \
    mkdir -p /data/server && \
    mkdir -p /data/extensions

# Install fastfetch
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/download/$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')/fastfetch-linux-aarch64.deb" -o /tmp/fastfetch.deb; \
    dpkg -i /tmp/fastfetch.deb && rm -rf /tmp/fastfetch.deb; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
    curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/download/$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.tag_name')/fastfetch-linux-amd64.deb" -o /tmp/fastfetch.deb; \
    dpkg -i /tmp/fastfetch.deb && rm -rf /tmp/fastfetch.deb; \
    fi

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

# Install the newest stable Swift release supporting this Ubuntu and CPU.
# Keep the toolchain outside /home/ubuntu so existing home volumes cannot hide it.
# Optionally pin a release with --build-arg SWIFT_VERSION=6.4.1.
ARG SWIFT_VERSION
ENV PATH="/opt/swift/usr/bin:${PATH}"
RUN set -eu; \
    . /etc/os-release; \
    case "$(dpkg --print-architecture)" in \
        amd64) swift_arch=x86_64; swift_suffix= ;; \
        arm64) swift_arch=aarch64; swift_suffix=-aarch64 ;; \
        *) echo "Unsupported Swift architecture" >&2; exit 1 ;; \
    esac; \
    swift_tmp=$(mktemp -d); \
    trap 'rm -rf "$swift_tmp"' EXIT; \
    curl -fsSL --compressed https://www.swift.org/api/v1/install/releases.json -o "$swift_tmp/releases.json"; \
    swift_tag=$(jq -er --arg platform "Ubuntu ${VERSION_ID}" --arg arch "$swift_arch" --arg version "${SWIFT_VERSION:-}" \
        'map(select(any(.platforms[]?; .name == $platform and (.archs | index($arch))))) | \
        (if $version == "" then max_by(.date) else map(select(.name == $version)) | last end) | \
        .tag // error("No stable Swift release supports the requested Ubuntu, architecture, and version")' "$swift_tmp/releases.json"); \
    swift_branch=$(printf '%s' "$swift_tag" | tr '[:upper:]' '[:lower:]'); \
    swift_platform="ubuntu${VERSION_ID}"; \
    swift_directory="ubuntu$(printf '%s' "$VERSION_ID" | tr -d .)${swift_suffix}"; \
    swift_url="https://download.swift.org/${swift_branch}/${swift_directory}/${swift_tag}/${swift_tag}-${swift_platform}${swift_suffix}.tar.gz"; \
    curl -fSL --retry 3 "$swift_url" -o "$swift_tmp/swift.tar.gz"; \
    curl -fsSL --retry 3 "${swift_url}.sig" -o "$swift_tmp/swift.tar.gz.sig"; \
    curl -fsSL --compressed https://swift.org/keys/all-keys.asc -o "$swift_tmp/keys.asc"; \
    export GNUPGHOME="$swift_tmp/gnupg"; \
    mkdir -m 0700 "$GNUPGHOME"; \
    gpg --batch --import "$swift_tmp/keys.asc"; \
    gpg --batch --verify "$swift_tmp/swift.tar.gz.sig" "$swift_tmp/swift.tar.gz"; \
    mkdir -p /opt/swift; \
    tar -xzf "$swift_tmp/swift.tar.gz" -C /opt/swift --strip-components=1 --no-same-owner; \
    chmod -R a+rX /opt/swift; \
    for swift_tool in /opt/swift/usr/bin/swift* /opt/swift/usr/bin/sourcekit-lsp /opt/swift/usr/bin/lldb; do \
        if [ -x "$swift_tool" ]; then ln -s "$swift_tool" "/usr/local/bin/$(basename "$swift_tool")"; fi; \
    done

USER ubuntu

# Use a standard SSH/sudo PATH to verify the global command links as ubuntu.
# Fail the build if Swift cannot compile, link Foundation, and execute.
RUN set -eu; \
    export PATH=/usr/local/bin:/usr/bin:/bin; \
    swift --version; \
    swift_test=$(mktemp -d); \
    trap 'rm -rf "$swift_test"' EXIT; \
    printf '%s\n' 'import Foundation' 'print(Date(timeIntervalSince1970: 0).timeIntervalSince1970)' > "$swift_test/main.swift"; \
    swiftc "$swift_test/main.swift" -o "$swift_test/hello"; \
    test "$("$swift_test/hello")" = 0.0

# Install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')/install.sh | bash

# Install pnpm
RUN curl -fsSL https://get.pnpm.io/install.sh | SHELL=/bin/bash sh -

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Install Deno
RUN curl -fsSL https://deno.land/install.sh | sh -s -- -y

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

USER root

# Host keys must be unique to each dev container, not baked into the image.
RUN rm -f /etc/ssh/ssh_host_* && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
