# Reviews

The Builder/Reviewer record for this repository. Nothing is created, committed or
published on the strength of a review alone: each of those needs the owner's separate
approval.

## Protocol

- The **Builder** submits a proposal.
- The **Reviewer** returns a disposition, **ACCEPT**, **REVISE** or **REJECT**, with
  numbered findings.
- The Builder answers every finding in one consolidated revision: accepting it, or
  disagreeing with evidence for the Reviewer to rule on.
- The **owner** (the "Operator" in the rounds) decides every open item and authorizes
  every action.
- Each design round is committed **as written**. A correction is a new file, never an
  edit to an earlier round, so the record shows what was proposed, what was challenged,
  and why it changed.

## Naming

```text
BP<number>-R<round>-<role>.md        BP001-R02-reviewer.md, BP001-R03-builder.md
```

BP stands for Builder Proposal. The commit gates admit a review file only under this
name, directly inside this folder.

## Record

| File | Role | Subject | Disposition |
|---|---|---|---|
| [BP001-R02-builder.md](BP001-R02-builder.md) | Builder | Repository scaffold with four project folders | Reviewed in R02 |
| [BP001-R02-reviewer.md](BP001-R02-reviewer.md) | Reviewer | Review of R02 | REVISE (B01 to B05, N01 to N07) |
| [BP001-R03-builder.md](BP001-R03-builder.md) | Builder | Index hub in place of the four folders; answers to every finding | Reviewed in R03 |
| [BP001-R03-reviewer.md](BP001-R03-reviewer.md) | Reviewer | Ruling on R03 | REVISE, limited to B01 and B05. Index architecture accepted; B02 and B03 closed; B04 withdrawn |
| [BP001-R04-builder.md](BP001-R04-builder.md) | Builder | Path-gate correction and the complete commit candidate | Reviewed in R04 |
| [BP001-R04-reviewer.md](BP001-R04-reviewer.md) | Reviewer | Ruling on R04 | REVISE, limited to B05. B01 closed. Three audit corrections required (B05a to B05c) |
| [BP001-R05-builder.md](BP001-R05-builder.md) | Builder | Audit corrections: failed searches, binary content, IPv6 | Reviewed in R05 |
| [BP001-R05-reviewer.md](BP001-R05-reviewer.md) | Reviewer | Ruling on R05 | ACCEPT. B05 closed; no design blockers |
| [BP001-R06-builder.md](BP001-R06-builder.md) | Builder | CI: refuse merge commits, scan the checked-out files | Ruled in R06 |
| [BP001-R06-reviewer.md](BP001-R06-reviewer.md) | Reviewer | Ruling on R06 | ACCEPT. Merge refusal and checked-out file scan accepted; count reconciliation accepted for Gitleaks 8.21.2 |
| [BP002-R01-builder.md](BP002-R01-builder.md) | Builder | List google-workspace-administration as planned | Ruled in R01 |
| [BP002-R01-reviewer.md](BP002-R01-reviewer.md) | Reviewer | Ruling on BP-002 R01 | ACCEPT. Index row and status-rule sentence accepted; both rounds recorded with the change |

## Notes on the record

- **This record covers the design of the scaffold, R02 to R06.** The operational records
  that followed (qualification and publication) are kept privately by the owner.
- **R01** was a draft in conversation and was never submitted. R02 is the first round.
- **BP001-R02-reviewer.md** is the Reviewer's own plain-Markdown reissue of the R02
  review. Its findings and disposition are unchanged; its closing note says what the
  reissue replaced.
- **R03's attachment** was revision 2 of
  [docs/project-repository-requirements.md](../docs/project-repository-requirements.md).
  Revision 3, which adds the clarifications from the R03 ruling, is the first committed
  version.
- **Earlier rounds describe earlier designs.** The `.gitignore` and control script printed
  in BP001-R03-builder.md are the ones the R03 ruling found incomplete, and the audit
  described in BP001-R04-builder.md is the one the R04 ruling found incomplete. The files
  in this repository are the corrected ones.
