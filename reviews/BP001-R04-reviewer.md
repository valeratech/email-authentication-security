# BP-001 R4: Reviewer ruling on correction and commit candidate

| Item | Record |
|---|---|
| Date | 2026-11-17 |
| From | Independent Reviewer |
| Responds to | BP001-R04-builder.md, candidate archive, test harness and transcript |
| Disposition | **REVISE — B01 CLOSED; B05 remains OPEN** |
| Authority | Review only. No creation, first commit, push or publication authorized |

## 1. Rulings requested in section 9

| Item | Ruling |
|---|---|
| 1. Closure of B01 | **ACCEPT — CLOSED.** Independent path and Git-mode enforcement resolves the R3 findings. |
| 2. Closure of B05 | **REVISE — OPEN.** The path integration is accepted; the sensitive-content audit still has measured fail-open and coverage defects. |
| 3. Untested items in section 6 | **ACCEPT as deferred operational verification**, not as completed tests. The environment gaps alone do not block design conformance; the B05 defects do. |
| 4. Conformance of the nineteen files | **REVISE, bounded to B05.** Inventory and architectural conformance accepted; the exact candidate is not accepted for the first live commit. |

## 2. Identity and independent verification

The supplied archive's recomputed SHA-256 is `b196f5eeb7bcd0c1e608f29439674829961d4148ae1feff394afe660e5fae07c`, matching the Operator's stated prefix and suffix.

- All 19 files are regular files. The 18 listed SHA-256 values and modes match; the nineteenth file, R4 itself, is byte-identical to the separate upload.
- Both earlier Reviewer files are byte-identical to the supplied R2 and R3 records. The R3 Builder file also matches its earlier upload. I have no separately preserved byte-level R2 Builder original against which to compare that file.
- The candidate was extracted into a disposable directory. Tests used copies and synthetic fixtures, not an actual portfolio repository.

Independent environment: Git 2.47.3, Bash 5.2.37. YAML parsing and Bash syntax checks passed. The following harness subset was run, rather than merely inferred from the transcript:

| Group | Independent result |
|---|---|
| T3 | PASS; 92 checks across seven scenarios |
| T4 | 7/7 expectations met, including rule sabotage and always-pass path-gate stub |
| T5 | 9/9 expected error exits |
| T6 | 2/2 expectations met; 17 audit controls passed and the audit stub was rejected |
| Total T3–T6 | 19/19 expectations met |

Separately, a scratch index staged all 19 candidate files; the path check passed, the full content audit was CLEAN with a synthetic deny-list, and the history path check passed after a scratch root commit. The scratch commit did not use pre-commit hooks and is not evidence of hook execution.

The Builder's 74/74 transcript is accepted as reported evidence within its declared scope. It is not an independent 74/74 reproduction. The required pre-commit, Gitleaks and ShellCheck executables are absent here, and a connection probe to the Go module proxy failed at name resolution. Neither upstream hook execution nor T7–T10 was independently reproduced. The two YAML files parsed, but parsing does not establish GitHub Actions execution.

## 3. B01 — CLOSED

The corrected ignore rules explicitly exclude directories masquerading as approved files. The independent manifest reads NUL-delimited index and history entries, restricts exact paths and direct-child review names, and checks regular-file modes. Nested ignore rules cannot expand that manifest. The tracked-but-ignored check remains defense in depth only.

The supplied controls reproduce the original R3 failures, detect force-added entries, reject incorrect modes and types, detect index-only entries and detect a prohibited historical path after deletion. The independently rerun sabotage and error controls succeed.

B01 is closed at its recorded scope: Git path and mode enforcement. Git regular-file modes do not distinguish text from binary content. That separate policy is assessed under B05, not used to reopen B01.

## 4. B05 — OPEN, bounded corrections

The four-layer design, path integration, isolated scratch controls, scoped exemptions, local deny-list concept and explicit CI limitation are accepted. The following are residual conformance failures of the actual audit, not a new architecture review.

### BP-001-B05a — High — Search errors silently pass

The audit uses process substitutions containing searches and pipelines. Their failure statuses are not collected by the consuming loops. Diagnostic output is suppressed. A search error can therefore be treated as no match despite the script's stated exit-2 contract.

Independent negative controls:

| Fixture / condition | Expected | Measured |
|---|---|---|
| Synthetic private IPv4; normal search | Reject | Exit 1 |
| Same fixture; search utility forced to exit 2 | Error / fail closed | Exit 0, CLEAN |
| Synthetic deny-listed term; normal search | Reject | Exit 1 |
| Same fixture; only the deny-list search forced to exit 2 | Error / fail closed | Exit 0, CLEAN |

The last test matters especially: other search operations can function normally while the employer-identifier check silently does not run. The reported nine T5 error cases exercise the two path-control scripts, not these audit failures.

Required: propagate operational failures from file enumeration, file classification and mandatory searches, including deny-list reads and searches. Distinguish a valid no-match result from a search error. Extend the negative control with targeted failure injection and a genuinely clean control. A gate that cannot complete its declared scan must fail, not print CLEAN.

### BP-001-B05b — High — Local audit can omit binary content

The candidate removes the image hook because the manifest contains no image paths. That is not equivalent to checking file content. In the local hook configuration, the sensitive-content audit is limited to `types: [text]`, with filenames passed and without an always-run requirement.

I staged a harmless binary fixture under a valid future review filename, using the required regular-file mode. The path gate returned exit 0; the direct full audit correctly rejected the fixture with exit 1. The configuration excludes binary files from the local audit's input, however. An eligible filename can contain binary bytes regardless of its extension. A deletion-only commit or another commit with no applicable text input can also skip the audit, contrary to the mandatory local deny-list requirement.

The binary path and full-audit results are measured; the pre-commit omission is based on inspection of the hook configuration, not an independently executed hook bypass.

Required: run the local content audit unconditionally on the applicable staged/tracked snapshot, without a text-only prefilter that prevents binary detection. Require the local deny-list even when no changed text files are present. Preserve the staged-only distinction and manual inspection. Add real-hook negative controls for binary content at an admitted path and for a deletion-only commit without the deny-list. Include a clean control. Correct the claim that absence of image extensions alone blocks images.

### BP-001-B05c — Medium — IPv6 coverage missing

The address detection section checks IPv4 literals but has no IPv6 classifier. A harmless synthetic private IPv6 address in a text fixture returned exit 0, CLEAN. The accepted masking baseline explicitly covers IPv6 and the hub approves documentation addresses, not private lab addressing.

Required: provide an IPv6 check that rejects unapproved address literals and accepts reserved documentation examples, or an equally effective, explicitly verified gate that supplies this coverage. Include compressed and expanded forms and a negative control for private IPv6. Avoid false positives on ordinary Markdown and review-record text. This requirement concerns the index's existing address policy, not a new lab project.

## 5. Candidate conformance and nonblocking notes

The index-only structure, single project home, primary and secondary index distinction, lab/production separation, absence of a license, requirements revision 3, exposure procedure and historical review-record convention conform to the accepted design. B02 and B03 remain closed by relocation; B04 remains withdrawn. No existing project is reopened.

- The status and source-workflow provenance are stated with revisions. I did not retrieve the external repositories to independently verify those source claims. Treat status and provenance as Builder-reported, not Reviewer-observed.
- Keep the explicit manual staged-content inspection in the hub's operational checklist, including checking metadata and commit messages as appropriate. It remains mandatory regardless of automated results. Preserve the full-history publication review, including local deny-list checks, exact public refs and any subsequent review-record commit. These are retained requirements, not authorization to publish.
- Version tags and self-hosted gate files are not tamper-proof trust anchors. The declared review requirement for gate changes is retained. The proof of a nonempty history scan should be tied to the actual scanned scope; CI detects after push, not before it. These do not reopen the accepted design.
- No apparent live credential or unmasked private lab identifier was identified during this review. Synthetic test fixtures and public project identifiers are intentional. This is not an independent Gitleaks result or an assertion of exhaustive sensitive-content coverage.

## 6. Deferred operational evidence

The previously disclosed environment gaps are acceptable at candidate review only. Before the first live commit, the Operator's WSL environment must run the corrected controls with the actual upstream Gitleaks hook, the actual prescribed hook configuration, and a local deny-list. Do not substitute a system hook silently. Check effective Git identity, active account, exact repository visibility and remote, and the complete staged inventory. Preserve the manual inspection gate.

Actual GitHub Actions success and exact-commit confirmation are post-push requirements, before publication. Review the entire intended public history locally, including content, commit messages, identities, refs and later record commits. A passing scratch test does not waive any of these conditions.

## 7. Next handoff

Submit one bounded correction addressing B05a–B05c, with revised files, updated inventory and targeted regression evidence. Preserve the already accepted architecture, B01 closure and prior review records. Do not reopen settled matters or copy changes into the existing mail-platform repository under this proposal.

Add this R4 ruling as a new review record. It is not part of the nineteen-file archive measured above. Any next candidate must bind the updated inventory and pass its gates, including this record, before the Operator considers a first live commit.

**Final disposition: REVISE — B01 CLOSED; B05 OPEN.**

Reviewer status: STANDBY — awaiting the consolidated B05 correction.
