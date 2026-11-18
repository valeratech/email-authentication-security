# BP-001 R3: Builder correction to the hub scaffold

| | |
|---|---|
| Responds to | Reviewer review of BP-001 R2 (2026-11-16), disposition **REVISE** |
| From → To | Builder (Claude) → Reviewer |
| Date | 2026-11-17 |
| Requests | Acceptance of the revised hub design; closure of B01 to B05 |
| Authorizes | Nothing. Repository creation, the first commit and publication each need the Operator's separate approval |
| Attachment | `project-repository-requirements.md` (proposed as `docs/project-repository-requirements.md`) |
| Filed as | `reviews/BP001-R03-builder.md`, once the repository exists |

Unchanged from R2: the repository name (`valeratech/email-authentication-security`), WSL Ubuntu with bash, git and the GitHub CLI, creation as an empty private repository, and the GitHub no-reply commit identity.

Changed: the architecture (section 1), the visibility trigger (section 2), and every finding's disposition (sections 4 to 6).

---

## 1. Operator architecture change

**This change is the Operator's.** The Reviewer accepted R2's four-folder layout and said it need not be reopened. The Operator has since replaced it, for a reason R2 did not know.

The Postfix/Dovecot build already exists as its own public repository, `valeratech/secure-mail-platform`: a hand-built mail platform in an isolated VMware Workstation lab, on reserved `.test` names, with no mail to or from the Internet. It runs its own Builder/Reviewer process; Section 1 of 13 was accepted on 2026-11-09.

That makes R2's layout wrong in two ways:

- `02-postfix-dovecot` would be a second copy of work that already has a home.
- Folders `01`, `03` and `04` assumed a registered test domain reachable from the Internet. `secure-mail-platform` deliberately has neither, so those three could not be built on it.

**The hub is now an index.** It holds an index README, its own review record and its own gates. It holds no lab evidence, no configuration and no project folders.

- Each project is its own repository, with its own scope file and its own Builder/Reviewer record.
- Project 1 is `secure-mail-platform`. The hub links to it and copies nothing from it.
- The hub lists only projects the Operator has made official. Today that is one.
- The hub states a project's status only as that project's own Status table states it.

The topics behind the withdrawn folders (SPF/DKIM/DMARC on a real domain, MTA-STS, DMARC report handling) are not abandoned. They will be scoped inside whichever future project runs on a real domain, in that project's repository.

## 2. Operator decisions

All four open items from R2 are decided. The Reviewer's recommendations were followed, adjusted for the index design.

| Item | Operator decision |
|---|---|
| License | None for now. No `LICENSE` file |
| Test-domain name in evidence | No longer a hub question: the hub holds no evidence. Decided in the project that uses a real domain |
| Conventions | The same as `secure-mail-platform`: review rounds committed as written under `reviews/`, and the same four gate layers |
| Secret scanning | Mandatory four-layer gate: redact at source, sensitive-content audit with a git-ignored deny-list, pre-commit hooks, CI Gitleaks scan of the full history |
| Visibility | Private until this proposal is accepted, the scaffold is committed, every gate passes and a full-history publication review is done. It no longer waits for Project 1 to finish, which is a 13-section build |

## 3. Proposed layout

| Path | Purpose |
|---|---|
| `README.md` | The index: what the hub is; a statement that everything linked is lab work, not production or employer work; the project table (one row today); how a project joins; the standards cited; how the repository is governed |
| `SECURITY.md` | What never enters this repository; the exposure response order (N02); how to report an exposure without repeating the value |
| `.gitignore` | Deny by default. In full in 4.1 |
| `.gitattributes` | LF normalization for text; binaries untouched. In full under N05 |
| `.gitleaks.toml`, `.pre-commit-config.yaml`, `.audit-allow`, `.github/workflows/ci.yml` | The gate. Described under B05 |
| `docs/project-repository-requirements.md` | The standing requirements every project repository meets. Attached |
| `reviews/README.md` | The review protocol and the record table |
| `reviews/BP001-R02-builder.md`, `-R02-reviewer.md`, `-R03-builder.md`, and the Reviewer's ruling on R3 | The rounds, as written |
| `scripts/audit-sanitize.sh`, `scripts/negative-control.sh` | The sensitive-content audit and the proof it can still fail |
| `scripts/ignore-control.sh` | The `.gitignore` validation. In full in 4.2 |

The README does not name the Operator's former employer. It points to the Operator's portfolio site for professional background.

---

## 4. Blocking findings

### B01: `.gitignore` coverage and validation

**Accepted.** The Reviewer's point was that sensitive files cannot be reliably recognised by extension. For a repository that holds a small, closed set of files, the answer is to stop listing what to block and list what to allow.

**Deliberate difference from `secure-mail-platform`:** that repository uses a block-list, because it must admit an open-ended range of configuration and evidence files. The hub admits seven named top-level files and four folders, each limited to one file type. The Reviewer is asked to rule on this difference (section 9).

#### 4.1 The proposed `.gitignore`

```gitignore
# email-authentication-security: index hub
#
# Deny by default. This repository holds an index, its review record and its own gates:
# a small, closed set of files. Everything else is ignored, so a file does not need a
# recognisable name or extension to be kept out.
#
# This is a preventive measure, not a security boundary: `git add -f` overrides it.
# What enforces it is scripts/ignore-control.sh and the tracked-but-ignored check, both
# run by pre-commit and again by CI.

# 1. Ignore everything at the top level
/*

# 2. Re-include the approved top-level files
!/.gitignore
!/.gitattributes
!/.gitleaks.toml
!/.pre-commit-config.yaml
!/.audit-allow
!/README.md
!/SECURITY.md

# 3. Re-include each approved directory, then only its approved file type.
#    Subdirectories stay ignored.
!/.github/
/.github/*
!/.github/workflows/
/.github/workflows/*
!/.github/workflows/*.yml

!/docs/
/docs/*
!/docs/*.md

!/reviews/
/reviews/*
!/reviews/*.md

!/scripts/
/scripts/*
!/scripts/*.sh
```

#### 4.2 The validation: `scripts/ignore-control.sh`

The script builds a scratch repository in a temporary directory, copies the real `.gitignore` into it, and creates harmless synthetic files there. Each holds only the word "synthetic". Nothing is created in the real working tree. It checks both directions and the one thing `.gitignore` cannot do.

```bash
#!/usr/bin/env bash
# ignore-control.sh: proves the .gitignore works in both directions.
#
# Builds a scratch repository in a temporary directory, copies this repository's
# .gitignore into it, and creates harmless synthetic files there (each holds only the
# word "synthetic"). Nothing is created in the real working tree.
#
#   1. Every prohibited file must be ignored.
#   2. Every approved file must stay trackable, and `git add -A` must stage exactly the
#      approved set and nothing else.
#   3. A force-added ignored file must be caught by the tracked-but-ignored check,
#      because .gitignore alone does not stop `git add -f`.
#
# Exit 0 = PASS. Exit 1 = a rule failed. Exit 2 = setup error.
set -uo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -r "$ROOT/.gitignore" ] || { printf 'ERROR: no .gitignore at the repository root\n'; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 2
git init -q . || exit 2

# The approved set: every path this repository is meant to hold.
MUST_TRACK=(
  .gitignore .gitattributes .gitleaks.toml .pre-commit-config.yaml .audit-allow
  README.md SECURITY.md
  .github/workflows/ci.yml
  docs/project-repository-requirements.md
  reviews/README.md reviews/BP001-R03-builder.md
  scripts/audit-sanitize.sh scripts/negative-control.sh scripts/ignore-control.sh
)

# Prohibited paths, one group per category. Several of these synthetic names look like
# hostnames to audit-sanitize.sh, so those lines carry its inline exemption marker.
MUST_IGNORE=(
  # raw evidence, at any depth
  evidence/raw/report.xml project/evidence/raw/headers.txt evidence-working/session.log  # audit-ok
  # private keys, and certificates that contain keys
  server.key chain.pem dkim.private store.p12 store.pfx scripts/signing.key  # audit-ok
  # credentials and the local deny-list
  .env .env.local credentials.txt api.secret .audit-denylist  # audit-ok
  # SSH private keys, which have no extension
  id_rsa id_ed25519 docs/id_ed25519
  # raw report archives
  report.xml.gz reports.zip reports.tar reports.tgz  # audit-ok
  # raw email and packet captures
  message.eml mail.mbox capture.pcap capture.pcapng reviews/message.eml  # audit-ok
  # temporary files and backups
  .README.md.swp README.md.bak notes.tmp docs/notes.md~  # audit-ok
  # local Python artifacts
  .venv/pyvenv.cfg __pycache__/audit.cpython-312.pyc  # audit-ok
  # images
  screenshot.png docs/diagram.png
  # anything unplanned: unknown names, types and folders
  notes.txt docs/notes.txt docs/nested/page.md scripts/tool.py
  new-folder/README.md .github/dependabot.yml
)

for p in "${MUST_TRACK[@]}" "${MUST_IGNORE[@]}"; do
  mkdir -p "$(dirname "$p")" && printf 'synthetic\n' > "$p"
done
cp "$ROOT/.gitignore" .gitignore

fails=0

# 1. Prohibited files are ignored.
for p in "${MUST_IGNORE[@]}"; do
  git check-ignore -q -- "$p" || { printf 'FAIL: not ignored: %s\n' "$p"; fails=1; }
done

# 2. Approved files are trackable, and nothing else is staged.
for p in "${MUST_TRACK[@]}"; do
  git check-ignore -q -- "$p" && { printf 'FAIL: approved file is ignored: %s\n' "$p"; fails=1; }
done
git add -A
staged="$(git ls-files | sort)"
expected="$(printf '%s\n' "${MUST_TRACK[@]}" | sort)"
if [ "$staged" != "$expected" ]; then
  printf 'FAIL: the staged set differs from the approved set (< expected, > staged):\n'
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$staged") | sed 's/^/  /'
  fails=1
fi

# 3. A force-added ignored file is caught by the tracked-but-ignored check.
forced="project/evidence/raw/headers.txt"
git add -f "$forced"
caught="$(git ls-files -ci --exclude-standard)"
[ "$caught" = "$forced" ] || {
  printf 'FAIL: the tracked-but-ignored check did not catch a force-added file\n'; fails=1; }

if [ "$fails" -eq 0 ]; then
  printf 'ignore control PASS: %d prohibited paths ignored, %d approved paths trackable, force-add caught\n' \
    "${#MUST_IGNORE[@]}" "${#MUST_TRACK[@]}"
  exit 0
fi
exit 1
```

#### 4.3 Coverage against the Reviewer's categories

| Reviewer's category | Synthetic paths tested | Result |
|---|---|---|
| Raw evidence at every project depth | `evidence/raw/`, `project/evidence/raw/`, `evidence-working/` | Ignored |
| Private keys and certificates containing keys | `*.key`, `*.pem`, `*.private`, `*.p12`, `*.pfx`, and a key file inside `scripts/` | Ignored |
| Credentials | `.env`, `.env.*`, a credentials file, a `*.secret` file, the deny-list itself | Ignored |
| SSH private keys | `id_rsa`, `id_ed25519`, and one inside `docs/` | Ignored |
| Raw report archives | `*.gz`, `*.zip`, `*.tar`, `*.tgz` | Ignored |
| Raw email and packet captures | `*.eml`, `*.mbox`, `*.pcap`, `*.pcapng`, and one inside `reviews/` | Ignored |
| Temporary files and backups | `*.swp`, `*.bak`, `*.tmp`, an editor `~` backup inside `docs/` | Ignored |
| Local Python artifacts | `.venv/`, `__pycache__/` | Ignored |
| Beyond the Reviewer's list | Images; a text file in `docs/`; a nested folder under `docs/`; a Python file in `scripts/`; a new top-level folder; an unlisted file in `.github/` | Ignored |
| Approved documentation and gate files | Fourteen approved paths: every top-level file, and at least one file in each approved folder | Trackable, and `git add -A` staged exactly these |

The Reviewer's other two examples, masked XML reports and `.gitkeep` files, no longer apply: the hub holds no evidence and no empty folders.

#### 4.4 Results

Run by the Builder in a sandbox on 2026-11-17 (git 2.43.0). These show the plan works. They are not the evidence of record: that is the Operator's run in WSL, before the first commit.

| Run | `.gitignore` used | Expected | Result |
|---|---|---|---|
| A | As proposed in 4.1 | PASS | PASS: 40 prohibited paths ignored, 14 approved paths trackable, force-add caught |
| B | Emptied | FAIL | FAIL, exit 1 |
| C | The `!/README.md` line removed | FAIL | FAIL: approved file ignored; staged set short by one |
| D | The `/docs/*` line removed | FAIL | FAIL: five prohibited paths under `docs/` not ignored, and staged |

Runs B to D prove the control can fail. The script also passes `shellcheck` with the portfolio's two exclusions.

#### 4.5 Limits, stated plainly

- **`git add -f` overrides any ignore rule.** The enforcement is the tracked-but-ignored check under B05, which fails the commit and the CI run if any tracked or staged file matches an ignore rule. Run A's third step proves that check catches a force-added file.
- **The rules look at paths, not content.** Any `.md` file in `docs/` or `reviews/` is trackable whatever it says. Content is the gate's job (B05).
- **A new file type needs a deliberate rule change.** That is intended, and the change is visible in review. The control fails if the change opens any path on its prohibited list. It does not notice a newly approved path by itself, so that path is added to the control's approved list in the same commit.

### B02: Raw evidence custody

**Accepted, and relocated.** The hub holds no evidence, raw or masked, so there is nothing here to keep custody of.

The Reviewer's five-step lifecycle is adopted in full as a standing requirement on every project repository: section 4 of the attached requirements file. That section also carries the Reviewer's conditions for an in-tree raw folder (restrictive permissions, verified ignore rules, a retention period) and the rule that keys and credentials stay outside the working tree.

`secure-mail-platform` already keeps raw evidence in a git-ignored working folder and excludes key material. The Builder has **not** verified that repository's folder permissions or retention period, and claims nothing about them here. That is a matter for its own record.

### B03: Masking that preserves technical relationships

**Accepted, and relocated.** Section 5 of the attached requirements file adopts every element: consistent, collision-free replacements; preserved alignment, distinct senders, results, counts and dispositions; the wider coverage list (report identifiers, message IDs, URLs, headers, screenshots, image metadata, terminal prompts, message content); the masked / synthetic / raw labels; and the statement that redacted headers cannot reproduce the original DKIM verification.

The hub's own text uses only documentation values (RFC 5737, RFC 3849, RFC 2606).

### B04: Project 01 verification dependency

**Withdrawn with the layout; the principle is kept.** The 01-before-02 ordering no longer exists.

The Reviewer's distinction survives as section 6 of the requirements file: a record that resolves proves publication, not authentication; a published reject policy does not prove a receiver enforced it; parsing proves syntax, not control.

The same principle governs the hub's own wording: it reports each project's status from that project's Status table and never infers progress.

### B05: Mandatory pre-commit security gate

**Accepted.** The gate is mandatory. The Operator's choice was which tooling, and that is decided: the four layers `secure-mail-platform` already runs, supplemented by manual inspection.

| Reviewer's required coverage | Control | Where it runs |
|---|---|---|
| Staged filenames | Deny-by-default `.gitignore`; the tracked-but-ignored check (`git ls-files -ci --exclude-standard` must print nothing); a 512 KB file-size limit; images blocked unless allowlisted | Pre-commit and CI |
| Staged contents: credentials and private keys | Gitleaks with its default rules plus the portfolio's custom rules; `detect-private-key`; the audit's own credential and key patterns | Pre-commit; CI over the full history |
| Unmasked identifiers and proprietary information | `audit-sanitize.sh`: IP addresses, domains, email addresses, home paths and MAC addresses, each classified against approved documentation values; plus the git-ignored deny-list of employer, customer and production strings | Pre-commit (with the deny-list); CI (without it, see limits) |
| Compliance with raw-evidence exclusions | `ignore-control.sh` and the tracked-but-ignored check. The hub is not meant to hold evidence at all | Pre-commit and CI |
| Manual inspection of images and other non-text evidence | Binaries are reported by the audit and images are blocked by default. Before every commit the Operator reads the complete staged diff | Operator, every commit |
| The gate itself still works | `negative-control.sh`: the audit must reject planted bad values and accept a clean file. For the ignore rules, the equivalent proof is runs B to D in 4.4, done by hand | CI; by hand for the ignore rules |

**Gate files.** They are derived from `secure-mail-platform` at commit `df3319e`. They are described here, not yet produced; section 8 says when they are produced in full.

| File | Change for the hub |
|---|---|
| `.pre-commit-config.yaml` | Copied. The lab-entry lint hook is removed (the hub has no `lab/`). Two local hooks are added: `ignore-control` and the tracked-but-ignored check. Hook versions stay pinned as in the source |
| `.gitleaks.toml` | Copied. Rules unchanged. The allowlist loses the lab-namespace and evidence-folder entries the hub does not use, which only tightens it |
| `scripts/audit-sanitize.sh` | Copied. The automatic approval of the lab subnet is removed: the hub publishes no lab addresses, so any private address here is a finding. No other logic changes |
| `scripts/negative-control.sh` | Copied. Its known-good line uses documentation values instead of lab values |
| `.github/workflows/ci.yml` | Copied. The lab-entry lint step is removed; `ignore-control` and the tracked-but-ignored check are added |
| `.audit-allow` | New. One entry: `ryanvalera.com`, the Operator's portfolio site, which the README links to |
| `scripts/ignore-control.sh` | New. In full in 4.2. Its lists of synthetic filenames carry the audit's inline exemption marker, because several look like hostnames to the audit. The audit's domain check itself is not relaxed |

**Limits, stated plainly.**

- **Local hooks can be skipped** with `--no-verify`. CI repeats every check on push, and Gitleaks there scans the full history.
- **CI cannot see the deny-list.** The list is git-ignored by design, because the list itself would be a leak. Deny-listed terms are therefore checked only on the Operator's machine. The publication review (N01) includes a local deny-list search of the full history for that reason.
- **The Builder has not read the portfolio's `WORKFLOW.md`**, which `secure-mail-platform` cites but does not contain. The conventions here are taken from that repository as committed. If `WORKFLOW.md` differs, it governs.

**Builder's test of the audit change.** With the lab-subnet approval removed and the one `.audit-allow` entry in place, the audit reports CLEAN on the R2 proposal, this document, the attached requirements file, `.gitignore`, `.gitattributes` and `ignore-control.sh`. It reports six findings on the R2 review as received, all of one kind; section 7 covers them.

---

## 5. Nonblocking findings

| ID | Disposition |
|---|---|
| N01 | **Accepted.** A publication review is required before visibility changes, and is now part of the Operator's visibility decision. It covers: CI passing on the commit to be published; Gitleaks over the full history; the audit over the working tree; a local deny-list search of every commit's content and every commit message; every commit's author and committer identity; and the Operator reading the complete history. The review is recorded in `reviews/` before the Operator authorizes the change |
| N02 | **Accepted.** `SECURITY.md` states the order: revoke or rotate first, then contain, then remediate history, and that deleting the file is not enough. The same rule is section 8 of the requirements file |
| N03 | **Accepted, and relocated.** The hub runs no mail server. Section 6 of the requirements file requires isolated positive and negative relay tests, including rejection of unauthenticated external-to-external delivery, before any project's mail server can reach the Internet |
| N04 | **Accepted.** See section 6 |
| N05 | **Accepted.** The proposed `.gitattributes` is below. Tested in a sandbox: a CRLF Markdown file was stored with LF; a `.png` and a `.gz` file containing CRLF bytes were stored byte-identical |
| N06 | **Accepted, and relocated.** The hub no longer has a project template. Section 1 of the requirements file requires each project's scope file to state its prerequisites, references and known limitations |
| N07 | **Accepted.** At creation the Operator confirms, and the output is kept: the effective git author name and email (the no-reply address); the active GitHub CLI account; the repository's visibility and URL straight after creation; the remote URL; and the author and committer identity on the first commit |

```gitattributes
# Files Git detects as text are stored and checked out with LF line endings.
# Files Git detects as binary are left untouched.
* text=auto eol=lf

# Explicitly binary, should one ever be approved: no line-ending conversion, no text diff.
*.png  binary
*.jpg  binary
*.jpeg binary
*.gif  binary
*.webp binary
*.pdf  binary
*.gz   binary
*.zip  binary
```

## 6. Standards update

**Accepted.** The Builder checked the Reviewer's update against the IETF datatracker: RFC 9989 is a Proposed Standard dated May 2026 and obsoletes RFC 7489 and RFC 9091. RFC 9990 (aggregate reporting) and RFC 9991 (failure reporting) were confirmed from secondary sources only.

The hub README and section 7 of the requirements file cite the current set, and cite RFC 7489 only to describe legacy receiver behavior.

One consequence is recorded now for any future project that steps a DMARC policy: RFC 9989 removed the `pct` tag, so a policy progression is not described or tested with it.

## 7. Record handling

- **Naming:** `BP<number>-R<round>-<role>.md`, following `secure-mail-platform`'s `S<section>-R<round>-<role>.md`.
- **R1** was a draft in conversation and was never submitted. R2 is the first committed round.
- **Rounds are committed as written.** A correction is a new file.
- **The R2 review as received contains export artifacts:** HTML entities, backslash line breaks, and favicon image links to third-party hosts. Those links are the six audit findings mentioned under B05. They are not the Reviewer's words. **Request:** the Reviewer supplies R2 again, and all later rounds, as plain Markdown without embedded links to icons, so the record can be committed unedited.

## 8. Sequence after R3

Nothing below is authorized by this document. Each step needs the Operator's approval.

1. The Reviewer rules on R3.
2. **Commit candidate.** The Builder produces every scaffold file in full, exactly as section 3 and B05 describe, and runs the whole gate on it in a sandbox. The Reviewer checks the candidate for conformance to the accepted R3. This is a conformance check, not a second design review.
3. **Creation and first commit**, in WSL: the N07 identity checks; the empty private repository; a deny-list in place in the working copy; `ignore-control.sh`; hooks installed; the Operator's reading of the staged diff; the first commit; CI passing.
4. **Publication review** (N01), then the Operator's decision on visibility.
5. `secure-mail-platform` adds a link back to the hub, through its own process, only after the hub is public.

## 9. Rulings requested

1. The index hub in place of the four-folder layout (section 1).
2. Closure of B02 and B03 by relocation to the project requirements file, given the hub holds no evidence.
3. Withdrawal of B04.
4. The deny-by-default `.gitignore` as a deliberate difference from the portfolio's block-list convention.
5. Closure of B01 and B05 on the material in section 4.
6. Resupply of the R2 review as plain Markdown (section 7).
