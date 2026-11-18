# email-authentication-security

Index of my email authentication and email security projects. Each project is a separate
repository with its own scope, build history and review record. This repository is the
map: it links to the projects, reports their status, and holds the requirements every
project listed here has to meet.

**Everything linked from here is lab and portfolio work.** None of it is production, paid
or employer work, and nothing here claims compliance or certification. No employer or
production configuration, customer data or internal procedure appears in this repository
or in any project it lists.

## Projects

| Project | Scope | Environment | Status |
|---|---|---|---|
| [secure-mail-platform](https://github.com/valeratech/secure-mail-platform) | A mail platform built by hand: Postfix, Dovecot, rspamd, MariaDB virtual users, Roundcube, BIND and a private CA, with SPF, DKIM and DMARC verified by cases that must fail as well as cases that must pass. Thirteen sections, each proposed, reviewed and accepted before the next begins | An isolated VMware Workstation lab on reserved `.test` names. No registered domain, and no mail to or from the Internet | **In progress.** Section 1 (architecture and scope): accepted. Section 2 (VMware environment and base OS): in progress. Sections 3 to 13: no state recorded yet. Read from the project's Status table at commit [`ab45a87`](https://github.com/valeratech/secure-mail-platform/blob/ab45a87108cc29321d6ab2440d1001cb5016e6d4/README.md#status) |

The Scope column is what a project sets out to build. The Status column is what has been
built and accepted so far.

**Status is copied, never inferred.** Each status here is transcribed from the project's
own Status table at the commit named beside it. This index never states more progress
than the project's own record does, and a project being public does not mean it is
finished.

This index is the primary listing for `secure-mail-platform`. The project is also listed
in [linux-infrastructure-portfolio](https://github.com/valeratech/linux-infrastructure-portfolio),
as a Linux build. It has one home, its own repository; neither index holds a copy of it.

## Professional background

My professional background is described at [ryanvalera.com](https://ryanvalera.com). The
projects listed here are separate from it. They are built in a lab, on my own equipment,
so that the work and the reasoning behind it can be shown in full.

## How a project joins this index

A project is listed only once it is official, and it is listed as **planned** until
something in it has been built and verified.

Every project has its own repository, its own scope file and its own Builder/Reviewer
record, and meets [the project repository requirements](docs/project-repository-requirements.md)
in its first section: commit gates, evidence custody, masking that keeps the evidence
true, and honest verification. `secure-mail-platform` predates that file and is governed
by its own accepted record.

## Standards cited

| Subject | RFC |
|---|---|
| SPF | RFC 7208 |
| DKIM | RFC 6376 |
| DMARC | RFC 9989, which obsoletes RFC 7489 and RFC 9091 |
| DMARC aggregate reporting | RFC 9990 |
| DMARC failure reporting | RFC 9991 |
| MTA-STS | RFC 8461 |
| SMTP TLS reporting | RFC 8460 |
| Documentation addresses and names | RFC 5737, RFC 3849, RFC 2606 |

RFC 7489 is cited only to describe how an existing implementation behaves. Which
specification a given implementation follows is recorded in the project that uses it.

## How this repository is governed

Every change is proposed by a **Builder**, assessed by an independent **Reviewer**, and
approved by me before it is made. Each round is committed as written, corrections
included, in [reviews/](reviews/). See [reviews/README.md](reviews/README.md) for the
protocol and the record.

## Commit gates

Four layers, each catching a different failure:

1. **Redact at the source.** Write clean from the start: documentation addresses,
   reserved names, no real values. The gates below are backstops, not the control.
2. **Sensitive-content audit.** [scripts/audit-sanitize.sh](scripts/audit-sanitize.sh)
   classifies IPv4 and IPv6 addresses, domains, email addresses, home paths, credentials
   and key material, rejects binary content, and checks a deny-list of employer, customer
   and production strings. The deny-list is git-ignored, because a committed list of
   things that must never be committed is itself the leak. Without it the local audit
   fails rather than passes. So does a search that errors: the audit reports clean only
   when every search ran.
3. **Pre-commit hooks.** Gitleaks, private-key detection, the audit, and the path gate
   described below. The audit and the path gate run on every commit, whatever it touches,
   and read the staged content itself, not the working copy. A failing hook blocks the
   commit.
4. **CI.** Gitleaks over the full history of every pushed ref and over the checked-out
   files, the audit, the path gate over every commit, a refusal of merge commits, and the
   controls that prove each gate can still fail.

**The path gate.** This repository holds a small, fixed set of files.
[.gitignore](.gitignore) ignores everything else by default, which prevents accidents.
It is not what enforces the set: `git add -f` overrides an ignore rule, and so does a
`.gitignore` placed inside a folder. [scripts/check-paths.sh](scripts/check-paths.sh)
enforces it. It reads the index and compares every entry with a manifest written in the
script, consulting no ignore rule. Adding a file here means adding it to that manifest in
a reviewed change. [scripts/ignore-control.sh](scripts/ignore-control.sh) proves both,
including the cases the ignore rules cannot stop.

```bash
pre-commit install                            # once
git add -A
git diff --cached                             # read every staged change yourself
./scripts/audit-sanitize.sh --staged          # the same audit the hook runs
pre-commit run --all-files
```

Reading the staged changes, and the commit message, is part of every commit, whatever
the tools report. The tools are backstops for that reading, not a replacement for it.

After a push, confirm the CI run for that exact commit:

```bash
git push && sleep 5
SHA=$(git log --oneline -1 | cut -d' ' -f1)
RUN=$(gh run list -L5 --json databaseId,headSha \
      -q ".[] | select(.headSha|startswith(\"$SHA\")) | .databaseId")
gh run watch "$RUN" --exit-status \
  && gh run view "$RUN" --log | grep -Ei '([0-9]+ commits? scanned|scanned [0-9]+ commits?)'
```

**Known limits.**

- Local hooks can be skipped with `--no-verify`. CI repeats the checks server-side.
- CI cannot see the deny-list, so deny-listed terms are checked only on my machine.
- Gitleaks' history scan does not examine what a merge commit itself introduces, such as
  a conflict resolution. The history is therefore kept linear: CI fails if any merge
  commit exists, and it also scans the checked-out files.
- CI runs after a push has landed. A CI failure does not undo the push; it means the
  pushed content is remediated before anything else happens. See [SECURITY.md](SECURITY.md).

**Where this comes from.** The gates are adapted from the commit workflow of my Linux
infrastructure portfolio:
[WORKFLOW.md at commit `0b8c520`](https://github.com/valeratech/linux-infrastructure-portfolio/blob/0b8c52068aa300d3405d22ca70c60277b521186d/WORKFLOW.md).
That link is credit, not a dependency: everything needed to follow the gates is written
above. This repository differs from that workflow in these ways:

- `.gitignore` denies by default, because an index holds a fixed set of files.
- The path gate is added. The source workflow has no equivalent.
- The audit approves no lab subnet. This index publishes no lab addresses, so any private
  address is a finding, IPv6 included. It audits the staged content on every commit,
  treats binary content as a finding, withholds matched values from its output unless
  asked, and treats a missing deny-list or a failed search as an error.
- The CI confirmation uses `gh run watch --exit-status`, so a failed run fails the step,
  and a commit-count match that fits the output of the pinned Gitleaks version.
- There is no image allowlist. The audit rejects binary content, images included,
  whatever the file is called: a binary file under an approved name is still rejected.
  The manifest also admits no image path.
- The authoring steps for lab configuration and lab write-ups do not apply. This
  repository holds neither.
