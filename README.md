# VM images

[![Workflow Status](https://github.com/thaddeuskkr/vm/actions/workflows/build.yml/badge.svg)](https://github.com/thaddeuskkr/vm/actions/workflows/build.yml)

Two Ubuntu images, each built for **linux/amd64** and **linux/arm64**:

| Variant | Docker Hub | GHCR | Purpose |
| --- | --- | --- | --- |
| Dev | `thadkkr/vm:dev` | `ghcr.io/thaddeuskkr/vm:dev` | Persistent remote development with SSH and a VS Code tunnel |
| Sandbox | `thadkkr/vm:sandbox` | `ghcr.io/thaddeuskkr/vm:sandbox` | Disposable CLI, development, and security experiments |

Every published build also gets `dev-YYYYMMDD` and `sandbox-YYYYMMDD` tags, using one UTC date for the entire workflow. For example, `thadkkr/vm:sandbox-20261020`. Each enabled registry also receives `dev-sha-<full-commit>` and `sandbox-sha-<full-commit>` tags. A date tag selects the last successful build that day; use an image digest to pin exact contents. There is no ambiguous `latest` tag.

Both variants use an unminimized `ubuntu:latest` base, following the official image's latest LTS release. Daily builds refresh the base image, APT packages, and upstream installers.

## Disposable sandbox

```sh
docker compose -f compose.sandbox.yml run --rm sandbox
```

Use the sandbox Compose file **on its own**. It sets a 4 GiB memory limit, a two-CPU limit, and a 512-process limit. It has normal outbound internet access, publishes no ports, and mounts no host directories, home volume, credentials, or Docker socket. The dev service is not started by this command.

Or use Docker directly:

```sh
docker run --rm -it --init \
  --hostname sandbox \
  --memory 4g --cpus 2 --pids-limit 512 \
  thadkkr/vm:sandbox
```

The shell runs as `ubuntu`, in `/workspaces`. Passwordless sudo lets you install system packages:

```sh
sudo apt-get update
sudo apt-get install -y your-package
uv venv --python python3 /tmp/experiment
. /tmp/experiment/bin/activate
# Install Python libraries with uv pip install, or use uv tool / pipx for CLIs.
```

Files, installed packages, shell history, and downloaded projects stay inside this container. Exit the shell to remove the container and its writable layer; the next invocation starts fresh. This is enforced by the launch command's `--rm`, not by the image itself. Avoid `docker compose up` for disposable sessions, because it retains containers until explicitly removed.

This does not mean zero host disk writes: Docker stores image layers and temporary container data in its own storage. Host projects are protected by the absence of mounts. See Docker's [container storage documentation](https://docs.docker.com/engine/containers/run/#filesystem-mounts).

The sandbox has no SSH server, VS Code, Docker Engine/CLI, GitHub CLI, Bun, Deno, or pnpm. Use `docker exec -it <container> bash` if you need another shell in a running session. It has standard container isolation and network access, including access to reachable LAN services; it is not a separate-kernel VM for running hostile malware.

### Sandbox tools and why they are included

| Area | Tools | Use |
| --- | --- | --- |
| CLI development | GCC/G++, make, pkg-config, Git, nvm with Node.js LTS/npm, Python 3, uv/uvx, pip, venv, pipx | Compile small projects and try CLI packages; nvm installs the latest Node LTS at build time, Python uses Ubuntu's maintained version, and uv manages Python environments and tools |
| Everyday shell work | curl, wget, jq, ripgrep, fd, fzf, tree, nano, less, tmux, rsync, zip/unzip, xz | Download, search, inspect, edit, and manipulate test data |
| Network and DNS | Nmap, netcat, socat, dig/host/nslookup, whois, ip/ss, ping, traceroute | Inspect connectivity, DNS, exposed services, and test TCP/UDP clients |
| TLS and keys | OpenSSL, GnuPG, OpenSSH client | Inspect certificates and try cryptographic or SSH workflows without host keys mounted |
| HTTP discovery | Gobuster | Test directory/file and DNS discovery with your own small wordlists |
| Packet inspection | tcpdump | Inspect capture files or, with `sudo`, traffic visible inside the container |
| File and binary inspection | file, binutils (`strings`, `readelf`, `objdump`), xxd, YARA | Inspect file types, binaries, hex data, and match your own rules |
| Script checks | ShellCheck | Check shell scripts before trying them |

The security and system tools are distro packages available for both architectures; no third-party security distribution repositories or large bundled wordlists are needed. [Ubuntu's Gobuster package](https://packages.ubuntu.com/resolute/gobuster) and [YARA package](https://packages.ubuntu.com/resolute/yara) document their architecture support. Exploit frameworks, GPU password crackers, browser proxies, and large scanner/template collections are left for session-specific installs to keep the base focused.

The sandbox installs [nvm](https://github.com/nvm-sh/nvm#installing-in-docker) and [uv](https://docs.astral.sh/uv/guides/integration/docker/) for `ubuntu`. Node LTS is the default nvm version, and `node`, `npm`, and `uv` also work as direct container commands without an interactive shell. To change Node versions for a session, use `nvm install <version>` and `nvm use <version>`.

Nmap works as the regular user with TCP connect scans, for example `nmap -sT -Pn -p 80,443 <your-test-host>`. Raw-packet scans need privileges; the [Nmap guide](https://nmap.org/book/scan-methods-connect-scan.html) explains the distinction. Packet capture sees the container's network namespace. Nothing here requires `--privileged`, host networking, or a Docker socket.

## Persistent dev container

The dev variant keeps the existing unminimized Ubuntu environment, SSH server, VS Code tunnel, Docker Engine with Buildx/Compose, GitHub CLI, Swift, nvm, pnpm, Bun, Deno, uv, fastfetch, Neovim, cloc, and existing general tools. It also includes the shared CLI utilities above, including Python/pipx, ripgrep, fd, ShellCheck, tmux, rsync, and build tools. nvm is installed without automatically installing a Node.js version; choose one inside the container.

Swift uses the newest stable [official Linux toolchain](https://www.swift.org/install/linux/ubuntu/) supporting the image's Ubuntu version and CPU architecture. Required compiler/runtime libraries are installed, and the archive is verified against its upstream GPG signature. Swift lives in `/opt/swift`, is on the image PATH, and has command links in `/usr/local/bin`, so it works through SSH, VS Code, and noninteractive commands even with an existing home volume. Set build argument `SWIFT_VERSION` to a release number if you need to pin it. Swift is included only in `dev`.

```sh
git clone https://github.com/thaddeuskkr/vm.git
cd vm
# Set KEYS and any other desired settings in compose.yml first.
docker compose up -d dev_container
```

The included `compose.yml` references `ghcr.io/thaddeuskkr/vm:dev`. It retains the existing service/container names and mounts:

| Container path | Storage | Contents |
| --- | --- | --- |
| `/home/ubuntu` | Named volume `home` | User settings, SSH keys, nvm versions, and home-installed tools |
| `/workspaces` | Host directory `./workspaces` | Projects and working files |
| `/data` | Host directory `./data` | VS Code tunnel state, server data, and extensions |
| `/volumes/.gnupg`, `/volumes/.gitconfig` | Read-only host mounts | Imported GPG keys and Git configuration |
| `/var/run/docker.sock` | Host socket | Access to the host Docker daemon |

The host Docker socket gives the dev container control over the host daemon; it is intentionally absent from the sandbox.

Supported dev environment variables:

| Variable | Behavior |
| --- | --- |
| `KEYS` | SSH public keys, separated by newlines |
| `PASSWORD` | Set the root/ubuntu password; otherwise generated at startup |
| `SSH_PASSWORD_AUTH` | Enable SSH password authentication; defaults to `false` |
| `SSH_ROOT_LOGIN` | Enable root SSH login; defaults to `false` |
| `DOCKER_GROUP` | Host Docker socket's numeric group ID |
| `CODE_TUNNEL_VERBOSE` | Enable verbose VS Code tunnel logging |

### Migrating and updating without losing dev data

Existing deployments should change only the image reference to `ghcr.io/thaddeuskkr/vm:dev` or `thadkkr/vm:dev`, then pull and recreate the service from the same Compose directory and project:

```sh
docker compose pull dev_container
docker compose up -d dev_container
```

**Renaming the checkout directory can change Compose's default project name and select a different home volume.** Keep the existing project name with `-p <existing-project-name>` or `COMPOSE_PROJECT_NAME`, and keep `./workspaces` and `./data` pointed at the original host directories. For example, if the existing project is named `dev-container`, use `docker compose -p dev-container ...` after renaming the checkout.

Back up the home volume, workspaces, and data before a base-release change. Do not use `docker compose down -v` for updates; it deletes the Compose-managed home volume. Files elsewhere in the container, including manually installed APT packages, changes under `/etc`, and files under `/root`, are not preserved when the container is replaced. Add required system packages to the Dockerfile so they can be recreated.

An existing home volume hides the home directory from the new image, so updates do not refresh tools already stored there. Manage those tools inside the container. Native binaries installed in the home directory may need reinstalling after an Ubuntu release change. Docker's [volume guide](https://docs.docker.com/engine/storage/volumes/) explains this behavior.

## Building and publishing

The Dockerfile has independent `dev` and `sandbox` targets sharing an unminimized Ubuntu base stage. Dev stays the default target for plain `docker build`. Bake builds both variants for both architectures:

```sh
docker buildx bake --push
```

`IMAGE` overrides Bake's repository (default `thadkkr/vm`); `BUILD_DATE` defaults to the current UTC date and can be overridden with `YYYYMMDD`. To load one variant on a single-architecture local builder, choose the appropriate platform:

```sh
docker buildx bake sandbox --set '*.platform=linux/arm64' --load
# Use linux/amd64 on an AMD64 machine.
bash tests/smoke.sh sandbox thadkkr/vm:sandbox
```

GitHub Actions runs daily, on relevant pushes, on pull requests, and manually. The matrix builds both variants on native AMD64/ARM64 Linux runners and smoke-tests each before publishing. The sandbox checks cover tool availability, sudo/package installation, nvm/Node LTS selection, uv-created Python environments, direct runtime commands, and discarded filesystem changes. Dev builds compile and execute a Foundation program as `ubuntu`. Smoke checks also build and execute a Swift package with a standard SSH/sudo PATH and the home directory masked by an empty temporary mount, alongside the existing tool, runtime-manager, and SSH checks; they do not authenticate an actual VS Code tunnel.

Publishing runs only on the repository's default branch. Pull requests and other branches build/test without logging in or publishing. Successful builds push architecture digests to registries with available credentials, then create separate multiarch manifests for each variant. The workflow verifies that each dated manifest contains both AMD64 and ARM64. Caches are scoped by variant/architecture; scheduled builds bypass cached installers to refresh packages.

Repository setup:

- To publish to Docker Hub, create repository `thadkkr/vm` and add repository secret `DOCKERHUB_TOKEN`, using a token with write permission for that repository. Without that secret, Docker Hub login and pushes are skipped.
- GHCR publishes as `ghcr.io/thaddeuskkr/vm` using the automatically provided `GITHUB_TOKEN` with `packages: write`; ensure the package permits this repository's Actions workflow to publish. If the token is unavailable, GHCR login and pushes are skipped. To explicitly disable GHCR even when the automatic token exists, set repository variable `PUBLISH_GHCR` to `false`.
- Set the GHCR package's visibility to public if anonymous pulls are desired.
- After the GitHub repository is renamed to `thaddeuskkr/vm`, the README's repository links and badge use that name. The workflow's source label follows the actual repository automatically.

Registry selection applies to login, architecture pushes, and multiarch manifest publication independently. If neither registry is enabled, the workflow still builds and tests all four images, then skips publishing and digest uploads. Configured but invalid credentials still cause a publishing error.

The workflow follows Docker's documented [native runner/multi-platform publishing pattern](https://docs.docker.com/build/ci/github-actions/multi-platform/).
