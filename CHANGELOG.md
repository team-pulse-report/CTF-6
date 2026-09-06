# Changelog

## Initial release

Original docker-in-docker CTF themed on cryptographic authentication failures.
The architecture (a privileged outer host running its own Docker engine that
deploys a vulnerable inner stack, with the final escape through a mounted outer
Docker socket) follows the pattern of the Himanshukr000/CTF-DOCKERS collection.

### Design

- Outer host `FROM ubuntu:24.04` runs `dockerd` plus `sshd` and, on start,
  deploys the inner stack with Docker Compose.
- Inner web tier is a single Flask service that issues HS256 JSON Web Tokens.
  The signing key is a dictionary word (`trustno1`), so a low-privilege demo
  token can be cracked offline and re-forged with `role: admin`.
- The admin console exposes an unsalted MD5 password store. One hash reverses to
  the SSH password of the web-container operator account `mallory`.
- Privilege escalation inside the web container is a `sudo NOPASSWD` rule on
  `/usr/bin/env` (GTFOBins).
- The web container mounts the outer Docker socket and ships a static Docker
  client, so container root can mount the outer host filesystem, read the outer
  root flag, and recover the outer user's SSH credential to log in as `victor`.

### Build hygiene

- Inner base image and static Docker client are pulled at build time, so the
  challenge is multi-arch (amd64 and arm64) with no pre-baked tarballs.
- The outer Dockerfile declares `VOLUME /var/lib/docker` so the nested engine
  does not run overlay-on-overlay.
- `.dockerignore` keeps git history, docs, license, and readme out of the build
  context and image layers.
