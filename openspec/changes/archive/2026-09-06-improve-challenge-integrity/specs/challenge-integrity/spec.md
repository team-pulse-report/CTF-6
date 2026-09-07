# Challenge integrity

## ADDED Requirements

### Requirement: Featured vulnerability is load-bearing

The challenge SHALL require its namesake weak-JWT-forgery vulnerability to obtain
at least one flag that is not otherwise reachable; no local-account SSH brute
force, direct file read, or socket mount SHALL trivialize the featured class.

#### Scenario: Online SSH brute cannot skip the JWT stage

- **WHEN** a player runs a naive online top-N password brute against the
  web-container SSH service on port 23 for the operator account
- **THEN** the account's password is not among the top-N candidates and the brute
  fails, so the only source of that credential is the admin console reached by a
  forged admin token

#### Scenario: Inner flags gate on the forged admin token

- **WHEN** a player attempts to reach the three inner-container flags without
  forging an admin JWT
- **THEN** container entry requires `mallory`'s SSH password, which is disclosed
  only by the admin console the forged token unlocks, so the JWT forge is a
  mandatory first step for every inner flag

### Requirement: Credential and stored hash stay in sync

Any password that the intended path recovers by cracking a stored hash SHALL be
identical to the credential used to authenticate, and the stored hash SHALL be
the hash of that exact credential, in every place it appears.

#### Scenario: MD5 store matches the SSH password

- **WHEN** a player cracks the operator's unsalted MD5 hash from the admin console
- **THEN** the recovered plaintext is exactly the operator's SSH password as set
  by the container's `chpasswd` line, and logging in over SSH with it succeeds

### Requirement: Documented solution path is reproducible

The challenge SHALL provide a WALKTHROUGH whose every documented stage succeeds
against the files as built, with no stage that dead-ends or contradicts the files.

#### Scenario: Walkthrough crack yields the built credential

- **WHEN** a maintainer follows the WALKTHROUGH Stage 2 crack against the hash
  shipped in `server.py`
- **THEN** the plaintext it documents matches the shipped `chpasswd` password and
  the subsequent SSH login step succeeds

### Requirement: Walkthrough honesty about the socket primitive

Where a mounted docker.sock yields outer root directly, the WALKTHROUGH SHALL
state that plainly and SHALL NOT claim a downstream credential or SSH stage is
required when it is a realism flourish.

#### Scenario: Outer-user flag is disclosed as directly readable

- **WHEN** a reader reaches Stage 5 (recover the outer user's password and SSH in)
- **THEN** the walkthrough states that the outer-user flag is directly readable as
  root through the `/host` mount and that the SSH-to-`victor` step is for
  completeness and realism, not a requirement

### Requirement: Robust service startup

Service startup SHALL be resilient: the primary web service SHALL NOT be coupled
to sshd init success, and any wait for the inner docker engine SHALL be bounded
and emit a diagnostic on failure rather than hanging silently.

#### Scenario: Web tier survives an sshd init hiccup

- **WHEN** the container's `service ssh start` returns non-zero at runtime
- **THEN** the Flask server still launches and the web tier stays reachable

#### Scenario: Bounded wait for the inner engine

- **WHEN** the outer entrypoint waits for the inner docker engine and the engine
  never becomes ready
- **THEN** the wait is bounded and prints a diagnostic hint rather than looping
  forever with no output

### Requirement: Reproducible build pins

Base images and language packages the documented exploit depends on SHALL be
pinned so the challenge builds reproducibly and the documented token behaviour
does not drift.

#### Scenario: Token library is pinned

- **WHEN** the inner web image is rebuilt at a later date
- **THEN** Flask and PyJWT install at the pinned versions, so `jwt.encode` /
  `jwt.decode` behave as the walkthrough documents
