# Improve challenge integrity

## Why

An adversarial review of the CTF-1..10 family on 2026-09-06 found that CTF-6's
namesake vulnerability (weak HS256 JWT forgery) is entirely optional. Two
independent shortcuts collapse the intended chain:

- The web-container operator `mallory` has SSH password `iloveyou`, a top-10
  rockyou entry, exposed on port 23 with `PasswordAuthentication yes` and no rate
  limiting. A naive online brute force reaches a shell without ever touching the
  admin console.
- Once in the container, `mallory` escalates to root through the `NOPASSWD`
  `/usr/bin/env` sudo rule and reads `/flags/admin.txt` directly, because that
  flag is staged as a plain `root:400` file at the exact path `server.py` reads.

Together these let a player collect all three inner-container flags (admin,
mallory, inner-root) without ever calling `/api/login`, cracking the HS256 key,
or forging an admin token. The featured vulnerability is decorative.

The review also flagged reproducibility and robustness nits: unpinned Flask and
PyJWT that could drift the documented token behaviour on a rebuild, inner web
availability coupled to the sshd init script, an unbounded wait for the inner
engine with no diagnostic, and outer-image hygiene leftovers.

## What Changes

- **ADDED** requirement that the featured JWT-forgery vulnerability is
  load-bearing: replace `mallory`'s guessable SSH password so a naive online
  top-N brute fails, and keep the offline recovery consistent by updating the
  stored MD5 hash in `server.py` to match the new password (the intended path
  recovers the SSH password by cracking that hash).
- **ADDED** requirement that the documented solution path stays reproducible: the
  WALKTHROUGH's Stage 2 crack yields the new password against the files as built.
- **ADDED** requirement that the walkthrough is honest about the socket
  primitive: Stage 5's outer-user flag is directly root-readable via the `/host`
  mount, so the SSH-to-`victor` step is a realism flourish, not a requirement.
- **ADDED** requirement that service startup is robust: the inner Flask service is
  decoupled from sshd init, host keys are generated at build time, and the outer
  engine wait is bounded with a diagnostic on timeout.
- **ADDED** requirement that build pins are reproducible: Flask and PyJWT are
  pinned so the documented token behaviour does not drift on a rebuild.

## Impact

- Affected files: challenge content (`docker-web/app.Dockerfile`,
  `docker-web/app/server.py`, `Dockerfile`, `entrypoint.sh`) and docs
  (`docs/WALKTHROUGH.md`, `CHANGELOG.md`, `README.md`).
- **No scoring or flag-value change.** No flag file's value is moved, altered, or
  deleted. `mallory`'s inner-root and both outer flags are unchanged; the admin
  flag is unchanged and still served by the API.
- The credential change is applied in every place `mallory`'s password appears
  (the `chpasswd` line and the stored MD5 hash in the admin store) so they stay
  in sync; the walkthrough is updated to match.
- Out of scope: the socket-breakout genre inherently exposes root-readable outer
  flags after the mount; making the outer-user login truly load-bearing would
  need a PAM/profile redesign and is documented as a residual, not fixed here.
- No git commit is made; all edits are left uncommitted in the working tree.
