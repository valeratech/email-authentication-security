# Reviewer — BP-001 R3: Repository scaffold

| Field | Value |
|---|---|
| Date | 2026-11-17 |
| Responds to | BP-001 R3 and attached Project repository requirements, revision 2 |
| Repository | `valeratech/email-authentication-security` |
| Disposition | **REVISE — bounded control corrections only** |
| Authorization | None. Operator approval remains required. |

The index architecture is accepted. The four-folder architecture is superseded by the Operator's decision, not reopened because of a defect in the earlier review. The outstanding issues are confined to the ignore-control enforcement and its integration into the commit gate. No further architecture debate is required.

## 1. Rulings requested in section 9

| Item | Ruling | Reason |
|---|---|---|
| 1. Index hub | ACCEPT | One authoritative project repository per build; the hub links and reports status without duplicating work. |
| 2. B02 and B03 relocation | ACCEPT — CLOSED at hub design level | Sections 4 and 5 of the attachment carry the evidence custody and relationship-preserving masking requirements into future project scopes. Existing project acceptance is unaffected. |
| 3. B04 withdrawal | ACCEPT — WITHDRAWN (scope superseded) | The former ordering no longer exists. The verification principle survives in attachment section 6. |
| 4. Deny-by-default `.gitignore` | ACCEPT — design | A narrow index has a different file inventory from a build repository. The actual pattern implementation requires correction (B01). |
| 5. B01 and B05 closure | NOT CLOSED — limited revision required | Independent testing reproduced the submitted results but found a path bypass affecting both controls. The four-layer gate is accepted in principle; its enforcement is not yet demonstrated. |
| 6. R2 Markdown resupply | ACCEPT — supplied separately | `BP001-R02-reviewer.md` is the historical review reissued without interactive rendering or icon links; its disposition and findings are unchanged. |

## 2. Architecture and governance ruling

Accept the index-only hub, the existing `secure-mail-platform` repository as Project 1, its separate governance, and the one-home rule. No lab configurations, evidence, or project folders belong in the hub. Gate configuration and review records are hub governance artifacts, not lab configuration or evidence.

Accept the Operator's decisions in section 2: no license for now; real-domain publication decisions in the relevant project; alignment with the existing project's review conventions; mandatory four-layer gate; revised visibility trigger. The hub need not wait for all 13 sections of Project 1 to be completed. Its own publication gate must pass and the Operator must authorize publication separately.

The existing project's status must be transcribed from its authoritative Status table, with the source revision identified at the time of addition or update. Do not infer that Project 1 is finished from its public visibility or Section 1 acceptance. The existing project's public status and Section 1 acceptance are Builder-reported; I did not independently inspect that repository in this review.

The attachment's grandfathering clause stands. Nothing in this ruling reopens the accepted record of `secure-mail-platform`, certifies its existing controls, or implicitly authorizes an implementation change there.

## 3. Blocking finding dispositions

### BP-001-B01 — High — OPEN; implementation correction required

The approach is accepted, and the submitted test results reproduce. I extracted the exact ignore rules and script from BP-001 R3 and ran them in disposable local repositories using Git 2.47.3. No Operator repository, credentials or network service was used.

| Run | Expected | Reviewer result |
|---|---|---|
| A — submitted rules | PASS | Exit 0; 40 prohibited paths ignored, 14 approved paths trackable, force-add caught |
| B — empty rules | FAIL | Exit 1 |
| C — remove README exception | FAIL | Exit 1; intended README ignored |
| D — remove docs exclusion | FAIL | Exit 1; five prohibited docs paths admitted |

These results independently reproduce the Builder's four runs. They do not establish that the rules admit only direct child files.

**Additional negative control: directories with approved-looking names.** The negation patterns admit directories as well as files. I placed the same harmless synthetic text used by the submitted control in the following paths in a separate scratch repository.

| Synthetic path | Expected | Measured |
|---|---|---|
| `README.md/raw.key` | Ignored | Trackable and staged |
| `docs/nested.md/raw.key` | Ignored | Trackable and staged |
| `reviews/raw.md/.env` | Ignored | Trackable and staged |
| `scripts/nested.sh/raw.key` | Ignored | Trackable and staged |
| `.github/workflows/nested.yml/raw.key` | Ignored | Trackable and staged |

All five were staged by ordinary add-all behavior without force-add. The proposed tracked-but-ignored check returned no paths. This contradicts the claim in section 4.1 that subdirectories stay ignored.

**Additional negative control: local nested ignore rules.** In a separate scratch repository, an ignored `docs/.gitignore` containing the single exception `!raw.key` admitted the synthetic `docs/raw.key`. Ordinary staging included the file and the tracked-but-ignored check again returned no paths. A local ignored rule can therefore change what the proposed enforcement regards as permitted.

These are synthetic path-boundary tests, not findings of leaked secrets.

**Required change:** retain deny-by-default, but explicitly exclude directories masquerading as approved filenames, and add a separate staged/tracked path-and-type check that does not derive its allow decision from Git's mutable ignore sources. It must admit the seven named root files and only direct regular files in the approved directories, with the permitted type for each; no symlinks, gitlinks or unexpected nested paths. Future direct-child review records remain admissible under the declared convention. Keep the tracked-but-ignored check as defense in depth.

Extend the existing scratch control to exercise both newly demonstrated bypasses, forced staging, and allowed regular files. Demonstrate that the independent check rejects disallowed staged entries even when local ignore rules permit them. The rule may distinguish exact approved names and permitted review filename patterns; the choice of implementation remains with the Builder. No new gate layer or project folder is required.

The current 14-path fixture is representative, not an exhaustive scaffold manifest. During the commit-candidate review, check every actual proposed scaffold filename, including all review rounds.

### BP-001-B02 — High — CLOSED by relocation

Attachment section 4 adopts the five-step lifecycle, local custody, restricted in-tree raw storage, retention and the exclusion of private keys and credentials from the working tree. The index has no evidence to collect or publish. Retain this requirement in each future project, reviewed at that project's Section 1 and verified during implementation. The Builder appropriately states that existing project permissions and retention have not been verified here.

### BP-001-B03 — High — CLOSED by relocation

Attachment section 5 retains consistency, collision avoidance, relationship preservation, evidence labels and the cryptographic limitation of redacted headers. It is sufficient for the hub design.

Carry the original masking baseline forward explicitly when finalizing the attachment: private lab IPs, workstation paths, account identifiers, personal email addresses and third-party identifiers remain masked; credentials and private keys are never publishable. The clause permitting an approved real lab value is limited to explicitly authorized, non-sensitive values (for example the Operator's own public test-domain name), and is not a general waiver of the original hard rules. Approved synthetic evidence may be committed as synthetic, not passed off as a masked observation. These are clarifications of the already accepted requirements, not a new project scope.

### BP-001-B04 — Medium — WITHDRAWN (scope superseded)

The former dependency is no longer applicable. The record remains historical and is not erased. Attachment section 6 retains the distinction between DNS publication, actual authentication, receiver enforcement, configuration parsing and demonstrated control behavior. A future real-domain build establishes its own dependencies and verification criteria; no Internet-facing project is authorized here.

### BP-001-B05 — High — OPEN; integration correction required

The mandatory four layers and manual staged-content inspection are accepted as the correct design. The source revision identification and limited adaptation plan are also accepted as the Builder's stated basis, not as independently verified implementation.

The B01 bypass defeats the proposed filename enforcement in B05. Incorporate the independent check from B01 into pre-commit and CI. Keep the other three automated control categories and manual inspection intact; do not weaken audit rules to make the review record pass.

At the commit-candidate review, supply the actual gate files and demonstrate the following in a disposable environment:

- The pre-commit gate examines the actual staged content and staged paths, not just the working tree. A clean working copy must not hide a disallowed staged value. Include a benign staged-only negative control.
- The scratch repository operates independently of the parent Git environment when invoked by a hook; isolate inherited repository/index variables before scratch Git operations. Setup and Git command failures must fail the gate rather than be interpreted as clean results. The current script declares a setup-error exit but does not check all setup and Git operations. No failure-injection or actual hook invocation was measured in this review.
- The local deny-list is present and readable for the required Operator-side gate, remains untracked, and is never printed in audit output or committed. CI's inability to access it is an accepted, documented limitation, not equivalent coverage.
- The negative control rejects planted prohibited values, the clean case passes, the independent path check rejects the new bypass cases, and a real hook invocation rejects a synthetic violation. CI must run the declared checks, fail on errors, and scan the available full history rather than a shallow checkout. Do not treat a later CI failure as preventing an already completed push.
- Exemptions such as `audit-ok` are narrowly scoped, reviewed and not usable as an unexamined bypass for sensitive values. Confirm the gate does not require exposing a secret in a review or log. Verify the complete actual staged inventory and gate-file versions.

The gate files other than the supplied ignore script are described but not attached in full. Their absence is expected at the design stage and is not, by itself, a new blocker. Closure requires the corrected design and its conformance evidence; no claim that the complete gate is working is made here.

## 4. Nonblocking findings and standards

| ID | Reviewer disposition |
|---|---|
| N01 | ACCEPT — publication review retained. Bind the review to the exact candidate revision, include all refs intended to be made public, and ensure any later review-record commit is itself checked and covered before visibility changes. |
| N02 | ACCEPT — revoke or rotate exposed credentials promptly, contain the exposure, then remediate history. For an identifier without a revocable credential, contain and remediate; do not imply that revocation is possible. |
| N03 | ACCEPT — relocated to attachment section 6. The hub operates no MTA. |
| N04 | ACCEPT — current DMARC standards confirmed independently. |
| N05 | ACCEPT — proposed text normalization and explicit binary treatment; Builder's byte-comparison tests are reported, not independently repeated. |
| N06 | ACCEPT — scope-file requirements relocated to attachment section 1. |
| N07 | ACCEPT — identity and creation checks retained. Verify both author and committer before the first commit as well as the actual resulting commit; retain supporting output locally and publish only an appropriately sanitized verification record. |

For N04, I independently checked the RFC Editor records for RFC 9989, RFC 9990 and RFC 9991 (May 2026). The reporting specifications, together with RFC 9989, replace RFC 7489; RFC 9989 also obsoletes RFC 9091. RFC 9989 Appendix A.6 and C.5.2 confirm removal of `pct`; its replacement for some of the former functionality is the `t` testing tag, not percentage-based rollout. This does not establish which specification any particular implementation supports. The standards table and legacy-behavior distinction are accepted. No future real-domain build is scoped by this standards ruling.

For the ignore semantics, the reference is Git's gitignore documentation (pattern matching and precedence) and git-ls-files documentation (standard exclusions). The two additional bypasses above were measured independently rather than inferred solely from those references.

## 5. Record handling — section 7

Accept the naming convention and the treatment of R1 as an unsubmitted draft. The original R2 disposition remains REVISE. The separately supplied plain-Markdown R2 reissue removes UI rendering and interactive citation artifacts; source references are expressed in text. It is not a new substantive review or a byte-identical export of the earlier rendered message.

The submitted R3 proposal and attachment contain no apparent secret, private key, personal email address or unmasked private lab identifier on manual review. The public repository and portfolio identifiers are intentional context; the other identifiers used for tests are synthetic or documentation values. This is not a secret-scan attestation. The supplied R2 and R3 Markdown files must pass the actual candidate gate like every other file.

## 6. Next handoff and closure

B02 and B03 are closed by relocation. B04 is withdrawn because its scope is superseded. B01 and B05 remain open for the single shared path-enforcement correction and its verification. All seven nonblocking findings have accepted dispositions.

A separate architecture proposal is unnecessary. With Operator approval, the Builder may combine the bounded correction with the full commit candidate in the next handoff, rather than creating a standalone design iteration followed by a second review of the same control. That handoff must include the exact files, the expanded tests and results, and the actual hook/CI configuration needed to assess conformance. Resolve the cited WORKFLOW.md dependency if available; if it is unavailable, record the limitation and obtain Operator confirmation that no unstated governing convention is being overridden.

Do not create the repository, commit, push, change visibility, modify `secure-mail-platform`, or publish a portfolio card on the strength of this review. Those remain separate Operator-authorized activities. No existing portfolio publication rule is changed here beyond the hub visibility decision expressly made by the Operator.

**Final disposition: REVISE — limited to B01/B05. Index architecture accepted.**

Reviewer status: STANDBY — awaiting the consolidated corrected candidate, subject to Operator approval.
