# BP-001 R6: Builder correction to CI for merge commits

| | |
|---|---|
| Responds to | Reviewer ruling on BP-001 R5 (2026-11-17), disposition **ACCEPT** |
| From → To | Builder (Claude) → Reviewer |
| Date | 2026-11-17 |
| Requests | A ruling on one bounded CI correction, found after R5 was accepted |
| Authorizes | Nothing. Repository creation, the first commit and publication each need the Operator's separate approval |
| Delivered with | The candidate archive (23 files, this one included), the test harness `candidate-tests.sh`, and its transcript |
| Filed as | `reviews/BP001-R06-builder.md` |

The R05 ruling requested no further design round. This round exists because reconciling a number the ruling asked about produced a new measurement, and the Operator chose to correct it before qualification rather than record it as a limitation. It changes one workflow file and adds two lines of README text. Nothing accepted in R5 is reopened.

---

## 1. Reconciliation the R05 ruling asked for

The ruling noted that the R5 transcript shows five reachable commits and three commits scanned by Gitleaks, and asked that this be reconciled, not assumed.

**Measured, not assumed.** I committed one change at a time in a scratch repository and read Gitleaks 8.21.2's count after each commit:

| Commit added | Reachable | Counted by Gitleaks |
|---|---|---|
| Adds a text file | 1 | 1 |
| Empty | 2 | 1 |
| Removes one line of text | 3 | 2 |
| Modifies text | 4 | 3 |
| Deletes a file | 5 | 3 |
| Adds a binary file | 6 | 3 |
| Renames the binary file | 7 | 4 |
| A side-branch commit plus its merge commit | 11 | 7 (the merge is not counted) |

Gitleaks counts commits whose diff it parses as text changes. It does not count empty commits, deletion-only commits, commits that only add a binary, or merge commits. In the R5 transcript the two uncounted commits are the empty commit (T8.32) and the deletion-only commit (T8.36), so five reachable and three counted is the expected result for that history.

**Rule for the post-push review:** the scanned count is never more than the reachable count, and the difference is explained by the commits listed above. Both numbers are printed in the same CI job.

## 2. The new measurement

Checking whether merge commits are counted led to whether they are scanned. **They are not.** Gitleaks' history scan does not examine the changes a merge commit itself introduces.

In a scratch repository I resolved a merge conflict by adding a synthetic key shape, and committed the merge:

| Check | Result |
|---|---|
| `gitleaks git .`, the scan CI ran in R5 | **No leaks found** |
| `gitleaks dir .` on the checked-out files | Leak found |
| `gitleaks` over the merge commit's own diff against its first parent | Leak found |

The local layer covers this case: completing a conflicted merge runs the commit hooks, and the harness now shows the Gitleaks hook rejecting it (T8.38). A merge made where local hooks do not run, such as on GitHub's website, would pass CI's history scan with that content in it.

Nothing is exposed: the repository does not exist, and the intended history has no merges. The gap is in CI's full-history layer, which is the layer meant to catch what local hooks miss.

## 3. The correction

`.github/workflows/ci.yml`, job `secrets` only:

- **Refuse merge commits.** A new step fails if any commit reachable from any fetched ref is a merge. The hub's history is linear by design, so a merge commit is itself a finding. It prints the number of merges found.
- **Scan the checked-out files.** A new step runs `gitleaks dir .` after the history scan. It reads the working tree only, not `.git`; I confirmed that a key present only in history and in `.git` is not reported by it, so it does not duplicate the history scan's findings.
- **Check out the pull request's own commit.** GitHub tests a pull request on a merge commit it creates. Without this, the new step would fail every pull request. The checkout now uses the pull request's head commit, falling back to the pushed commit. The expression uses bracket syntax because the audit, correctly, reads dotted names such as GitHub context paths as hostnames and rejects them. The audit was not weakened to admit them.
- **The proof-of-scan comment** now states that Gitleaks' count can be lower than the reachable count, and why.
- The job's name now says it scans the checked-out files too.

`README.md`, "Commit gates" only: layer 4's description adds the checked-out file scan and the merge refusal, and the known limits gain one entry explaining why the history is kept linear.

### 3.1 Limits, stated plainly

- **Bracket-syntax expressions and the pull-request checkout were not executed on GitHub.** They parse as YAML. Whether GitHub evaluates the expression as intended on push and pull-request events is confirmed only by the first real runs.
- **Refusing merges is a policy, not a scan of merges.** If a merge is ever wanted, this step must be changed by a reviewed proposal, and merges would then need their own scan.
- **A merge on a branch that is never pushed is never seen by CI.** The local hooks cover merges made locally.

## 4. Tests

| Tests | What they prove |
|---|---|
| T8.37 to T8.39 | **Real hooks:** completing a conflicted merge with a key shape in the resolution is rejected by the Gitleaks hook, the key is not repeated in the output, and HEAD does not move |
| T9.02, T9.05 | The two new CI steps pass on the clean history |
| T9.23, T9.24 | A merge commit on any ref fails the merge refusal; with it removed, the step passes |
| T9.25 | **The gap, recorded as a test:** with a key shape added in a merge resolution, the history scan alone exits 0 |
| T9.26 | The checked-out file scan exits 1 on the same history, without repeating the key |
| T9.27 | The merge refusal also fails on it |

The side-branch tests from R4 are renumbered T9.20 to T9.22, because CI now has eleven steps. The synthetic future review round in T8 is renamed from R06 to R08, because this round's real file is R06.

**122 expectations checked, 122 met, none skipped.** Run by the Builder in a sandbox on 2026-11-17, as root, with the system Gitleaks hook as in R4 and R5. The deferred operational checks accepted in the R04 and R05 rulings are unchanged.

## 5. What changed since R5

| File | Change |
|---|---|
| `.github/workflows/ci.yml` | Section 3 |
| `README.md` | Section 3 |
| `reviews/README.md` | The R05 builder row updated; rows for the R05 ruling and this round |
| `scripts/ignore-control.sh` | Two lines: the R06 rounds added to its approved list (24 paths, 96 checks). No logic changed |
| `reviews/BP001-R05-reviewer.md` | Added, as the Reviewer supplied it |
| `reviews/BP001-R06-builder.md` | This document |

Byte-identical to R5: `scripts/audit-sanitize.sh`, `scripts/negative-control.sh`, `scripts/check-paths.sh`, `.gitignore`, `.gitattributes`, `.gitleaks.toml`, `.pre-commit-config.yaml`, `.audit-allow`, `SECURITY.md`, `docs/project-repository-requirements.md`, and the seven earlier rounds.

## 6. Candidate inventory

Twenty-two files, with this document as the twenty-third. SHA-256 of each as delivered:

| Path | Mode | SHA-256 |
|---|---|---|
| `.audit-allow` | 100644 | `3a8cd6cf283b4c528d6642e9bada38623027690a19768eaf5eb10dff0a5adc5d` |
| `.gitattributes` | 100644 | `af4d0bbb07094bc0841ce1c31210555381d559a6dda0d9fc5043cf0127088221` |
| `.github/workflows/ci.yml` | 100644 | `9ea99db06897535da49673964fbd62ccd80b9d563b20e1e03a8089b9cf516262` |
| `.gitignore` | 100644 | `ba5a90386d05f01a39b864bb05b7544b6efc9101830d84683faf78044d391373` |
| `.gitleaks.toml` | 100644 | `8bc79bdcf813bfeae64b274e93d6d955bfde1e49b759fb9c5d4e4c2ea3a50b45` |
| `.pre-commit-config.yaml` | 100644 | `deae79831cc14359e577b3b3ff8a886dd114134d279a5f499ba08e053aa04f16` |
| `README.md` | 100644 | `ff5ef36934aa8f02d703e289a6d000a0a67c5a035be3022563a335721393b74e` |
| `SECURITY.md` | 100644 | `272e5083beb03aea024cfc8936cd7c155eec802bf42ad9db5782baadd09930b1` |
| `docs/project-repository-requirements.md` | 100644 | `752df0d4cc12c4056ba6d114b29d05d12396444b723b59caf6dcb2d64321eabb` |
| `reviews/BP001-R02-builder.md` | 100644 | `7ff2c4316913c7b9aa8e9e9b7c980cc8c56108094164257d731c827d01bcac00` |
| `reviews/BP001-R02-reviewer.md` | 100644 | `c662c3490e9e0e643b575e6e59890fe0f942c9307de0fb496334744c1458a3e6` |
| `reviews/BP001-R03-builder.md` | 100644 | `f96e03b87d3b519ec792f048921a3eb4b3213e5bfce73ca49123f3fbfcfa40cf` |
| `reviews/BP001-R03-reviewer.md` | 100644 | `0f61d4e07028f73ed1dd93222bd215ad2562420031dac5ead35e70d0c7724d8c` |
| `reviews/BP001-R04-builder.md` | 100644 | `2fb320c5e94e6986847f97d404f24da1cb704e0f8700312c753cc594319797cb` |
| `reviews/BP001-R04-reviewer.md` | 100644 | `9871a69175bbf97b4c2690bf1957bb19ff13a83c00efba298efc62e731573046` |
| `reviews/BP001-R05-builder.md` | 100644 | `a980fba045ee0218e0861a675dc948f5d9da6ee755bb6b0b36f00a0bdc51c7d8` |
| `reviews/BP001-R05-reviewer.md` | 100644 | `b41e5397e974a57b04efedd7789dadbefe12b5f526e0be0500557f7c3d743e9d` |
| `reviews/README.md` | 100644 | `16534ec364ec8e00e2a90a871300549c73ded18270c80471520bbaf1b24d5c9f` |
| `scripts/audit-sanitize.sh` | 100755 | `99dca46ba82cff25595e2208a94bb5f61b0766fdf4c22068751d9c65801894b1` |
| `scripts/check-paths.sh` | 100755 | `34c65f6c30801ad022f3923bfe0814f71fd03bc2bffd85a8ee5be3051d073e7a` |
| `scripts/ignore-control.sh` | 100755 | `035184acdcbd599777f7425a6d806ee5c02023bbaaade426165108b974940489` |
| `scripts/negative-control.sh` | 100755 | `8ce67217557999626fecc6b1308432d5a086c8bcf2157fae4330abb62b47de30` |

## 7. Rulings requested

1. Acceptance of the CI correction in section 3.
2. Acceptance of the reconciliation in section 1.
3. Conformance of the twenty-three files.

Nothing is created, committed or pushed on the strength of this document.
