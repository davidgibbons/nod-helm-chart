#!/bin/sh
# Checks the docker shim's translation with a kubectl stub that echoes its args.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
printf '#!/bin/sh\necho "$@"\n' > "$stub/kubectl"
chmod +x "$stub/kubectl"
run() { PATH="$stub:$PATH" sh "$here/docker" "$@"; }
expect() { [ "$1" = "$2" ] || { printf 'FAIL\n got: %s\nwant: %s\n' "$1" "$2"; exit 1; }; }
refused() { if run "$@" 2>/dev/null; then echo "FAIL: accepted $*"; exit 1; fi; }

expect "$(run exec -i --user node --workdir /workspace/abc nod-workspace-0 /usr/bin/python3 -c 'x y')" \
  'exec -i --quiet nod-workspace-0 -- setpriv --reuid=1000 --regid=1000 --clear-groups env -C /workspace/abc HOME=/home/node /usr/bin/python3 -c x y'
expect "$(run exec -i --user 23456:1002 --workdir /var/tmp nod-workspace-0 true)" \
  'exec -i --quiet nod-workspace-0 -- setpriv --reuid=23456 --regid=1002 --clear-groups env -C /var/tmp HOME=/ true'
expect "$(run exec -i --user node nod-browser-0 node /app/bridge.mjs)" \
  'exec -i --quiet nod-browser-0 -- node /app/bridge.mjs'
refused exec -i --user root nod-workspace-0 sh
refused exec -i --user 0:1002 nod-workspace-0 sh
refused exec -i --user root nod-browser-0 sh
refused exec -i --user node other-pod sh
refused run -i nod-workspace-0
echo ok
