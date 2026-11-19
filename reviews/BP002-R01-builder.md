# BP-002 R01: List google-workspace-administration as planned

| | |
|---|---|
| From → To | Builder → Reviewer |
| Date | 2026-11-19 |
| Requests | A ruling on one change to the index, and on how this round is recorded |
| Authorizes | Nothing. The commit and the push each need the owner's separate approval |
| Base | `main` at `6e721e312cf7cd59ff2f05bbf67559dfb66a507c` (tree `da2e92a57d93fa938ea122462e10f910af6e5202`) |

## 1. Why now

The owner made `google-workspace-administration` an official project of this index. Its Section 1 (scope and safety) was accepted by the project's own Reviewer on 2026-11-19, ruling S01-R02. The ruling's SHA-256 is `27e8e53e4553dbc3e8e63deb77dd241334ea2d082d8bd3af1ce4de445199d99a`. It is supplied with this round, and it states that the hub may now list the project as planned.

Under "How a project joins this index", an official project is listed as **planned** until something in it has been built and verified. Nothing has been: the project's repository is not created yet, and no lab work has started.

## 2. The change

The change touches only `README.md`: one new row in the Projects table, and one sentence after the status rule.

```diff
 | [secure-mail-platform](…) | … | … | **In progress.** … |
+| google-workspace-administration (repository not yet public, so not linked) | A Google Workspace administration lab, re-run end to end on the current Admin console: directory, Gmail, Calendar and Drive settings, endpoints, 2SV, SSO and Secure LDAP, Vault and audit. Its mail section takes a real domain from parked to SPF, DKIM and DMARC aligned, and back. Nine sections, each proposed, reviewed and accepted before the next begins | A Google Workspace Business Plus trial on my own domain, ryanvalera.com, with fictional test users and synthetic data. The domain carries real mail only during a controlled window, then returns to a parked state | **Planned.** Section 1 (scope and safety): accepted by the project's Reviewer on 2026-11-19. The repository is not created yet, so there is no Status table or commit to cite |

 **Status is copied, never inferred.** … a project being public does not mean it is
-finished.
+finished. A planned project whose repository does not exist yet cites its accepted
+scope review instead, and is linked only once its repository is public.
```

**Why each part is worded this way:**
- **No link.** The repository does not exist, and it will be private at first. A link now would point at nothing.
- **The status sentence.** The index rule says status is copied from a project's Status table at a named commit. A project with no repository has neither, so the new sentence states what is cited instead. That keeps the rule true rather than quietly bending it.
- **The domain.** `ryanvalera.com` is the owner's own public domain, and it is already linked in this README. The project's accepted scope approves publishing the domain name, and only the name. No account address, tenant identifier or DNS detail appears in the row.
- **Scope and Environment** paraphrase the project's accepted Section 1. They claim nothing built.

## 3. Gate rehearsal

This was run on a copy of the repository with the same tree as `main` (`da2e92a5…`) and the change staged. A placeholder deny-list stood in for the owner's private one.

| Gate | Result |
|---|---|
| Path gate | `check-paths PASS (index): 24 entries` |
| Sensitive-content audit (staged) | CLEAN |
| Hooks on `README.md` | All passed or had nothing to check. The upstream Gitleaks hook was skipped in the rehearsal because it cannot be built offline |
| Gitleaks (`dir`, pinned 8.21.2) | No leaks |
| Resulting tree | `6bd19439d6abb6a91daa69723f20044e4844c018` |

On the owner's machine, the commit runs the upstream Gitleaks hook and the audit with the real deny-list. CI then runs as for every commit. Expected after the push: 3 commits reachable, 0 merges, 3 scanned, 24 index entries, and 72 historical path entries across 3 commits.

## 4. How this round is recorded

Proposed: this round and its ruling are committed as written, as design rounds are, together with the change. That is one commit after the ruling:
- `README.md` modified
- `reviews/BP002-R01-builder.md` and `reviews/BP002-R01-reviewer.md` added
- `reviews/README.md` modified, with the two rows added to its table

That changes the expected counts to 26 index entries and 74 historical path entries across 3 commits. The ruling may instead keep the records out of the repository; then the commit is `README.md` alone, with the counts in section 3.

## 5. Ruling requested

1. The README change in section 2, as worded.
2. How the round is recorded (section 4).
