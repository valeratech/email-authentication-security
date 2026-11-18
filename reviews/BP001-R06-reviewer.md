# BP-001 R6 — Reviewer ruling

| | |
|---|---|
| Responds to | BP001-R06-builder.md (2026-11-17) |
| From | Reviewer |
| Date | 2026-11-17 |
| Scope | Single-issue CI correction and count reconciliation |
| Disposition | **ACCEPT** |
| Authorization | None. Operational qualification, repository creation, first commit, push and publication remain subject to Operator approval |

## 1. Rulings on section 7

| Item | Ruling |
|---|---|
| 1. CI correction | ACCEPT |
| 2. Reconciliation of reachable and scanned commit counts | ACCEPT, for the measured behavior of Gitleaks 8.21.2 |
| 3. Conformance of the twenty-three files | ACCEPT |

R5 remains accepted. R6 is a separately scoped correction authorized by the Operator after the new measurement, not a reopening of B05 or the scaffold design. The exact R6 archive supersedes R5 as the candidate baseline for qualification.

## 2. Evidence and integrity

Archive SHA-256:

`8c6da61dc918b3dca31b5a58675dd99fc8d80c6e3b41c6e077061a45c5111813`

Independently recomputed: MATCH.

- All 23 regular files accounted for; all 22 declared hashes and modes match. The separately delivered R06 Builder round matches its archived copy.
- Relative to R5, exactly four existing files changed and two review records were added, as declared in section 5. No files were removed.
- All four earlier Reviewer rulings match their separately supplied copies byte for byte. The other unchanged files match the R5 archive.
- The workflow parsed as YAML. The unchanged audit and path scripts remain covered by R5 acceptance.

The harness transcript records 122 of 122 expectations met in the Builder environment, with the explicitly substituted system Gitleaks hook. That is Builder evidence, not an independently reproduced full run.

## 3. CI correction

**ACCEPT.** For this small index repository, refusing merge commits is a proportionate alternative to implementing a merge-aware historical scanner. It addresses the measured coverage gap by excluding that class of history, rather than pretending Gitleaks has scanned it.

The merge refusal uses an all-ref revision walk and rejects any reachable merge. The following measurements use the actual workflow command, Git 2.47.3 and harmless scratch history:

| Test | Expected exit | Measured exit |
|---|---:|---:|
| Linear history | 0 | 0 |
| Merge at checked-out branch tip | 1 | 1 |
| Merge reachable only from another branch | 1 | 1 |
| Merge reachable only from a tag | 1 | 1 |
| Merge reachable only through detached HEAD | 1 | 1 |
| Merge object no longer reachable from refs or HEAD | 0 | 0 |
| Git revision-walk failure injected | Nonzero | 97 |
| Shallow checkout refusal, full repository | 0 | 0 |
| Shallow checkout refusal, shallow clone | 1 | 1 |

In a conflicted merge fixture, the default Git log patch omitted a unique resolution marker, while an explicit diff against the first parent contained it. This corroborates the mechanism of the reported gap; it is not a direct measurement of Gitleaks.

The checked-out file scan uses the same pinned scanner and configuration, includes redaction, and has no success-forcing wrapper. Its reported detection of the synthetic merge-only key shape, and the local hook rejection, are accepted as Builder measurements (T8.37 to T8.39 and T9.25 to T9.27). Neither was independently executed here.

The secrets job explicitly selects the pull-request head SHA, falling back to the event SHA for pushes. That is consistent with avoiding a synthetic pull-request merge in the merge-free policy. YAML parsing is not proof of GitHub expression evaluation or ref retrieval. Verify the actual checkout and scanned scope in the first applicable Actions runs; if pull requests are used, verify that path too. The other jobs retain their previously accepted checkout behavior.

CI detects after a push; it does not prevent a merge from being created or undo an exposure. Merge-free history is a repository policy, not a scan of unreachable objects or remote refs that were never fetched. Use a merge-free integration method and retain the local gates and publication review. If merges are later desired, the scan policy requires separate review.

## 4. Count reconciliation

**ACCEPT, within the measured scope.** The R5 harness creates an empty commit and a commit deleting a file, in addition to the three counted commits. The R6 Builder experiment attributes the five-reachable / three-counted result to those two commits. The R6 transcript again shows five reachable and three counted in the corresponding clean history.

The experiment and scanner-specific counts are Builder-reported. I did independently verify the Git merge behavior, but Gitleaks is unavailable in this environment. The count explanation is sufficient for design conformance and resolves the previously recorded question at that scope.

Do not apply the count as a proof of coverage or as a universal invariant across scanner versions. In particular, deleting an entire file is not the same as removing lines from a surviving text file. Record actual refs, commit types and scan results during qualification; investigate unexplained differences instead of imposing equality. Keep the positive history-scan proof and the negative controls. An unexpected zero or unexplained count does not establish coverage.

## 5. Regression and limitations

The R6 candidate's path gate and full staged sensitive-content audit pass independently in a scratch repository using a synthetic deny-list. The supplied ignore control reports 96 checks across seven scenarios. The audit negative control reports 106 checks, including the unreadable-file control and 36 injected failures, in this unprivileged environment.

The supplied harness completed with 35 expectations met, no failures and two skipped test groups (T2.1 and T7 to T11), exit 3 as specified. All seven weakened-audit controls failed as expected. This is a partial tool-limited run, not full operational qualification.

Pre-commit, Gitleaks and ShellCheck are not installed here. I did not substitute a fake scanner or hook. The remaining scanner and real-hook tests, actual GitHub Actions runs, WSL and the real deny-list have not been independently qualified. These are the same operational boundaries as R5, not new blockers. No apparent live secret or unmasked private lab identifier was identified in the inspected materials; synthetic fixtures and approved public identifiers are intentional. This is not a secret-scanner result.

## 6. Qualification boundary

Add this ruling as reviews/BP001-R06-reviewer.md. The augmented candidate has 24 files if nothing else changes. Bind the actual final manifest and hashes, preserve the accepted bytes, and run the complete harness with the pinned upstream hook in WSL, plus the full prescribed gate over the exact augmented snapshot. A partial harness result or system-hook substitution is not operational qualification.

After separate authorization, prove the actual Actions run on the intended commit, the merge-free history, the actual checkout and fetched-ref scope, and both scanner steps. The full-history publication review, private deny-list and message checks, manual inspection, no-reply identities, and separate approval of publication remain mandatory. If a gate fails, stop and resolve it; do not silently edit review records or weaken a gate.

B01, B02, B03 and B05 (including B05a to B05c) remain CLOSED at their recorded scopes; B04 remains WITHDRAWN. N01 to N07 retain their dispositions. No additional design round is requested.

**Final disposition: ACCEPT — R6 conforms to the accepted design and the Operator-approved bounded correction.**

Reviewer status: STANDBY — awaiting separately approved operational qualification. No live repository action is authorized by this ruling.
