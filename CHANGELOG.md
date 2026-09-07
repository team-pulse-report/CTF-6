# Changelog

## 2026-09-06 - Challenge integrity fixes

Adversarial review found the featured weak-JWT-forgery vulnerability was optional:
`mallory`'s SSH password was `iloveyou` (a top-10 wordlist entry) exposed on port
23, so an online brute plus the `sudo env` GTFOBins escalation reached all three
inner-container flags without ever forging an admin token.

- Replaced `mallory`'s SSH password with `velvet123`, a rockyou entry at line
  ~330,000: deep enough that a naive online top-N SSH brute (top-500/1000/10k)
  misses it while an offline crack of the admin console's unsalted MD5 against
  full rockyou or a crackstation lookup still recovers it instantly. The admin
  console (reached only by a forged admin JWT) is now the sole practical source of
  the credential, so the JWT forge is a required first step for every inner flag.
  The `chpasswd` value and the stored MD5 in `app/server.py`
  (`15cf0ae3726fdf8505b199e968106d68`) are updated together and kept in sync.
- Pinned Flask (`3.1.*`) and PyJWT (`2.*`) so the documented token behaviour does
  not drift on a later rebuild.
- Decoupled the inner Flask service from sshd init (`service ssh start || true;
  exec python3 ...`) and added `ssh-keygen -A` at build time so an sshd hiccup
  cannot take down the web tier.
- Bounded the outer entrypoint's wait for the inner Docker engine and made it emit
  a diagnostic on timeout instead of hanging silently.
- Outer-image hygiene: `userdel -r ubuntu` and dropped the unused `nano`.
- WALKTHROUGH: Stage 2 updated to the new credential; Stage 5 now states plainly
  that the outer-user flag is directly root-readable via the `/host` mount and the
  SSH-to-`victor` step is a realism flourish.

No flag values changed and no scoring changed.

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
