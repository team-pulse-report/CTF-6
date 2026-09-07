FROM ubuntu:24.04

# Outer host: its own Docker engine plus SSH. The engine deploys the inner stack
# at runtime.
RUN apt-get update \
    && apt-get install -y docker.io docker-compose-v2 openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/docker /run/sshd \
    && sed -i "s/#PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config \
    && sed -i "s/#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config \
    && ssh-keygen -A \
    && useradd -m -s /bin/bash victor \
    && echo -n "victor:ctHzaZo5HbNrUCPfBLH1HZ4n" | chpasswd \
    && userdel -r ubuntu \
    && sed -i 's#/bin/sh#/bin/bash#' /etc/passwd \
    && ln -sf /dev/null /root/.bash_history \
    && ln -sf /dev/null /home/victor/.bash_history

# Outer flags and the credential that ties the two outer flags together. The
# onboarding note is root-only, so victor's password is only recoverable after
# the Docker-socket breakout gives a root view of the outer filesystem.
COPY ./main_flags/root.txt /root/root.txt
COPY ./main_flags/user.txt /home/victor/user.txt
COPY ./docker-web /root/docker-web

RUN chown root:root /root/root.txt && chmod 0400 /root/root.txt \
    && chown victor:victor /home/victor/user.txt && chmod 0400 /home/victor/user.txt \
    && printf '%s\n' \
        'Onboarding notes (internal).' \
        'victor initial SSH password: ctHzaZo5HbNrUCPfBLH1HZ4n' \
        'Rotate after first login.' > /root/onboarding.txt \
    && chown root:root /root/onboarding.txt && chmod 0400 /root/onboarding.txt \
    && chown -R root:root /root/docker-web && chmod -R go-rwx /root/docker-web

# Store the inner engine's data on a volume so it does not run overlay-on-overlay.
# Without this, inner image builds fail on hosts whose /var/lib/docker is itself
# an overlay filesystem (for example Docker Desktop).
VOLUME /var/lib/docker

EXPOSE 22 23 8080

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["docker", "compose", "-f", "/root/docker-web/docker-compose.yaml", "up"]
