#!/bin/bash

set -e

# Start the outer Docker engine and SSH daemon.
dockerd > /dev/null 2>&1 &
/usr/sbin/sshd -D > /dev/null 2>&1 &

# Wait for the engine to accept commands before deploying the inner stack. Bound
# the wait so a misconfigured run (missing --privileged, cgroup/seccomp
# restriction, corrupt /var/lib/docker) fails loudly instead of hanging silently.
DOCKERD_WAIT_SECONDS=60
waited=0
until docker info >/dev/null 2>&1; do
    if [ "$waited" -ge "$DOCKERD_WAIT_SECONDS" ]; then
        echo "dockerd did not become ready within ${DOCKERD_WAIT_SECONDS}s;" \
             "did you run with --privileged? check /var/lib/docker." >&2
        exit 1
    fi
    sleep 1
    waited=$((waited + 1))
done

# Run CMD (docker compose builds the inner stack and pulls base images).
exec "$@"
