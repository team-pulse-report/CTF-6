FROM python:3.12-slim-bookworm

ARG DOCKER_CLI_VERSION=29.8.0

# Runtime tooling plus a static Docker CLI. The CLI is what inner-container root
# uses against the mounted outer socket for the final breakout, so it is fetched
# per architecture (arm64 and amd64) rather than baked as a fixed binary.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-server sudo curl ca-certificates procps \
    && pip install --no-cache-dir 'flask==3.1.*' 'pyjwt==2.*' \
    && arch="$(uname -m)" \
    && curl -fsSL "https://download.docker.com/linux/static/stable/${arch}/docker-${DOCKER_CLI_VERSION}.tgz" -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1 docker/docker \
    && rm -f /tmp/docker.tgz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Accounts. mallory is the operator account reachable over SSH once her MD5
# password is cracked; root is the privilege-escalation target. Her password is a
# wordlist entry deep enough that a naive online top-N SSH brute misses it, while
# an offline crack of the unsalted MD5 in the admin store still recovers it, so the
# forged admin JWT is the only practical route to her credential. The chpasswd
# value here MUST stay in sync with the MD5 in app/server.py (USER_RECORDS).
RUN useradd -m -s /bin/bash mallory \
    && echo "mallory:velvet123" | chpasswd \
    && ln -sf /dev/null /home/mallory/.bash_history \
    && ln -sf /dev/null /root/.bash_history \
    && mkdir -p /run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Privilege-escalation misconfiguration: mallory may run env as root without a
# password, which is a direct GTFOBins shell (sudo env /bin/sh).
COPY --chown=root:root --chmod=440 ./sudoers /etc/sudoers.d/mallory

# Application code.
COPY ./app /app

# Flags. The admin flag is served by the API to an admin token; the other two
# are on-disk and owned by their respective accounts.
COPY --chown=root:root --chmod=400 ./flags/admin.txt /flags/admin.txt
COPY --chown=mallory:mallory --chmod=400 ./flags/mallory.txt /home/mallory/user.txt
COPY --chown=root:root --chmod=400 ./flags/inner-root.txt /root/root.txt

EXPOSE 8080 22

# Start sshd independently of the web tier: an sshd init hiccup must not take down
# the Flask service, which is the challenge's sole entry point.
CMD service ssh start || true; exec python3 /app/server.py
