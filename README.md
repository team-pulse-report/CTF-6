# Weak-JWT Docker-in-Docker CTF

This is a Capture The Flag challenge that runs as a single privileged Docker
container. Inside it, an outer host runs its own Docker engine and deploys a
small web tier whose authentication is a weak HS256 JSON Web Token. The path
runs from forging an admin token, through cracking an unsalted MD5 password, into
the web container, up to container root, and finally back out to the outer host.

There are five flags:

| Flag file | Location | Prefix |
|---|---|---|
| admin.txt (served by the API) | web container admin console | `FLAG{...}` |
| user.txt | web container, user `mallory` | `FLAG{...}` |
| root.txt | web container, `root` | `TOKEN_FLAG{...}` |
| root.txt | outer host, `root` | `MAIN_FLAG{...}` |
| user.txt | outer host, user `victor` | `MAIN_FLAG{...}` |

## Requirements

- Docker Engine that can run a privileged container (Docker Desktop works).
- Internet access on the first run: the inner stack pulls its base image and a
  static Docker client at build time, and the breakout pulls a small image.
- Works on both amd64 and arm64 hosts.

## Running the challenge

```bash
git clone https://github.com/jesse-quinn/CTF-6.git
cd CTF-6
docker image build -t ctf6:latest .
docker container run -it --rm --privileged \
  --hostname ctf6 --name ctf6 \
  -p 8080:8080 -p 22:22 -p 23:23 \
  ctf6:latest
```

Run the build and run from inside the cloned `CTF-6` directory. On Docker
Desktop (macOS, Windows) do not use `sudo`; on a Linux host, prefix both
commands with `sudo` or add your user to the `docker` group.

Then wait for the inner Docker Compose stack to finish deploying. The web
application is served on port 8080, the outer host SSH on port 22, and the web
container SSH on port 23.

Note: if you use `-d`, you will not see the inner Compose deployment progress.

If some of those host ports are already in use on your machine, remap the left
side of each `-p` flag (for example `-p 18080:8080 -p 2222:22 -p 2323:23`); the
challenge itself is unaffected.

## Rules

- Do not read the flag files or the solution notes during setup. The challenge
  is finding them through gameplay.
- The intended solution path is documented, for maintainers, in
  `docs/WALKTHROUGH.md`. It is a spoiler; do not open it if you want to play.

## Credits

This is an original challenge, inspired by the Himanshukr000/CTF-DOCKERS
collection and themed on cryptographic auth failures (weak HS256 JWT signing and
unsalted MD5 hashing). See `CHANGELOG.md` for the design notes.
