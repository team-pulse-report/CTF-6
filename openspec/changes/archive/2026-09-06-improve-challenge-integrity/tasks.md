# Tasks

## 1. Make the featured JWT vuln load-bearing (credential must stay in sync)

- [x] 1.1 Replace `mallory`'s SSH password in `docker-web/app.Dockerfile` chpasswd
  line with a value that is not an online top-N brute hit but is still recoverable
  by an offline MD5 crack.
- [x] 1.2 Update the stored MD5 hash for `mallory` in `docker-web/app/server.py`
  `USER_RECORDS` to `md5(new password)` so the offline crack still yields it.
- [x] 1.3 Update `docs/WALKTHROUGH.md` Stage 2 to reference the new password and
  its new MD5, and note that the JWT-forged admin console is now the only source
  of `mallory`'s credential.

## 2. Reproducible build pins

- [x] 2.1 Pin Flask and PyJWT in `docker-web/app.Dockerfile` (`flask==3.1.*`,
  `pyjwt==2.*`).

## 3. Robust service startup

- [x] 3.1 Add `ssh-keygen -A` to the sshd build RUN block and decouple the Flask
  service from sshd init in the `docker-web/app.Dockerfile` CMD.
- [x] 3.2 Bound the inner-engine wait in `entrypoint.sh` and emit a diagnostic on
  timeout instead of hanging silently.

## 4. Walkthrough honesty and hygiene

- [x] 4.1 Update `docs/WALKTHROUGH.md` Stage 5 to state the outer-user flag is
  directly root-readable via the `/host` mount and the SSH-to-`victor` step is for
  realism.
- [x] 4.2 `userdel -r ubuntu` and drop the unused `nano` in the outer `Dockerfile`.

## 5. Docs

- [x] 5.1 Add a dated (2026-09-06) CHANGELOG entry summarizing the integrity fixes.
- [x] 5.2 Note in `README.md` that the repo ships disposable challenge secrets.

## 6. Verify

- [x] 6.1 `bash -n` every shell script edited; confirm MD5 of the new password
  matches the stored hash; `openspec validate improve-challenge-integrity
  --strict`.
