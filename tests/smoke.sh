#!/usr/bin/env bash
# Run on native Linux CI runners; no host project/credential mounts.
set -euo pipefail
variant=${1:?Usage: smoke.sh dev\|sandbox image}
image=${2:?Usage: smoke.sh dev\|sandbox image}

case "$variant" in
  sandbox)
    test "$(docker image inspect --format '{{json .Config.Entrypoint}}' "$image")" = '["/sandbox-entrypoint.sh"]'
    test "$(docker image inspect --format '{{json .Config.Volumes}}' "$image")" = null
    test "$(docker image inspect --format '{{json .Config.Cmd}}' "$image")" = '["sshd"]'
    # Exercise the normal image command path, sudo installs, and working files.
    docker run --rm --init "$image" bash -euc '
      test "$(id -un)" = ubuntu
      test "$PWD" = /workspaces
      for tool in git curl jq rg fd gcc make python3 pipx nvm node npm uv uvx shellcheck \
          nmap nc socat dig whois openssl tcpdump gobuster yara readelf xxd sshd; do
        command -v "$tool"
      done
      for tool in code docker bun deno swift swiftc; do
        if command -v "$tool"; then
          echo "Unexpected dev-only tool: $tool" >&2
          exit 1
        fi
      done
      touch /workspaces/disposable-marker
      sudo touch /etc/disposable-marker
      sudo apt-get update
      sudo apt-get install -y --no-install-recommends hello
      hello
      uv --version
      uv venv --python /usr/bin/python3 --no-python-downloads /tmp/venv
      /tmp/venv/bin/python -c "print(123)"
      test "$(nvm current)" = "$(nvm version default)"
      node -e "if (!process.release.lts) process.exit(1); console.log(process.release.lts)"
      npm --version
      nmap --version
      sudo tcpdump --version
    '
    # Direct commands must find the runtimes without a Bash startup file.
    docker run --rm "$image" node -e 'if (!process.release.lts) process.exit(1)'
    docker run --rm "$image" npm --version
    docker run --rm "$image" uv --version
    # A fresh container must not retain either filesystem change.
    docker run --rm "$image" bash -euc '
      test ! -e /workspaces/disposable-marker
      test ! -e /etc/disposable-marker
    '
    ;;
  dev)
    docker run --rm --entrypoint bash "$image" -euc '
      for tool in code sshd docker gh nvim rg fd python3 shellcheck swift swiftc; do
        command -v "$tool"
      done
      sudo -H -u ubuntu bash -ic '\''
        for tool in nvm pnpm bun deno uv swift swiftc sourcekit-lsp; do
          command -v "$tool" || exit 1
        done
      '\''
      code --version
      docker --version
      test -x /entrypoint.sh
      mkdir -p /run/sshd
      ssh-keygen -A
      /usr/sbin/sshd -t
    '
    # Mask the image home like a persistent dev home volume, without host mounts.
    # Swift must remain usable by ubuntu and build a Foundation-based package.
    docker run --rm -i --user ubuntu \
      --tmpfs /home/ubuntu:uid=1000,gid=1000,mode=0700 \
      --entrypoint bash "$image" -se < tests/swift.sh
    ;;
  *) echo "Unknown variant: $variant" >&2; exit 1 ;;
esac

# Authenticate an actual SSH session in the default sandbox/server startup path.
bash tests/ssh.sh "$variant" "$image"
