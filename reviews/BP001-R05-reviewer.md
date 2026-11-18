# BP-001 R5: Reviewer ruling on the sensitive-content audit

| Item | Record |
|---|---|
| Date | 2026-11-17 |
| From | Independent Reviewer |
| Responds to | BP001-R05-builder.md, candidate archive, test harness and transcript |
| Disposition | **ACCEPT — candidate conformance; B05 closed** |
| Authority | Review only. Repository creation, first live commit, push and publication remain subject to the Operator's separate approval and operational gates |

## 1. Rulings requested in section 7

| Item | Ruling |
|---|---|
| 1. Closure of B05a | **ACCEPT — CLOSED.** The measured search-error defects are corrected; targeted failure controls pass. |
| 2. Closure of B05b | **ACCEPT — CLOSED.** The local audit is unconditional, reads the staged snapshot, requires the deny-list and rejects binary content. Real-hook evidence is Builder-reported; the actual upstream hook remains an operational qualification requirement. |
| 3. Closure of B05c | **ACCEPT — CLOSED.** IPv6 classification and the required positive and negative controls conform to the accepted masking baseline. |
| 4. Conformance of the twenty-one files | **ACCEPT — candidate conformance.** The exact R5 archive is accepted within the measured scope. This is not approval of a live commit or a publication verdict. |

B05 is closed at the design and candidate-conformance scope. The outstanding operational tests are not recorded as completed. No previously closed finding is reopened.

## 2. Candidate identity and record preservation

The recomputed archive SHA-256 is `53dbd3fb7c6fd059b71e293783f78a9f7158ca8e1c968901f4a0eeb4c28686bd`, matching the supplied prefix and suffix.

- The archive contains 21 regular files. All 20 declared SHA-256 values and file modes match. The twenty-first file, the R5 Builder round, is byte-identical to the separate upload; its SHA-256 is `a980fba045ee0218e0861a675dc948f5d9da6ee755bb6b0b36f00a0bdc51c7d8`.
- The three earlier Reviewer rounds are byte-identical to the copies previously supplied. The R4 Builder round also matches its separate upload.
- A direct comparison with the supplied R4 archive confirms exactly six existing files changed and two review files were added, as declared in R5 section 4. The other thirteen files are byte-identical, including the path gate, the ignore rules, the CI workflow and the project requirements.
- The R2 Builder record is unchanged from R4. Its original pre-R4 provenance remains Builder-attested, not independently established.

All testing used disposable local directories and synthetic values. No actual portfolio repository was created or modified.

## 3. Independent verification

Environment: Git 2.47.3, Bash 5.2.37, Python with PyYAML, and setpriv. The Reviewer environment does not contain pre-commit, Gitleaks or ShellCheck. No substitute hook or unverified scanner was installed.

Bash syntax checks passed for all four candidate scripts. The two YAML files parsed successfully. The available harness expectations were reproduced as follows:

| Group | Independently measured result |
|---|---|
| T2.2 | 1/1; YAML parse |
| T3 | 1/1; 94 internal checks across seven scenarios |
| T4 | 7/7; ignore-rule sabotage and path-gate stub rejected |
| T5 | 9/9; path-control errors fail closed |
| T6 | 2/2; 104 audit checks (36 injected failures); always-pass stub rejected |
| T6S | 7/7; each deliberately weakened audit rejected by its controls |
| T6R | 6/6; original IPv4 and deny-list measurements plus IPv6 pair |
| T6U | 2/2; unprivileged run passed and unreadable-file control ran |
| Total | **35/35 executed expectations met** |

The unmodified harness began normally and passed 21 expectations, but the execution window expired during T6S. The six outstanding mutation tests and eight targeted/unprivileged expectations were then run as separate scratch invocations using the corresponding harness setup, functions and test definitions. All passed. This is a reproducible split run, not a claim that the entire unmodified harness completed with exit 3. T2.1 was skipped because ShellCheck is absent. T7 through T11 were not independently executed because their prerequisites are absent.

The Builder transcript reports 109/109 expectations met, with no skips. Its explicitly disclosed system Gitleaks substitution and local CI simulation remain part of the measurement scope. That result is accepted as Builder-reported evidence, not as an independent reproduction of the complete suite or actual GitHub Actions evidence.

A separate scratch index containing the exact 21 files passed the path gate and the staged content audit with a synthetic deny-list. The audit evaluated all 21 files and reported CLEAN. This was not a live hook invocation.

## 4. Closure rationale

### B05a — CLOSED: failures of declared search and classification operations

R5 replaces unchecked search substitutions with checked scratch results. The search helper distinguishes matches, no matches and errors. File classification, NUL detection and Git export failures are checked; the deny-list must be readable and contain terms. CRLF normalization of the local deny-list is appropriate for WSL. A missing explicit input path is an error rather than an omission.

| Synthetic fixture | R4 measured exit | R5 independently measured exit |
|---|---|---|
| Prohibited IPv4, normal search | 1 | 1 |
| Same fixture, address search fails | 0 | 2 |
| Deny-listed term, normal search | 1 | 1 |
| Same fixture, deny-list search fails | 0 | 2 |
| Prohibited IPv6, normal search | 0 | 1 |
| Same IPv6 fixture, search fails | Not measured | 2 |

The expanded control exercised 36 injected tool failures for the selected fixtures; all were rejected. The additional mutation tests show the controls can themselves fail when the intended protections are removed. The unprivileged run confirms unreadable content is not silently skipped. The clean controls continue to pass.

Closure is based on the demonstrated operational failure cases and the declared implementation, not an assertion that all possible operating-system or adversarial failure modes have been exhaustively tested.

### B05b — CLOSED: unconditional staged content and binary handling

The Builder's correction to the R4 binary-hook observation is accepted. The earlier Reviewer identified the text-only filter as a potential omission by inspection, not as an executed hook bypass. The Builder measured that an approved Markdown filename was still classified as text by pre-commit. The actual omission of empty and deletion-only commits, and the absence of a full-index deny-list check, remain substantive defects in R4.

The R5 hook configuration removes its explicit text restriction, sets `always_run: true` and `pass_filenames: false`, and invokes the staged audit. The audit classifies content independently of filenames and scans the full exported index. The declared LF and text attributes are retained; this assessment is for that configuration, not arbitrary external checkout filters or malicious gate rewrites.

Additional independent direct-audit checks:

| Condition | Measured exit |
|---|---|
| Exact 21-file staged candidate, synthetic deny-list | 0 |
| Additional clean synthetic review file staged | 0 |
| Local deny-list changed to match a term already in that staged snapshot | 1 |
| Local deny-list removed | 2 |
| Binary fixture staged under an approved review filename | 1 |

The supplied negative control also demonstrates rejection of an index-only value and nonregular index entries. The Builder's real-hook tests T8.23 through T8.36 cover the binary, staged-only IPv6, empty-commit and deletion-only cases with positive controls. Those hook tests were not independently reproduced in this environment. WSL qualification remains required, using the actual upstream configuration.

The README now correctly distinguishes path admission from content classification and requires manual inspection of staged changes and commit messages.

### B05c — CLOSED: IPv6 classification

The IPv6 parser now distinguishes compressed and expanded forms, including upper case, brackets, prefixes and dotted IPv4 tails. The nine selected prohibited-address fixtures are rejected by the IPv6 classifier; the documentation-prefix and loopback controls pass. The independently reproduced targeted search failure returns exit 2. Disabling the IPv6 check or widening the approved documentation prefix causes the negative control to fail.

The correction conforms to the recorded scope: classification of literal addresses in index documentation, supported by manual inspection. This is not a claim of exhaustive recognition of every possible encoding, token boundary, obfuscation or secret representation. The documented ASCII-only deny-list case folding and binary-classification limitations are accepted as bounded limitations of a backstop, not exemptions from the underlying publication policy.

## 5. Section 2.5 and retained nonblocking notes

The Builder's responses are accepted. No design expansion is required.

One operational reconciliation remains: the R5 transcript reports five commits reachable from all refs and three commits scanned by Gitleaks. The two added empty/deletion-only control commits are a possible explanation, not independently established here. The difference is not itself proof of a missed secret or of complete coverage. During operational confirmation, record the refs and actual scan scope and reconcile any count discrepancy against the behavior of the pinned scanner. Do not treat the mere presence of a count line as independent proof that every intended ref was included. This preserves the R4 nonblocking history-scan note; it is not a new B05 blocker.

Manual inspection, exact-ref history review, no-reply identities and separate approval of gate changes remain mandatory. Pinned tags and repository-owned scripts are not independent trust anchors. The external project status and source-workflow provenance remain Builder-reported; the underlying project is not reopened by this acceptance.

No apparent live credential or unmasked private lab identifier was identified on inspection of the submitted materials. Test values and approved public project identifiers are intentional. This is not a Gitleaks result or a guarantee of exhaustive disclosure detection.

## 6. Operational activation boundary

Before the first live commit, the Operator must qualify the accepted candidate in WSL using the actual pinned upstream Gitleaks hook, not the system-mode substitution. The full harness must complete successfully with all applicable expectations executed, including the unprivileged control. A missing-tool or partial result is not operational acceptance. Check the effective author and committer identities, active GitHub account, exact private repository and remote, local deny-list custody, and complete staged inventory. Inspect staged content, metadata and the proposed commit message manually.

This ruling is the next review record, not one of the 21 measured archive files. Adding it produces a 22-file candidate if no other files change. Bind the actual final inventory and hashes, retain the accepted R5 bytes, and run the full prescribed gate over that exact augmented snapshot. If any gate rejects the record or a substantive candidate change is needed, stop and resolve it through the existing review process rather than silently editing the record or weakening a gate.

Following a separately authorized push, actual GitHub Actions success and exact-commit confirmation are required. Before any change to public visibility, complete the full-history publication review covering every intended public ref, local deny-list searches, commit messages, identities and any later record commit. Reconcile the actual scan scope as described above. The Operator separately authorizes publication. No public release is implied by candidate acceptance.

## 7. Final finding register

| Finding | Status |
|---|---|
| B01 — Ignore coverage and path enforcement | CLOSED (R4) |
| B02 — Raw evidence custody | CLOSED by relocation (R3) |
| B03 — Relationship-preserving masking | CLOSED by relocation (R3) |
| B04 — Project verification dependency | WITHDRAWN (R3) |
| B05a — Audit operational failures | CLOSED (R5) |
| B05b — Mandatory staged content audit | CLOSED (R5) |
| B05c — IPv6 coverage | CLOSED (R5) |
| B05 — Mandatory security gate | CLOSED at candidate-conformance scope (R5) |
| N01–N07 | Accepted dispositions; applicable operational obligations retained |

**Final disposition: ACCEPT — BP-001 R5 candidate conforms to the accepted design. No open design blockers.**

Reviewer status: STANDBY — awaiting the Operator's separately approved operational qualification record. No further scaffold design round is requested.
