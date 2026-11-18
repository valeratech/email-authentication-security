#!/usr/bin/env bash
# ignore-control.sh: proves the ignore rules and the path gate, including their limits.
#
# Every scenario runs in its own scratch repository inside a temporary directory, using
# harmless synthetic files (each holds only the word "synthetic"). Nothing is created in
# the real working tree, and the scratch repositories are cut off from any parent Git
# context, so the script behaves the same from a shell, from a commit hook and in CI.
#
#   S1  the rules, both directions; `git add -A` stages exactly the approved set
#   S2  directories named like approved files are ignored, with everything inside them
#   S3  a .gitignore nested in an approved directory CAN admit a prohibited file; the
#       path gate rejects it anyway
#   S4  a force-added ignored file is rejected
#   S5  an approved path with the wrong type or mode is rejected: symlink, gitlink,
#       stray executable bit, missing executable bit
#   S6  a prohibited entry that exists only in the index is rejected
#   S7  a prohibited file committed and later deleted is rejected by the history check
#
# Exit 0 = every expectation held. Exit 1 = an expectation failed.
# Exit 2 = setup or Git error. Exit 2 is a failure, never a pass.
set -uo pipefail
export LC_ALL=C

die() { printf 'ignore-control ERROR: %s\n' "$*" >&2; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || die "cannot resolve the repository root"
RULES="$ROOT/.gitignore"
GATE="$ROOT/scripts/check-paths.sh"
[ -r "$RULES" ] || die "no readable .gitignore at the repository root"
[ -x "$GATE" ] || die "scripts/check-paths.sh is missing or not executable"

# Cut the scratch repositories off from the caller's Git context. A commit hook exports
# GIT_DIR, GIT_INDEX_FILE and friends; left in place they would point scratch commands at
# the real repository. User and system configuration could change ignore behaviour.
local_vars="$(git rev-parse --local-env-vars)" || die "git rev-parse --local-env-vars failed"
for v in $local_vars; do unset "$v"; done
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1

TMP="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$TMP"' EXIT

# An empty home, so no per-user ignore file is found either, and a fixed synthetic
# identity for the scratch commits in S7.
mkdir "$TMP/home" || die "mkdir failed"
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home"
export GIT_AUTHOR_NAME="ignore control" GIT_COMMITTER_NAME="ignore control"
export GIT_AUTHOR_EMAIL="control@example.invalid" GIT_COMMITTER_EMAIL="control@example.invalid"

FAILS=0
CHECKS=0
SCN=setup
fail() { printf 'FAIL [%s]: %s\n' "$SCN" "$*"; FAILS=$((FAILS+1)); }
ok()   { CHECKS=$((CHECKS+1)); }

g() { git "$@" || die "git $1 failed in scenario $SCN"; }

new_repo() { # new_repo <scenario id>: fresh scratch repository holding the real rules
  SCN="$1"
  mkdir "$TMP/$SCN" || die "mkdir failed"
  cd "$TMP/$SCN" || die "cd failed"
  g init -q .
  cp "$RULES" .gitignore || die "cannot copy the rules"
}

put() { # put <path>...: create synthetic files
  local p
  for p in "$@"; do
    mkdir -p "$(dirname "$p")" || die "mkdir failed for $p"
    printf 'synthetic\n' > "$p" || die "cannot write $p"
  done
}

is_ignored() { # 0 = ignored, 1 = not ignored; anything else is a Git error
  local rc=0
  git check-ignore -q -- "$1" || rc=$?
  case "$rc" in
    0) return 0 ;;
    1) return 1 ;;
    *) die "git check-ignore failed ($rc) on $1 in scenario $SCN" ;;
  esac
}

staged() { git ls-files > "$TMP/staged.$SCN" || die "git ls-files failed in $SCN"; sort "$TMP/staged.$SCN"; }

gate() { # gate <expected exit> [--history]: run the path gate; exit 2 from it is fatal
  local want="$1" rc=0; shift
  "$GATE" "$@" > "$TMP/gate.log" 2>&1 || rc=$?
  [ "$rc" -le 1 ] || { cat "$TMP/gate.log"; die "check-paths could not run in scenario $SCN"; }
  if [ "$rc" -ne "$want" ]; then
    fail "check-paths exited $rc, expected $want"; sed 's/^/    /' "$TMP/gate.log"
  else
    ok
  fi
}

gate_names() { # gate_names <path>...: the last gate output must name each path as rejected
  local p
  for p in "$@"; do
    if grep -qF -- "$p" "$TMP/gate.log"; then ok; else fail "check-paths did not name $p"; fi
  done
}

# The approved set: every path this repository holds, plus one future review round.
APPROVED=(
  .gitignore .gitattributes .gitleaks.toml .pre-commit-config.yaml .audit-allow
  README.md SECURITY.md
  .github/workflows/ci.yml
  docs/project-repository-requirements.md
  reviews/README.md
  reviews/BP001-R02-builder.md reviews/BP001-R02-reviewer.md
  reviews/BP001-R03-builder.md reviews/BP001-R03-reviewer.md
  reviews/BP001-R04-builder.md reviews/BP001-R04-reviewer.md
  reviews/BP001-R05-builder.md reviews/BP001-R05-reviewer.md
  reviews/BP001-R06-builder.md reviews/BP001-R06-reviewer.md
  scripts/audit-sanitize.sh scripts/check-paths.sh
  scripts/ignore-control.sh scripts/negative-control.sh
)

# Prohibited paths, one group per category. Several of these synthetic names look like
# hostnames to audit-sanitize.sh, so those lines carry its inline exemption marker.
PROHIBITED=(
  # raw evidence, at any depth
  evidence/raw/report.xml project/evidence/raw/headers.txt evidence-working/session.log  # audit-ok
  # private keys, and certificates that contain keys
  server.key chain.pem dkim.private store.p12 store.pfx scripts/signing.key  # audit-ok
  # credentials and the local deny-list
  .env .env.local credentials.txt api.secret .audit-denylist  # audit-ok
  # SSH private keys, which have no extension
  id_rsa id_ed25519 docs/id_ed25519
  # raw report archives
  report.xml.gz reports.zip reports.tar reports.tgz  # audit-ok
  # raw email and packet captures
  message.eml mail.mbox capture.pcap capture.pcapng reviews/message.eml  # audit-ok
  # temporary files and backups
  .README.md.swp README.md.bak notes.tmp docs/notes.md~  # audit-ok
  # local Python artifacts
  .venv/pyvenv.cfg __pycache__/audit.cpython-312.pyc  # audit-ok
  # images
  screenshot.png docs/diagram.png
  # anything unplanned: unknown names, types and folders
  notes.txt docs/notes.txt docs/nested/page.md scripts/tool.py
  new-folder/README.md .github/dependabot.yml
)

# Directories named like approved files (S2). The first five are the Reviewer's cases.
MASQUERADE=(
  README.md/raw.key docs/nested.md/raw.key reviews/raw.md/.env
  scripts/nested.sh/raw.key .github/workflows/nested.yml/raw.key
  SECURITY.md/notes.md .audit-allow/entry .gitleaks.toml/rules.md
  reviews/BP001-R09-builder.md/notes.md
)

# ---- S1: the rules, both directions -----------------------------------------------------
new_repo S1
put "${APPROVED[@]}" "${PROHIBITED[@]}"
cp "$RULES" .gitignore || die "cannot copy the rules"
for p in "${PROHIBITED[@]}"; do
  if is_ignored "$p"; then ok; else fail "not ignored: $p"; fi
done
for p in "${APPROVED[@]}"; do
  if is_ignored "$p"; then fail "approved file is ignored: $p"; else ok; fi
done
g add -A
# Set the executable bit in the index directly, so the result does not depend on the
# filesystem. Only for scripts that were staged: if the rules are broken, that is a
# failed expectation below, not a setup error here.
for p in scripts/audit-sanitize.sh scripts/check-paths.sh scripts/ignore-control.sh scripts/negative-control.sh; do
  if staged | grep -qxF "$p"; then g update-index --chmod=+x "$p"; fi
done
expected="$(printf '%s\n' "${APPROVED[@]}" | sort)"
if [ "$(staged)" = "$expected" ]; then ok; else
  fail "the staged set differs from the approved set (< expected, > staged):"
  diff <(printf '%s\n' "$expected") <(staged) | sed 's/^/    /'
fi
gate 0

# ---- S2: directories named like approved files -------------------------------------------
new_repo S2
put "${MASQUERADE[@]}"
for p in "${MASQUERADE[@]}"; do
  if is_ignored "$p"; then ok; else fail "not ignored: $p"; fi
done
g add -A
if [ "$(staged)" = ".gitignore" ]; then ok; else
  fail "git add -A staged more than .gitignore:"; staged | sed 's/^/    /'
fi
g add -f -- "${MASQUERADE[0]}" "${MASQUERADE[1]}"
gate 1
gate_names "${MASQUERADE[0]}" "${MASQUERADE[1]}"

# ---- S3: a nested .gitignore admits a prohibited file -------------------------------------
new_repo S3
put docs/raw.key
printf '!raw.key\n' > docs/.gitignore || die "cannot write the nested rule"
g add -A
if staged | grep -qxF "docs/raw.key"; then
  printf 'note [S3]: the nested rule admitted docs/raw.key, as expected; ignore rules alone cannot stop this\n'
else
  g add -f docs/raw.key
fi
gate 1
gate_names docs/raw.key

# ---- S4: a force-added ignored file -------------------------------------------------------
new_repo S4
put project/evidence/raw/headers.txt .audit-denylist
g add -A
g add -f project/evidence/raw/headers.txt .audit-denylist
gate 1
gate_names project/evidence/raw/headers.txt .audit-denylist
if grep -qF 'matches an ignore rule' "$TMP/gate.log"; then ok; else
  fail "the tracked-but-ignored check did not report the force-added file"
fi

# ---- S5: approved paths with the wrong type or mode ---------------------------------------
new_repo S5
put README.md scripts/check-paths.sh
ln -s README.md SECURITY.md || die "ln failed"
g add -f README.md scripts/check-paths.sh SECURITY.md
g update-index --chmod=+x README.md
g update-index --chmod=-x scripts/check-paths.sh
g update-index --add --cacheinfo 160000,1111111111111111111111111111111111111111,docs/project-repository-requirements.md
gate 1
gate_names SECURITY.md README.md scripts/check-paths.sh docs/project-repository-requirements.md

# ---- S6: a prohibited entry that exists only in the index ---------------------------------
new_repo S6
put notes.txt
g add -A
g add -f notes.txt
rm notes.txt || die "rm failed"
[ ! -e notes.txt ] || die "notes.txt still present"
gate 1
gate_names notes.txt

# ---- S7: committed, then deleted ----------------------------------------------------------
new_repo S7
put README.md
g add -A
g commit -q -m "approved files only"
gate 0 --history
put docs/raw.key
g add -f docs/raw.key
g commit -q -m "a prohibited file is committed"
g rm -q docs/raw.key
g commit -q -m "and deleted again"
gate 0
gate 1 --history
gate_names docs/raw.key

# -------------------------------------------------------------------------------------------
if [ "$FAILS" -eq 0 ]; then
  printf 'ignore control PASS: %d checks across 7 scenarios (%d prohibited paths, %d approved paths, %d directory cases)\n' \
    "$CHECKS" "${#PROHIBITED[@]}" "${#APPROVED[@]}" "${#MASQUERADE[@]}"
  exit 0
fi
printf 'ignore control FAIL: %d expectation(s) failed\n' "$FAILS"
exit 1
