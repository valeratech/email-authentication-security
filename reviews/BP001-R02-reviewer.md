# Reviewer — BP-001 R2: Repository scaffold

**Review date:** November 16, 2026  
**Repository:** `valeratech/email-authentication-security`  
**Disposition:** REVISE  
**Authorization:** None — Operator approval remains required.

The proposed repository structure is sound. I support the four-project layout, the WSL Ubuntu working environment, the GitHub CLI creation method and the private-first publication strategy.

The outstanding concerns involve evidence protection, pre-commit safeguards and a dependency ambiguity between Projects 01 and 02. These can be resolved without restructuring the repository.

## 1. Accepted design decisions

| Component | Reviewer assessment |
|---|---|
| Repository name | Accept |
| Private until Project 01 is finished | Accept, subject to publication review |
| WSL Ubuntu and Bash | Accept |
| GitHub CLI creation method | Accept |
| GitHub no-reply identity | Accept, verify effective identity |
| Four-project folder structure | Accept |
| Central documentation and templates | Accept |
| Raw/masked evidence separation | Accept concept; controls require revision |
| Postfix/Dovecot ownership | Accept |
| Optional projects without folders | Accept |
| Lab versus production distinction | Accept |

The four-folder layout is Operator-confirmed and does not need to be reopened.

WSL Ubuntu and Bash supersede the original Windows Command Prompt convention **for this repository only**.

## 2. Blocking findings

These findings must be resolved in BP-001 R3 before the scaffold receives Reviewer acceptance.

### BP-001-B01 — `.gitignore` coverage and validation

**High · Blocking**

The proposed exclusions are a good starting point, but sensitive files are not consistently identifiable by their extensions.

Additional coverage should include:

| Category | Examples |
|---|---|
| Raw evidence at every project depth | `**/evidence/raw/` |
| Private keys and certificates containing keys | `*.key`, `*.pem`, `*.private`, `*.p12`, `*.pfx` |
| Credentials | `.env`, `.env.*`, credential and secret files |
| SSH private keys | `id_rsa`, `id_ed25519` |
| Raw report archives | `*.gz`, `*.zip`, `*.tar`, `*.tgz` |
| Raw email and packet captures | `*.eml`, `*.mbox`, `*.pcap`, `*.pcapng` |
| Temporary files and backups | `*.swp`, `*.bak`, `*.tmp` |
| Local Python artifacts | `.venv/`, `__pycache__/` |

**Required change:** Submit the actual proposed `.gitignore` for review, together with a validation plan using harmless synthetic files.

Validate both directions: prohibited files must be ignored, while approved documentation, configuration examples, masked XML reports and `.gitkeep` files must remain eligible for tracking.

Git ignore rules do not protect files already tracked by Git and can be overridden. They are a preventive measure, not a security boundary. (Reference: Git gitignore documentation.)

### BP-001-B02 — Raw evidence custody

**High · Blocking**

The distinction between `evidence/raw/` and `evidence/masked/` is correct. However, the proposal does not establish how raw evidence is protected or how masked evidence becomes eligible for commit.

**Required change:** Establish the following evidence lifecycle in `docs/evidence-standard.md`.

1. **Collect raw evidence** — Local storage only · Restricted access
2. **Sanitize a separate copy** — Mask identifiers · Remove secrets and metadata
3. **Validate masked evidence** — Check exposure risk and technical accuracy
4. **Inspect staged content** — Pre-commit security gate
5. **Commit approved evidence** — Git / GitHub

Prefer storing raw evidence outside the Git working tree. If the proposed in-tree raw directories are retained, require restrictive permissions, verified ignore rules and a defined retention policy.

Private keys and credentials must remain outside the repository working tree entirely.

### BP-001-B03 — Masking must preserve technical relationships

**High · Blocking**

The proposed RFC-based replacements are appropriate. However, indiscriminate replacement could destroy the authentication relationships that the evidence is intended to demonstrate.

For example:

Synthetic example — aligned authentication

| Field | Masked value |
|---|---|
| Header From domain | `example.com` |
| SPF-authenticated domain | `mail.example.com` |
| DKIM signing domain | `example.com` |
| Sending IP | `192.0.2.25` |

**Relaxed alignment preserved**

The replacement retains the relationship between the parent domain and its subdomain.

**Required change:** The masking standard must require consistent, collision-free replacements within related evidence, preserving domain alignment, distinct senders, authentication results, message counts and policy dispositions.

It must also address report identifiers, message IDs, URLs, email headers, screenshots, image metadata, terminal prompts and message content.

Retain the following distinction:

- **Masked:** Actual lab evidence with identifying information replaced or removed.
- **Synthetic:** Artificially generated examples.
- **Raw:** Original, unmodified evidence that never enters Git.

Redacted message headers cannot necessarily be used to reproduce the original cryptographic verification. Document that limitation rather than presenting modified evidence as an independently verifiable original.

### BP-001-B04 — Project 01 verification dependency

**Medium · Blocking**

Project 01 proposes publishing and verifying SPF, DKIM and DMARC before Project 02 establishes the Postfix/Dovecot mail server.

DNS record publication is possible before the mail server exists. End-to-end authentication testing, however, requires an operational sending system with DKIM signing capability.

**Required change:** Distinguish DNS configuration verification from actual message authentication and receiver-side policy verification.

My recommended dependency model preserves the approved folder layout:

- **01 — SPF, DKIM and DMARC:** DNS configuration and record validation
- **02 — Postfix/Dovecot:** Secure sending, signing and receiving capability
- **01 — Complete operational verification:** Authentication, alignment and DMARC policy progression
- Then, in parallel:
  - **03 — MTA-STS / TLS-RPT**
  - **04 — DMARC reporting**

Alternatively, the Operator may approve a separate controlled sending service to complete Project 01 independently.

Do not mark Project 01 complete merely because its DNS records resolve. Publishing a DMARC rejection policy also does not prove that a receiver enforced it.

### BP-001-B05 — Mandatory pre-commit security gate

**High · Blocking**

The choice of an automated secret scanner is correctly reserved for the Operator. However, the underlying security inspection must not be optional.

**Required change:** Define a mandatory pre-commit gate covering:

- Staged filenames and file contents.
- Secrets, credentials and private keys.
- Unmasked identifiers and proprietary information.
- Compliance with raw evidence exclusions.
- Manual inspection of images and other non-text evidence.

The Operator may choose manual inspection or automated scanning supplemented by manual inspection.

My recommendation is Gitleaks with a tested local pre-commit hook. Gitleaks supports this integration, but it does not replace privacy inspection or masking validation. (Reference: Gitleaks documentation on pre-commit integration.)

## 3. Nonblocking findings

| ID | Severity | Recommended change |
|---|---|---|
| BP-001-N01 | Medium | Explicitly require a full repository history and publication review before changing visibility to public. |
| BP-001-N02 | Medium | In `SECURITY.md`, require immediate credential revocation or rotation following exposure, followed by containment and history remediation. Deleting the file alone is insufficient. |
| BP-001-N03 | Medium | Require isolated positive and negative SMTP relay tests before internet exposure, including rejection of unauthenticated external-to-external delivery. |
| BP-001-N04 | Medium | Update DMARC standards references to the current RFCs identified below. |
| BP-001-N05 | Low | Apply LF normalization to text files without treating binary evidence as text. |
| BP-001-N06 | Low | Extend the project template with prerequisites, references and known limitations. |
| BP-001-N07 | Low | Verify the effective Git author and committer identities, active GitHub account, remote URL and repository visibility during creation. |

GitHub recommends revoking or rotating exposed credentials before attempting repository history cleanup. (Reference: GitHub documentation on removing sensitive data from a repository.)

## 4. Technical standards update

An important finding for a repository being established in November 2026: the DMARC specification was updated in May 2026.

| Subject | RFC |
|---|---|
| SPF | RFC 7208 |
| DKIM | RFC 6376 |
| DMARC | RFC 9989 |
| DMARC aggregate reporting | RFC 9990 |
| DMARC failure reporting | RFC 9991 |
| MTA-STS | RFC 8461 |
| SMTP TLS reporting | RFC 8460 |
| IPv4 documentation addresses | RFC 5737 |
| IPv6 documentation addresses | RFC 3849 |
| Reserved example domains | RFC 2606 |

RFC 9989, RFC 9990 and RFC 9991 collectively supersede the original DMARC specification, RFC 7489. Older specifications may still be relevant when documenting the behavior of existing implementations. (References: RFC 9989, RFC 9990 and RFC 9991.)

The repository should distinguish current standards from legacy implementation behavior. This is particularly valuable for an email security engineering portfolio.

## 5. Operator decisions

The Reviewer provides recommendations only. All four items remain open.

| Open item | Recommendation | Rationale |
|---|---|---|
| 1. License | None initially | Retain control over original portfolio material until intended reuse rights are decided. |
| 2. Test domain publication | Keep masked | Reduces exposure of the underlying lab infrastructure. |
| 3. Linux Infrastructure conventions | Yes | Maintain consistent organization and documentation across engineering repositories. |
| 4. Local secret scanning | Yes — Gitleaks | Establish preventive security controls from the first commit. |

If no license is selected, omit the `LICENSE` file rather than creating an empty placeholder.

Matching the Linux Infrastructure hub should not require copying infrastructure-specific conventions that do not fit this repository.

## 6. Repository creation method

**ACCEPT — method only.**

The proposed GitHub CLI creation method is valid. GitHub CLI supports creating a new private repository without initializing it with scaffold files. (Reference: GitHub CLI manual, `gh repo create`.)

The first commit should contain the reviewed scaffold, with all four projects marked **planned**.

Repository creation, the first commit, project implementation and eventual public release are separate activities. Acceptance of this proposal does not authorize any of them.

## 7. Reviewer closure criteria

**BP-001 R3 — Required corrections**

- [ ] B01 — Actual `.gitignore` and validation plan
- [ ] B02 — Raw evidence custody and lifecycle
- [ ] B03 — Relationship-preserving masking standard
- [ ] B04 — Resolve Project 01 verification dependency
- [ ] B05 — Mandatory pre-commit security gate

5 blocking findings · 7 nonblocking findings · 4 Operator decisions

## 8. Review boundaries and final disposition

The review was conducted against the written proposal, not an implemented scaffold. No GitHub account permissions, local environment, existing Linux Infrastructure conventions or actual security configurations were independently inspected.

No sensitive credentials or unmasked lab identifiers were identified in the submitted proposal.

No implementation commands, repository changes or additional project folders are authorized or introduced by this review.

**BP-001 R2: REVISE.**

Preserve the Operator-confirmed four-folder architecture. Submit a consolidated R3 addressing the five blocking findings and recording the disposition of the nonblocking findings.

**Reviewer status: STANDBY — Awaiting Builder R3.**

---

Record note (2026-11-17): Plain-Markdown reissue requested in BP-001 R3 section 7. The R2 review remains historical. Interactive badges, diagrams and checklist elements are represented as text and standard Markdown; interactive citations are represented by descriptive reference labels, not preserved source-link metadata. No substantive finding, disposition or historical Operator decision has been updated. See the separate R3 ruling for the subsequent architecture change.
