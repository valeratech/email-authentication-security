# BP-001: Repository scaffold (Builder proposal, for Reviewer)

BP = Builder Proposal. Status: **ready for Reviewer**, not approved. Nothing has been created.
Repository: `valeratech/email-authentication-security` (private until Project 1 is finished).
Revision 2 (2026-11-16): creation method and working environment changed to WSL Ubuntu with GitHub CLI. Ryan has confirmed the four-folder layout for the Reviewer.

## Review request

Please review the layout, the creation method and the safety controls (masking, raw-versus-masked evidence, .gitignore coverage). Give findings with an ID, a severity, and a recommended change. The four open items at the end are decided by Ryan; your view on each is welcome.

## Context the Reviewer needs

- The repository is a lab-only portfolio hub: Ryan rebuilds email authentication and security on his own test domain and his own lab hosts. It is never presented as production or paid work.
- Nothing from Ryan's former employer enters the repository: no customer domains, internal procedures, tickets, or vendor-account data.
- Masking is mandatory before commit: IP addresses and hostnames in DMARC reports, private lab IPs, workstation paths, account IDs, API keys, DKIM private keys, passwords and personal email addresses. Keys and secrets never enter Git.
- Any lab mail server must refuse relaying for outsiders and be tested for it before it faces the internet.
- Only built and verified work is described as done; everything else is labelled "planned".

## Working environment

- Commands for this repository run in **WSL Ubuntu (bash)**, using git and the GitHub CLI (`gh`), which Ryan already uses for his other projects.
- Git identity is already set to Ryan's name and his GitHub **no-reply** address, so no personal email address enters the commit history.
- The working copy lives inside the WSL filesystem (Ryan's Linux home directory), not under `/mnt/c`. This keeps line endings and file permissions native to Linux and keeps Windows workstation paths out of anything committed.

## Creation method

- Pre-check: `gh auth status` shows an account that can create repositories under `valeratech`.
- Create the repository **empty and private** with `gh repo create valeratech/email-authentication-security --private`, with no README, .gitignore or license options.
- The approved scaffold becomes the first commit, pushed from WSL.

## Proposed layout

| Path | Purpose |
|---|---|
| `README.md` | Hub index: what the repository is, a lab-only statement, how lab work differs from production experience, and a project table with every project marked **planned** |
| `SECURITY.md` | What never enters Git (keys, secrets, unmasked reports), the masking rule in brief, and how to report an exposure |
| `.gitignore` | Blocks private keys (`*.key`, `*.pem`, `*.private`), env and secret files, raw evidence folders, and raw DMARC report archives (`*.xml.gz`, `*.zip`) |
| `.gitattributes` | Forces LF line endings, so files edited from Windows tools never commit CRLF |
| `LICENSE` | **Open item:** which license, or none |
| `docs/lab-environment.md` | Test domain, DNS provider (Cloudflare) and lab hosts, using placeholders until real values are approved for publication |
| `docs/masking-standard.md` | How masking works: IPv4 replaced with RFC 5737 documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24), IPv6 with RFC 3849 (2001:db8::/32), third-party domains and hostnames with RFC 2606 names (example.com, example.net), plus how account IDs, paths and email addresses are redacted |
| `docs/evidence-standard.md` | What counts as verification evidence, file naming, and the raw-versus-masked rule: raw output stays in `evidence/raw/` (git-ignored), and only `evidence/masked/` is committed |
| `templates/project-README.md` | Fixed sections every project uses: Goal, Design, Build steps, Verification, Left out, Status |
| `01-spf-dkim-dmarc/README.md` | DNS authentication on the test domain (Cloudflare): SPF, DKIM public key, DMARC policy stepped none to quarantine to reject. **Planned**. Comes first |
| `02-postfix-dovecot/README.md` | The mail server: TLS, submission and authentication, DKIM signing, inbound SPF/DKIM/DMARC checks, open-relay testing. **Planned**. Depends on 01. Its one home is here; the Linux Infrastructure hub cross-links to it |
| `03-mta-sts-tls-rpt/README.md` | MTA-STS policy and TLS reporting. **Planned**. Depends on 02's TLS certificates |
| `04-dmarc-report-handling/README.md` | Parsing DMARC aggregate reports, masked before publication. **Planned**. Depends on 01's DMARC reporting address |

All four projects are parts of one Postfix/Linux mail build, ordered by dependency. Each project folder also gets `evidence/masked/` (committed; kept with a `.gitkeep` file) and `evidence/raw/` (git-ignored).

The later, optional work (BIMI, ARC, relay or smarthost pattern, spoofing and look-alike detection) is listed in the hub README as **candidates**, with no folders until Ryan picks them.

## Open items (Ryan decides)

1. License: which one, or none.
2. Whether the test domain's real name may appear in published evidence, or stays a placeholder.
3. Whether this layout should match the Linux Infrastructure hub's conventions (folder naming, README sections).
4. Whether to add a local secret scan before the first commit (for example a gitleaks pre-commit hook).
