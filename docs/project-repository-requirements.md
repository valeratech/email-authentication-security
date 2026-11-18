# Project repository requirements (Email Authentication & Security hub)

Date: 2026-11-17 (revision 3). Applies to every project repository added to the hub.
`secure-mail-platform` predates this file and is governed by its own accepted record; nothing here reopens it.
Source: Reviewer findings on BP-001 R2 (B02, B03, B04, B05, N02, N03, N04, N06), carried forward to project repositories when the hub became an index, with the Reviewer's clarifications from the BP-001 R3 ruling (B03, N02).
Each new project repository meets these in its own Section 1, through its own Builder/Reviewer process.

## 1. Becoming a hub project

- An idea becomes a project only when Ryan makes it official. Until then the hub does not list it.
- The project gets its own repository under `valeratech`, its own Builder/Reviewer record (`reviews/`), and its own scope file.
- The scope file states the project's prerequisites, its references, and its known limitations.
- The hub adds the project to the index as **planned** through a hub Builder proposal, and updates its status only from the project's own Status table, naming the commit it was read from.

## 2. Labelling

- All work is labelled lab or portfolio work. Nothing is presented as production, paid or employer work, and nothing claims compliance or certification.
- Nothing from Ryan's former employer: no customer domains, internal procedures, tickets, or data from employer vendor accounts.
- Planned work is labelled **planned** until it is built and verified.

## 3. Commit gates (four layers)

1. Redact at the source.
2. A project-tuned sensitive-content audit (`audit-sanitize.sh` retuned for the project's namespace), with a git-ignored deny-list of employer and production strings.
3. Pre-commit hooks: Gitleaks with project rules, private-key detection, image blocking unless metadata is stripped and the image is allowlisted.
4. CI: Gitleaks over the full history, plus the audit and a negative control proving the audit still catches a planted value.

A manual inspection of staged content (filenames, text, images, other non-text evidence) is part of every commit, whatever the tooling finds.

Gate output and CI logs do not repeat a sensitive value, and a gate that cannot run counts as a failure, never as a pass.

## 4. Evidence custody

1. **Collect** raw evidence locally, preferably outside the Git working tree; if inside, in a git-ignored folder with restrictive permissions and a stated retention period.
2. **Sanitize** a separate copy: mask identifiers, remove secrets and metadata.
3. **Validate** the masked copy for exposure risk and technical accuracy.
4. **Inspect** staged content at the pre-commit gate.
5. **Commit** only approved, masked evidence.

Private keys and credentials never sit inside the working tree.

## 5. Masking that keeps the evidence true

- **The baseline is always masked:** private lab IP addresses, workstation paths, account identifiers, personal email addresses and third-party identifiers. Credentials and private keys are never publishable, masked or not.
- Replacements are consistent and collision-free across related evidence: the same real value always becomes the same masked value, and different values never merge.
- Relationships the evidence exists to prove are preserved: domain alignment (parent and subdomain), distinct senders, authentication results, message counts, policy dispositions.
- Coverage includes IP addresses, hostnames, report identifiers, message IDs, URLs, email headers, screenshots, image metadata, terminal prompts and message content.
- Replacement values: RFC 5737 (IPv4), RFC 3849 (IPv6), RFC 2606 names (example.com, example.net).
- **A real lab value is published only by explicit approval in the project scope, and only if it is not sensitive**, for example Ryan's own public test-domain name. This is a narrow exception. It is not a general waiver of the baseline above.
- Every evidence item is labelled **masked** (real lab evidence, identifiers replaced), **synthetic** (generated example) or, never in Git, **raw**. Approved synthetic evidence is committed as synthetic; it is never presented as a masked observation.
- Redacted headers cannot reproduce the original DKIM verification. Say so; do not present modified evidence as independently verifiable.

## 6. Verification honesty

- A record that resolves in DNS proves publication, not authentication. Message-level results need real messages and receiver-side evidence.
- Publishing `p=reject` does not prove a receiver enforced it.
- Configuration parsing (`postfix check` and similar) proves syntax, not control. Each control is verified by showing the misuse failing.
- Any mail server that can reach the Internet passes positive and negative relay tests in isolation first, including rejection of unauthenticated external-to-external delivery.

## 7. Standards cited

| Subject | RFC |
|---|---|
| SPF | RFC 7208 |
| DKIM | RFC 6376 |
| DMARC | RFC 9989 (obsoletes RFC 7489 and RFC 9091) |
| DMARC aggregate reporting | RFC 9990 |
| DMARC failure reporting | RFC 9991 |
| MTA-STS | RFC 8461 |
| SMTP TLS reporting | RFC 8460 |

RFC 7489 is cited only to document legacy receiver behavior. RFC 9989 removed the `pct` tag, so policy progression is not described with it; its `t` testing tag is not a percentage rollout. Which specification an implementation follows is recorded, not assumed.

## 8. Exposure response

If a credential is committed: revoke or rotate it first, then contain the exposure, then remediate history.

If an identifier with no revocable credential is committed (an address, a hostname, a name): it cannot be revoked. Contain the exposure and remediate history.

In both cases, deleting the file is not enough.
