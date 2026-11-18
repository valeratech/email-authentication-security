# BP-001 R4: Builder correction and commit candidate

| | |
|---|---|
| Responds to | Reviewer ruling on BP-001 R3 (2026-11-17), disposition **REVISE, limited to B01 and B05** |
| From → To | Builder (Claude) → Reviewer |
| Date | 2026-11-17 |
| Requests | Closure of B01 and B05; a conformance ruling on the commit candidate |
| Authorizes | Nothing. Repository creation, the first commit and publication each need the Operator's separate approval |
| Delivered with | The candidate archive (19 files, this one included), the test harness `candidate-tests.sh`, and its transcript |
| Filed as | `reviews/BP001-R04-builder.md` |

The Reviewer recommended combining the bounded correction with the full commit candidate. The Operator approved that. This round is both.

---

## 1. Builder correction to R3

R3 section 4.1 said that subdirectories stay ignored. **That was wrong.** The Reviewer's two additional controls are correct, and I reproduced both with Git 2.43.0 before changing anything:

- A directory named like an approved file (`README.md/`, `docs/nested.md/`) was admitted with everything inside it.
- A `.gitignore` placed inside `docs/` admitted a file the root rules prohibit.

In both cases `git add -A` staged the file and the tracked-but-ignored check printed nothing.

Why my control missed it: it planted files only, never a directory with a file-like name, and it tested the ignore rules with a check that depended on the same ignore rules. R3 section 4.5 called that check "the enforcement". It could not be.

## 2. Operator decisions since R3

| Decision | Effect on this round |
|---|---|
| One combined handoff | This document plus the complete candidate |
| Two indexes, one project | This index is the primary listing for `secure-mail-platform`. The Linux infrastructure portfolio keeps it as a secondary listing. The project has one home, its own repository. The README says so |
| Gate convention | Adapted from the Linux portfolio's `WORKFLOW.md` and `templates/`, pinned to commit `0b8c520`. The README describes the gates in full, so the link is credit, not a dependency, and it lists every difference |

**`WORKFLOW.md` is resolved.** R3 said I had not read it. It lives in `valeratech/linux-infrastructure-portfolio`, was added in commit `897445f`, and is unchanged through `0b8c520`. I read it there, together with `templates/`. That repository's own thread confirmed two defects in its section 7 confirmation step and owns the fix; this candidate uses the corrected forms and says so.

## 3. B01: the correction

### 3.1 Ignore rules

Deny-by-default is kept. After each re-inclusion the rules now ignore directories again: one line per approved top-level file (`/README.md/`), and one line per approved folder (`/docs/*/`). A directory can no longer pass as an approved file.

The rules still cannot stop a nested `.gitignore` or `git add -f`. Nothing written in a `.gitignore` can. They prevent accidents, and the README and the file's own header now say exactly that.

### 3.2 The path gate: `scripts/check-paths.sh`

This is the independent check the ruling asked for.

- **What it reads:** the index (`git ls-files -s`), so it sees what is staged and tracked, not the working tree. With `--history` it reads the tree of every commit reachable from any ref.
- **What decides:** a manifest written in the script. It consults no `.gitignore`, no exclude file and no ignore setting.
- **What passes:** fourteen exact paths, plus review rounds matching `reviews/BP<3 digits>-R<2 digits>-(builder|reviewer).md`. A review round must be a direct child of `reviews/`.
- **Types:** each path has a required mode. Scripts must be `100755`; everything else `100644`. A symlink (`120000`) or a gitlink (`160000`) can never pass, even at an approved path.
- **Errors:** exit 2 if Git fails, if there is nothing to check, or if `--history` is run on a shallow clone. Exit 2 is a failure.
- **Defense in depth:** the tracked-but-ignored check is kept inside the same script. It can add a rejection. It never allows anything.

The gate runs as a pre-commit hook and in CI, where it also runs over every commit. It is not a new layer: it is one more hook in layer three and one more step in layer four.

### 3.3 Limits of the path gate

- **The manifest lives in the repository it guards.** A commit that edits the manifest and adds a file passes. That is intended: the change is in the diff, and review is the control. The gate stops accidents and unreviewed additions. It does not replace review.
- **The two layers are deliberately different.** `.gitignore` admits any `.md` file directly inside `docs/`; the manifest admits one named file there. The gate is the stricter of the two, and the gate is what a commit has to pass.

### 3.4 The control: `scripts/ignore-control.sh`

Rewritten. Seven scenarios, each in its own scratch repository, 92 checks in total:

| Scenario | What it proves |
|---|---|
| S1 | The rules in both directions: 40 prohibited paths ignored, 20 approved paths trackable, `git add -A` stages exactly the approved set, the gate passes it |
| S2 | Nine directory cases, the Reviewer's five included, are ignored with their contents; forced in, the gate rejects them |
| S3 | A nested `.gitignore` does admit a prohibited file; the gate rejects it anyway |
| S4 | A force-added ignored file, and a force-added deny-list, are rejected |
| S5 | Approved paths with the wrong type or mode are rejected: symlink, gitlink, stray executable bit, missing executable bit |
| S6 | A prohibited entry that exists only in the index, deleted from the working tree, is rejected |
| S7 | A prohibited file committed and then deleted passes the index check and fails the history check |

The approved list is now the real inventory: all nineteen candidate files plus one future review round.

## 4. B05: integration, against each item in the ruling

Test numbers refer to the transcript.

| The ruling asked for | What the candidate does | Evidence |
|---|---|---|
| The gate examines staged content and staged paths, with a staged-only negative control | The path gate reads the index. pre-commit stashes unstaged changes before running hooks, so the audit and Gitleaks see staged content. Two staged-only controls: a bad address and a key shape, each staged and then removed from the working copy | T8.1 to T8.5; S6 |
| Scratch repositories independent of the parent Git environment | The control unsets every variable Git lists as repository-local, ignores user and system configuration, and uses an empty home directory | T7.3 (inside a real hook), T8.20 to T8.22 (hostile environment aimed at the real repository; its index and HEAD unchanged) |
| Setup and Git failures fail the gate | Every Git call in both scripts is checked. `git check-ignore` distinguishes "not ignored" from "failed" | T5.1 to T5.9: nine error conditions, each exits 2 |
| Deny-list present and readable, untracked, never printed | The local audit exits 2 without a readable, non-empty deny-list. Matching is case-insensitive. The term is never echoed. The deny-list is not in the manifest, so it cannot be committed | T8.6, T8.9a, T8.16; negative control group 5 |
| CI's lack of a deny-list is documented, not treated as coverage | CI passes `--no-denylist` explicitly, and the audit prints that the deny-list was not checked. Stated in the README, in `SECURITY.md` and in the workflow file | T9.05 |
| Negative control rejects planted values; the clean case passes | `negative-control.sh`, 17 checks | T6.1; T6.2 shows it fails when the audit is replaced by a stub |
| The path check rejects the new bypass cases | S2, S3, and the same cases through a real commit | T3.1, T8.10 to T8.15 |
| A real hook invocation rejects a synthetic violation | Eight different violations, each through `git commit` with the hooks installed; each is rejected and HEAD does not move | T8.2 to T8.17 |
| CI runs the declared checks and fails on errors | Every `run` block is taken from the workflow file and executed with `bash -e` in a fresh clone | T9.01 to T9.09 |
| CI scans full history, not a shallow checkout | `fetch-depth: 0`, a step that refuses a shallow clone, and a proof line that commits were scanned. A violation committed only on a side branch is caught by both history checks | T9.01, T9.03, T9.10, T9.12, T10.1, T10.2 |
| A later CI failure does not prevent a completed push | Stated in the workflow file, the README and `SECURITY.md`: CI detects after the push; the response is remediation | Documents |
| Exemptions are narrow and reviewed | The marker is honoured in four named files only, listed in the audit script. Elsewhere it has no effect. A deny-listed term is never exempt. Each run prints how many lines the marker exempted and where: 17 lines in 4 files today | Negative control groups 4 and 5 |
| The gate does not require exposing a value in a review or log | The audit withholds matched values unless run locally with `--show-values`. Gitleaks runs with `--redact` in the hook and in CI | T8.2, T8.4, T8.6 (output searched for the planted value); negative control group 2 |
| Complete staged inventory and gate-file versions | Section 7 below. `git add -A` staged exactly the nineteen files, and every committed file is byte-identical to the candidate | T7.2, T7.5, T11 |

## 5. Gate files: sources and every difference

Sources: the Linux portfolio's `templates/` at `0b8c520`, and `secure-mail-platform`'s working copies at `ab45a87`, which are the same files retuned for a mail platform. The candidate starts from the second.

| File | Differences from the source |
|---|---|
| `.gitleaks.toml` | Rules unchanged. Two allowlist entries removed (the lab namespace and the evidence folder), which only tightens it. Comment wording |
| `.pre-commit-config.yaml` | Removed: the lab-entry lint hook and the image-allowlist hook (no image is in the manifest, so none can be committed). Added: the path gate and the ignore control. The two whitespace fixers skip review rounds, because rounds are committed as written and the R02 review contains Markdown hard line breaks. Hook versions unchanged |
| `scripts/audit-sanitize.sh` | No lab subnet approved; the approved-domain list cut to documentation names and the hosts this index links to. **Beyond what R3 described**, each because of the R03 ruling: the deny-list is required; deny-list matching is case-insensitive and never exempt; the exemption marker is limited to named files and counted; matched values are withheld by default; options `--no-denylist`, `--denylist` and `--show-values` |
| `scripts/negative-control.sh` | The known-good line uses documentation values. Added controls for value withholding, the marker's scope, the deny-list, and the two error exits |
| `.github/workflows/ci.yml` | Runs on every pushed branch and tag, not only `main`. Added: shallow-clone refusal, a checksum check on the Gitleaks download, the commit-count proof, the path gate over the tree and over history, the ignore control. Removed: the lab-entry lint and the image step |
| `.gitignore`, `.gitattributes`, `.audit-allow`, `scripts/check-paths.sh`, `scripts/ignore-control.sh` | New for this repository |

Differences from `WORKFLOW.md` itself are listed at the end of the README.

## 6. Test results

**74 expectations checked, 74 met.** The transcript is delivered with this round. Run by the Builder in a sandbox on 2026-11-17. These are not the evidence of record: that is the Operator's run in WSL.

| Group | Tests | Result |
|---|---|---|
| T2 static checks | 2 | Met |
| T3 ignore control as delivered | 1 | PASS, 92 checks |
| T4 the ignore control can fail | 7 | Six sabotaged copies, each exits 1. The first uses the exact rules printed in R3 and fails at the directory scenario |
| T5 errors fail the gate | 9 | Each exits 2 |
| T6 audit negative control | 2 | PASS, 17 checks; fails when the audit is a stub |
| T7 first commit through real hooks | 5 | All fourteen hooks pass; nineteen files committed; byte-identical |
| T8 real hooks reject violations | 34 | Eight violations rejected; two control commits accepted; HEAD never moved on a rejection; a hostile Git environment left the repository unchanged |
| T9 CI commands in a fresh clone | 12 | All nine steps exit 0. A key shape and a prohibited file, each committed only on a side branch, are caught |
| T10 shallow clone | 2 | Refused |

Tools: Git 2.43.0, pre-commit 4.7.0, Gitleaks 8.21.2, shellcheck 0.11.0 for direct runs, Python 3.13.

### What was not tested, stated plainly

- **The upstream Gitleaks hook was not built.** pre-commit builds it with Go, and the sandbox cannot reach the Go module proxy. The hook's own entry command at the pinned version, `gitleaks protect --verbose --redact --staged`, was run instead with the 8.21.2 release binary, whose download matched the published SHA-256. Every other hook ran exactly as the candidate configures it. The harness runs the upstream hook unless told otherwise, so the Reviewer and the Operator can close this gap.
- **GitHub Actions did not run.** The workflow's commands ran locally. The two steps that use `sudo` were not executed as root: the Gitleaks download and its checksum check ran, the install did not; `apt-get` was skipped.
- **The README's post-push confirmation was not run.** It needs a GitHub repository. Its two corrections come from the `secure-mail-platform` thread, which reports having run them, and the Linux portfolio thread, which confirmed the defects.
- **WSL was not tested,** and no real deny-list was used. The tests use a synthetic one.

## 7. Candidate inventory

Eighteen files, with this document as the nineteenth. SHA-256 of each as delivered:

| Path | Mode | SHA-256 |
|---|---|---|
| `.audit-allow` | 100644 | `3a8cd6cf283b4c528d6642e9bada38623027690a19768eaf5eb10dff0a5adc5d` |
| `.gitattributes` | 100644 | `af4d0bbb07094bc0841ce1c31210555381d559a6dda0d9fc5043cf0127088221` |
| `.github/workflows/ci.yml` | 100644 | `0cc9fcb5eef745db15b3871433c08049d0bb245e156c433954c8bfe031d68149` |
| `.gitignore` | 100644 | `ba5a90386d05f01a39b864bb05b7544b6efc9101830d84683faf78044d391373` |
| `.gitleaks.toml` | 100644 | `8bc79bdcf813bfeae64b274e93d6d955bfde1e49b759fb9c5d4e4c2ea3a50b45` |
| `.pre-commit-config.yaml` | 100644 | `ca32528adaaf2ab4bb8a723c4760d1eeca13832229b0c8dd0ad3188566f0484e` |
| `README.md` | 100644 | `bc678aac7989a50b89bb7a91526d4394240539475d602e5ebeaff7cce147cfb3` |
| `SECURITY.md` | 100644 | `272e5083beb03aea024cfc8936cd7c155eec802bf42ad9db5782baadd09930b1` |
| `docs/project-repository-requirements.md` | 100644 | `752df0d4cc12c4056ba6d114b29d05d12396444b723b59caf6dcb2d64321eabb` |
| `reviews/BP001-R02-builder.md` | 100644 | `7ff2c4316913c7b9aa8e9e9b7c980cc8c56108094164257d731c827d01bcac00` |
| `reviews/BP001-R02-reviewer.md` | 100644 | `c662c3490e9e0e643b575e6e59890fe0f942c9307de0fb496334744c1458a3e6` |
| `reviews/BP001-R03-builder.md` | 100644 | `f96e03b87d3b519ec792f048921a3eb4b3213e5bfce73ca49123f3fbfcfa40cf` |
| `reviews/BP001-R03-reviewer.md` | 100644 | `0f61d4e07028f73ed1dd93222bd215ad2562420031dac5ead35e70d0c7724d8c` |
| `reviews/README.md` | 100644 | `4b757a6e57999943f57f4cc29e32d02e3a9472218f3c2c5f61a0152696cd16c9` |
| `scripts/audit-sanitize.sh` | 100755 | `de9b09c9727bef2c95a825f1fcd9e513622742d4f454de58a8ea86ed945608b0` |
| `scripts/check-paths.sh` | 100755 | `34c65f6c30801ad022f3923bfe0814f71fd03bc2bffd85a8ee5be3051d073e7a` |
| `scripts/ignore-control.sh` | 100755 | `670c1867dcb70da4b6ea4824ad1148f86d99c3ff16e0a3efaee2c7600b7f790d` |
| `scripts/negative-control.sh` | 100755 | `fe445789435353c01c90955c8dcd9af14ef0f56f344d26cfc3f8ded2b9bc7805` |

The four earlier rounds are byte-identical to what was exchanged. The Reviewer can compare the two reviewer files with the copies they supplied.

Pinned versions in the gate files: pre-commit-hooks `v5.0.0`; the Gitleaks hook and the CI download, both `8.21.2`; the shellcheck hook pin unchanged from the source; `actions/checkout@v5`, pinned by tag as in the source, not by commit.

## 8. Other dispositions from the R03 ruling

| Item | Where it is carried |
|---|---|
| B03 clarifications: the masking baseline, the narrow real-value exception, synthetic never presented as masked | `docs/project-repository-requirements.md` section 5, revision 3 |
| N01: bind the publication review to an exact commit, cover every public ref, check later commits too | `SECURITY.md`, "Before visibility changes" |
| N02: an identifier cannot be revoked | `SECURITY.md`, and section 8 of the requirements file |
| N07: verify author and committer before the first commit as well as after; keep the output locally | The creation step, which is not part of this round |
| Status transcribed from the project's table, with the source revision | README project table: read at `ab45a87`, where Section 2 is "In progress" |
| RFC 9989: the `t` tag is not a percentage rollout; implementations vary | Requirements file section 7, and the README's standards note |

## 9. Rulings requested

1. Closure of B01 on sections 3 and 6.
2. Closure of B05 on sections 4 to 6.
3. Whether the untested items in section 6 are acceptable for a conformance ruling, on condition that the Operator's WSL run with the upstream hook is the evidence of record.
4. Conformance of the nineteen files to the accepted design.

Nothing is created, committed or pushed on the strength of this document.
