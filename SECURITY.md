# Security

This repository is an index. It holds documentation, a review record and its own commit
gates. It runs no service and holds no lab evidence, no configuration and no credentials.

## What never enters this repository

- Credentials, tokens, private keys, DKIM keys and certificate-authority state.
- Raw lab evidence of any kind: reports, logs, message files, packet captures. Evidence
  belongs to the project repositories, and only in masked form.
- Real addresses, hostnames, account or tenant identifiers, home paths and personal email
  addresses. Documentation uses the reserved values in RFC 5737, RFC 3849 and RFC 2606.
- Anything from an employer or a production system: customer domains, internal
  procedures, tickets, vendor-account data.
- Images and other binary files.

How this is enforced, and where the enforcement stops, is described under "Commit gates"
in [README.md](README.md).

## If something sensitive is committed

Deleting the file in a new commit is not enough. The value stays in the history, and the
history is what becomes public.

1. **If it is a credential, revoke or rotate it first.** Do this before anything else,
   and assume the old value is compromised from the moment it was pushed.
2. **If it is an identifier, it cannot be revoked.** An address, a hostname or a name has
   no rotation step. Go straight to containment, and assume the value is known to anyone
   who could read the repository while it was exposed.
3. **Contain.** Stop pushing. If the repository is public, the owner decides whether to
   make it private while the history is repaired.
4. **Remediate the history.** Remove the value from every commit and every ref, not only
   from the latest one, then run the full gate again over the rewritten history. Copies
   outside the repository (clones, forks, caches) are outside this control.
5. **Record it** in [reviews/](reviews/), describing the class of value and the fix
   without repeating the value.

A CI failure after a push is handled the same way. CI runs after the push has landed, so
it detects; it does not prevent.

## Before visibility changes

This repository is private until a publication review has passed. The review is bound to
one exact commit and covers every ref that will become public: CI passing on that commit;
Gitleaks, the audit and the path gate over the full history; a local deny-list search of
every commit's content and every commit message; and the author and committer identity on
every commit. A commit added after the review, including the review's own record, is
checked the same way before visibility changes.

## Reporting

If you find a sensitive value in this repository or its history, open an issue that names
the file and the commit. Do not repeat the value in the issue.
