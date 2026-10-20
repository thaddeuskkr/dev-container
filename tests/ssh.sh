#!/usr/bin/env bash
# Native Linux CI integration check, with a temporary client key and no mounts.
set -euo pipefail
variant=${1:?Usage: ssh.sh dev\|sandbox image}
image=${2:?Usage: ssh.sh dev\|sandbox image}
ssh_test=$(mktemp -d)
container=
cleanup() {
  if [ -n "$container" ]; then docker stop "$container" >/dev/null 2>&1 || true; fi
  rm -rf "$ssh_test"
}
trap cleanup EXIT

ssh-keygen -q -t ed25519 -N '' -f "$ssh_test/client"
public_key=$(cat "$ssh_test/client.pub")

# Neither variant may ship a shared private host key.
docker run --rm --entrypoint bash "$image" -ec '
  if compgen -G "/etc/ssh/ssh_host_*_key" >/dev/null; then exit 1; fi
'
run_options=(--rm --init --detach --publish 127.0.0.1::22
  --env "KEYS=$public_key" --env PASSWORD=ssh-smoke-only)
case "$variant" in
  sandbox)
    # Exercise the image default, including public key installation and config.
    container=$(docker run "${run_options[@]}" "$image")
    ssh_config=/etc/ssh/sshd_config_sandbox
    ;;
  dev)
    # Stub only the VS Code tunnel so SSH startup needs no external sign-in.
    container=$(docker run "${run_options[@]}" --entrypoint bash "$image" -euc '
      printf "#!/bin/sh\nexec sleep infinity\n" > /usr/bin/code
      chmod 0755 /usr/bin/code
      exec /entrypoint.sh
    ')
    ssh_config=/etc/ssh/sshd_config
    ;;
  *) echo "Unknown variant: $variant" >&2; exit 1 ;;
esac
binding=$(docker port "$container" 22/tcp)
port=${binding##*:}
ssh_options=(-F /dev/null -i "$ssh_test/client" -p "$port"
  -o BatchMode=yes -o IdentitiesOnly=yes -o IdentityAgent=none
  -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$ssh_test/known_hosts"
  -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=2)
ready=false
for _ in {1..30}; do
  if ssh "${ssh_options[@]}" ubuntu@127.0.0.1 'test "$(id -un)" = ubuntu' 2>/dev/null; then
    ready=true
    break
  fi
  sleep 1
done
if [ "$ready" != true ]; then
  docker logs "$container"
  echo "SSH login failed for $variant" >&2
  exit 1
fi

effective_config=$(docker exec "$container" /usr/sbin/sshd -T -f "$ssh_config")
for setting in 'passwordauthentication no' 'permitrootlogin no' 'pubkeyauthentication yes'; do
  grep -iqx "$setting" <<< "$effective_config"
done
case "$variant" in
  sandbox)
    # Remote commands need the same runtimes as local CLI sessions.
    ssh "${ssh_options[@]}" ubuntu@127.0.0.1 '
      set -e
      command -v nvm
      nvm current
      node -e "if (!process.release.lts) process.exit(1)"
      npm --version
      uv --version
      python3 --version
      sudo -n true
      touch /workspaces/ssh-disposable-marker
    '
    ;;
  dev)
    ssh "${ssh_options[@]}" ubuntu@127.0.0.1 'swift --version && sudo -n true'
    ;;
esac
# --rm must remove the server and its writable layer when it is stopped.
docker stop "$container" >/dev/null
if docker inspect "$container" >/dev/null 2>&1; then
  echo 'Stopped SSH container was not automatically removed.' >&2
  exit 1
fi
container=
docker run --rm --entrypoint bash "$image" -ec 'test ! -e /workspaces/ssh-disposable-marker'
