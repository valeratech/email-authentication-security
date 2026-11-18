# BP-001 R5: Builder correction to the sensitive-content audit

| | |
|---|---|
| Responds to | Reviewer ruling on BP-001 R4 (2026-11-17), disposition **REVISE: B01 closed, B05 open** |
| From → To | Builder (Claude) → Reviewer |
| Date | 2026-11-17 |
| Requests | Closure of B05a, B05b and B05c; a conformance ruling on the corrected candidate |
| Authorizes | Nothing. Repository creation, the first commit and publication each need the Operator's separate approval |
| Delivered with | The candidate archive (21 files, this one included), the test harness `candidate-tests.sh`, and its transcript |
| Filed as | `reviews/BP001-R05-builder.md` |

One consolidated round, as the ruling asked. The architecture, the path gate and every earlier review record are preserved. `scripts/check-paths.sh` is byte-identical to R4.

---

## 1. Dispositions

| Finding | Disposition | Builder's own measurement before changing anything |
|---|---|---|
| B05a: a failed search passes as clean | **Accepted** | Reproduced. With the address search made to fail, the R4 audit exited 0 on a file it otherwise rejects. The deny-list search behaved the same way |
| B05b: binary content, and a hook that does not always run | **Accepted** | The configuration defect is real, including for the deletion-only commit the ruling names: see 1.2 |
| B05c: no IPv6 coverage | **Accepted** | Reproduced. A unique-local address passed the R4 audit |

### 1.1 Builder correction to R4

R4 section 4 said that every Git call in both scripts was checked. That was true of the two path scripts and I let it stand for the gate as a whole. It was not true of the audit, which piped `grep` into loops and never looked at its exit status. The nine error tests in R4 covered the path scripts only, as the ruling says.

### 1.2 What I measured for B05b

The ruling identified the hook defect by inspection and said so. I ran it through real hooks under the R4 settings:

- **A binary file under an approved review name was still audited and rejected.** pre-commit decides whether a file is text from its extension before it looks at content, so a binary named `.md` counted as text. For the names the manifest allows, the filter did not let binary content through.
- **The hook did not run on every commit, and that was a real gap.** With the deny-list removed, an empty commit and a deletion-only commit were both accepted: no file matched the filter, so the audit never ran and never noticed the list was missing. Harness tests T8.30 and T8.34 fail against the R4 hook settings and pass now.
- **The R4 hook audited only the files a commit changed.** A new deny-list term was therefore never checked against files already committed.

The correction is the one the ruling required, whatever the measurement.

### 1.3 Further defects found while reproducing these

Same class as B05a. None was raised in the ruling; all are corrected here.

| Defect in the R4 audit | Effect |
|---|---|
| If `file` failed, the file was treated as text | A binary passed as clean, exit 0 |
| A run containing only binary files exited 2, not 1 | Still a failure, but reported as "nothing to check" instead of as a finding |
| A path named on the command line that did not exist was skipped | A mistyped path was silently not audited |
| A deny-list saved with Windows line endings kept a carriage return on every term | No term could match. Likely on a WSL machine |
| Files were searched with grep's binary-skipping option, in the caller's locale | A text file in a legacy encoding could be skipped without a finding |

## 2. The corrections

All in `scripts/audit-sanitize.sh`, rewritten around one rule: **the audit exits 0 only if every step ran.** The detection patterns and the approved values are unchanged except where B05c adds to them.

### 2.1 B05a: operational failures

- **Every content search goes through one function.** It accepts grep exit 0 (matches) and 1 (no matches). Anything else stops the audit with exit 2. That includes a file grep cannot read.
- **Nothing is piped into a loop any more.** Each search writes to a scratch file, its exit status is checked, and only then are the results read. Second-stage filtering that used further `grep`, `cut`, `tr` and `sort` processes is done inside the shell, so those failure points no longer exist.
- **Every other external call is checked:** `file`, `tr`, `cmp`, `mktemp`, and each Git command.
- **Inputs are checked:** a named path that does not exist is an error; an unreadable file is an error; a deny-list that is missing, unreadable or empty is an error.
- **The allowlist is read once into memory,** so approving a value no longer starts a process that could fail.
- **Bytes, not characters.** The audit runs in the C locale and treats every file it searches as text, so no file is skipped because of its encoding.

### 2.2 B05b: binary content and the hook

- **Two independent binary tests.** A file is binary if `file` reports a binary character set **or** it contains a NUL byte. Either alone is enough. If `file` fails or prints something unrecognisable, the audit exits 2.
- **Binary content is a finding (exit 1),** reported as `binary-committed`, in every mode.
- **The hook is unconditional.** `always_run: true`, `pass_filenames: false`, and no `types` filter. The audit decides what is text; pre-commit no longer does.
- **The hook audits the staged content of the whole index.** A new mode, `--staged`, exports the index to a scratch directory and reads the files there. It does not depend on pre-commit's stashing, and a clean working copy cannot hide a staged value. Symbolic links and submodule entries in the index are findings.
- **An empty commit and a deletion-only commit are audited** like any other.
- **The README's claim about images is corrected,** as the ruling required. R4 said that because no image is in the manifest, none can be committed. The manifest controls names, not content. The README now says that the audit rejects binary content, images included, whatever the file is called.

### 2.3 B05c: IPv6

- Every token that parses as an IPv6 literal is classified. The parser handles `::` compression, upper case, eight-group forms, brackets with a port, a prefix length, and a dotted IPv4 tail.
- **Approved:** the unspecified address `::`, loopback `::1`, and the RFC 3849 documentation prefix `2001:db8::/32`. This matches section 5 of the requirements file.
- **Everything else is a finding** (`unapproved-ipv6`): unique-local, link-local, global unicast, and IPv4-mapped forms.
- Times such as `12:53:01` and MAC addresses do not parse as IPv6 and are not flagged by this check.

### 2.4 Limits, stated plainly

- **Deny-list case folding is ASCII only.** A term containing accented or non-Latin letters matches only in the exact case it was written.
- **The IPv6 check is strict.** Any token of hexadecimal digits and colons that parses as an address is flagged unless approved. A false positive is resolved by a reasoned entry in `.audit-allow`, which is reviewed.
- **`file` calls some very small files binary:** a file of one byte, or of a single newline. They are rejected. An empty file is accepted as text with nothing to search.
- **The audit that runs is the working copy of the script,** with the working copy of the deny-list. In `--staged` mode the approvals come from the staged `.audit-allow`.
- **A binary file is rejected, not searched.** Its content is not examined further.

### 2.5 Other items in the full R04 ruling

| Item in the ruling | Response |
|---|---|
| B05a: deny-list reads must fail closed | A failure to read the deny-list or the allowlist, not only to find it, now stops the audit with exit 2 |
| B05c: compressed and expanded forms | Group 7 rejects a fully expanded unique-local address; the known-good file holds a fully expanded documentation address |
| B05c: no false positives on Markdown and review records | The whole candidate, all six review records included, audits clean. Times, MAC addresses and double colons between words are not flagged |
| Section 5: manual inspection in the operational checklist | Added to the README's command block: read `git diff --cached` and the commit message before every commit, whatever the tools report |
| Section 5: tie the history-scan proof to the scanned scope | Acknowledged, without a change to `ci.yml`. The CI log already prints the number of commits reachable from all refs, and Gitleaks prints the number it scanned, in the same job. A strict equality check is not added: Gitleaks may count merge commits differently, and a check that fails on a correct history would train people to ignore it. The two numbers are compared by eye in the post-push review |
| Section 5: version tags and gate files are not trust anchors | Acknowledged. Gate changes stay subject to review |
| Section 6: do not substitute a system hook silently | The harness substitutes only when told to, and prints a NOTE when it does. The Operator's WSL run uses the upstream hook |
| Section 2: no separate original of the R2 Builder file | The file in the candidate is byte-identical to the copy saved in the Operator's project when R2 was sent, SHA-256 `7ff2c4316913c7b9aa8e9e9b7c980cc8c56108094164257d731c827d01bcac00`. That is a Builder-side record, not independent evidence |

## 3. The controls

### 3.1 `scripts/negative-control.sh`: 104 checks, 36 of them injected failures

Runs in CI. Ten groups: groups 7 to 10 are new, and groups 1, 5 and 6 are extended.

| Group | What it proves |
|---|---|
| 1 to 4 | As in R4: known-bad rejected, values withheld, known-good accepted, the marker's scope. Group 1 adds a text file in a legacy encoding, audited from a UTF-8 locale: the R4 audit skipped it and exited 0 |
| 5 | The deny-list, now including a list saved with Windows line endings and stray blanks |
| 6 | An audit of nothing is an error, and so is a missing path beside a good one |
| 7 | **IPv6.** Nine addresses, one per file, each rejected by the IPv6 check and none repeated in the output: unique-local compressed and fully expanded, upper case, link-local, global, eight groups, bracketed with a port, IPv4-mapped, and one digit off the documentation prefix. The known-good file holds the documentation prefix in four spellings including fully expanded, `::1`, `::`, a time and a double colon between words |
| 8 | **Binary content** under an approved-looking name: with a NUL byte, and without one. With `file` replaced by one that calls everything text, the NUL check still catches it. Unrecognisable output from `file` is exit 2. An unreadable file is exit 2 |
| 9 | **Staged content.** A value staged and then removed from the working copy: the working-copy audit sees nothing, `--staged` rejects it. A symbolic link and a submodule entry in the index are each reported |
| 10 | **Failure injection.** For `grep`, `file`, `tr`, `cmp` and `git` in turn: count the calls a normal run makes, then run again once per call, failing a different call each time. Every run must exit 2. Done for an input with findings and for a clean one, and for the staged and working-copy modes |

Group 10 is exhaustive for the inputs it uses: there is no call to those five tools that it does not fail once. The unreadable-file control needs an ordinary user, because root can read anything. As root the script skips it and says so; as an ordinary user the count is 106.

### 3.2 Harness additions

| Tests | What they prove |
|---|---|
| T6S.1 to T6S.7 | **The negative control can fail.** Seven copies of the audit, each with one correction undone (a failed search ignored, a failed export ignored, the NUL check removed, the `file` verdict ignored, the IPv6 check disabled, the approved prefix widened, the deny-list made case-sensitive). The negative control exits 1 on every one |
| T6R.1 to T6R.4 | **The Reviewer's four B05a measurements, repeated.** Results now: 1, 2, 1, 2 |
| T6R.5, T6R.6 | The same pair for IPv6: a unique-local address exits 1; with the IPv6 search failing, 2 |
| T6U.1 | The negative control run as an unprivileged user, so the unreadable-file control runs |
| T8.23 to T8.25 | **Real hook, B05b:** binary content under an approved review name. The path gate accepts the name; the commit is rejected by the audit hook as `binary-committed` |
| T8.26 to T8.29 | **Real hook, B05c:** an IPv6 address staged and then removed from the working copy. The commit is rejected, and the address is not repeated in the output. Audited directly, the working copies are clean and the staged content is not |
| T8.30 to T8.32 | **Real hook, B05b:** an empty commit without a deny-list is rejected, so the audit ran. With the list back, the same commit is accepted |
| T8.33 to T8.36 | **Real hook, B05b:** a deletion-only commit without a deny-list is rejected. With the list back, the same deletion is accepted |

## 4. What changed since R4

| File | Change |
|---|---|
| `scripts/audit-sanitize.sh` | Rewritten as sections 2.1 to 2.3 and 2.5 describe |
| `scripts/negative-control.sh` | Groups 1, 5 and 6 extended; groups 7 to 10 added |
| `.pre-commit-config.yaml` | The audit hook: `--staged`, `always_run: true`, `pass_filenames: false`, no `types` filter. One comment reworded. Nothing else |
| `scripts/ignore-control.sh` | Two lines: the R05 rounds added to its approved list, which is now 22 paths and 94 checks. No logic changed |
| `README.md` | "Commit gates" only: the audit's description; the command block, now with the manual inspection step; the corrected image claim; one line in the list of differences from `WORKFLOW.md` |
| `reviews/README.md` | Two rows and one note |
| `reviews/BP001-R04-reviewer.md` | Added, as the Reviewer supplied it |
| `reviews/BP001-R05-builder.md` | This document |

Byte-identical to R4, and verifiable against the R4 inventory: `scripts/check-paths.sh`, `.gitignore`, `.gitattributes`, `.gitleaks.toml`, `.audit-allow`, `.github/workflows/ci.yml`, `SECURITY.md`, `docs/project-repository-requirements.md`, and the five earlier rounds.

`ci.yml` needed no change: it already runs the negative control and the audit over every tracked file, and both now carry the corrections.

## 5. Test results

**109 expectations checked, 109 met, none skipped.** The transcript is delivered with this round. Run by the Builder in a sandbox on 2026-11-17, as root. These are not the evidence of record: that is the Operator's run in WSL.

| Group | Tests | Result |
|---|---|---|
| T2 static checks | 2 | Met |
| T3 ignore control as delivered | 1 | PASS, 94 checks |
| T4 the ignore control can fail | 7 | Each sabotaged copy exits 1 |
| T5 errors fail the path scripts | 9 | Each exits 2 |
| T6 audit negative control | 2 | PASS, 104 checks; fails when the audit is a stub |
| T6S the negative control can fail | 7 | Each weakened audit makes it exit 1 |
| T6R the Reviewer's measurements, repeated | 6 | 1, 2, 1, 2, and 1, 2 for IPv6 |
| T6U unprivileged run | 2 | PASS; the unreadable-file control ran |
| T7 first commit through real hooks | 5 | All fourteen hooks pass; 21 files committed; byte-identical |
| T8 real hooks reject violations | 54 | Twelve violations rejected; four control commits accepted; HEAD never moved on a rejection |
| T9 CI commands in a fresh clone | 12 | All nine steps exit 0; side-branch violations caught |
| T10 shallow clone | 2 | Refused |

The harness now reports a missing tool instead of failing on it: it skips the tests that need the tool, names them, and exits 3 so that a partial run cannot be read as a full pass. Without pre-commit, Gitleaks and ShellCheck it runs T2.2 to T6R and reports T2.1 and T7 to T11 as not run; I ran it that way, as root and without `setpriv`, and it exited 3 with 33 met and three skipped.

### What was not tested

Unchanged from R4, and accepted as conditional in the R04 ruling:

- **The upstream Gitleaks hook was not built.** The sandbox cannot reach the Go module proxy. The hook's own entry command at the pinned version was run with the 8.21.2 release binary instead. Every other hook ran exactly as the candidate configures it.
- **GitHub Actions did not run.** The workflow's commands ran locally; the steps that use `sudo` were not executed as root.
- **The README's post-push confirmation was not run.**
- **WSL was not tested,** and no real deny-list was used.

## 6. Candidate inventory

Twenty files, with this document as the twenty-first. SHA-256 of each as delivered:

| Path | Mode | SHA-256 |
|---|---|---|
| `.audit-allow` | 100644 | `3a8cd6cf283b4c528d6642e9bada38623027690a19768eaf5eb10dff0a5adc5d` |
| `.gitattributes` | 100644 | `af4d0bbb07094bc0841ce1c31210555381d559a6dda0d9fc5043cf0127088221` |
| `.github/workflows/ci.yml` | 100644 | `0cc9fcb5eef745db15b3871433c08049d0bb245e156c433954c8bfe031d68149` |
| `.gitignore` | 100644 | `ba5a90386d05f01a39b864bb05b7544b6efc9101830d84683faf78044d391373` |
| `.gitleaks.toml` | 100644 | `8bc79bdcf813bfeae64b274e93d6d955bfde1e49b759fb9c5d4e4c2ea3a50b45` |
| `.pre-commit-config.yaml` | 100644 | `deae79831cc14359e577b3b3ff8a886dd114134d279a5f499ba08e053aa04f16` |
| `README.md` | 100644 | `aaeca7a8b1cd08197d7c33c8184747c41e7bdb2aa58081f41c40e18aeb53df46` |
| `SECURITY.md` | 100644 | `272e5083beb03aea024cfc8936cd7c155eec802bf42ad9db5782baadd09930b1` |
| `docs/project-repository-requirements.md` | 100644 | `752df0d4cc12c4056ba6d114b29d05d12396444b723b59caf6dcb2d64321eabb` |
| `reviews/BP001-R02-builder.md` | 100644 | `7ff2c4316913c7b9aa8e9e9b7c980cc8c56108094164257d731c827d01bcac00` |
| `reviews/BP001-R02-reviewer.md` | 100644 | `c662c3490e9e0e643b575e6e59890fe0f942c9307de0fb496334744c1458a3e6` |
| `reviews/BP001-R03-builder.md` | 100644 | `f96e03b87d3b519ec792f048921a3eb4b3213e5bfce73ca49123f3fbfcfa40cf` |
| `reviews/BP001-R03-reviewer.md` | 100644 | `0f61d4e07028f73ed1dd93222bd215ad2562420031dac5ead35e70d0c7724d8c` |
| `reviews/BP001-R04-builder.md` | 100644 | `2fb320c5e94e6986847f97d404f24da1cb704e0f8700312c753cc594319797cb` |
| `reviews/BP001-R04-reviewer.md` | 100644 | `9871a69175bbf97b4c2690bf1957bb19ff13a83c00efba298efc62e731573046` |
| `reviews/README.md` | 100644 | `da455b017b249d36372ff912ca0f9e033f9b47d40847ac998c5c737c60a5a445` |
| `scripts/audit-sanitize.sh` | 100755 | `99dca46ba82cff25595e2208a94bb5f61b0766fdf4c22068751d9c65801894b1` |
| `scripts/check-paths.sh` | 100755 | `34c65f6c30801ad022f3923bfe0814f71fd03bc2bffd85a8ee5be3051d073e7a` |
| `scripts/ignore-control.sh` | 100755 | `50bbd23707e563cfa0ac1b7fb75c0c6606d807c88478e45f8d286a0665d40f18` |
| `scripts/negative-control.sh` | 100755 | `8ce67217557999626fecc6b1308432d5a086c8bcf2157fae4330abb62b47de30` |

Pinned versions in the gate files are unchanged from R4.

## 7. Rulings requested

1. Closure of B05a on sections 2.1, 3 and 5.
2. Closure of B05b on sections 1.2, 2.2, 3 and 5.
3. Closure of B05c on sections 2.3, 3 and 5.
4. Conformance of the twenty-one files to the accepted design.

Nothing is created, committed or pushed on the strength of this document.
