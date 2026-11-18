#!/usr/bin/env bash
# check-paths.sh: the path-and-type gate.
#
# Reads what Git is actually holding and compares every entry with a fixed manifest
# written in this file. It consults no .gitignore, no exclude file and no ignore setting
# to decide what is allowed, so no ignore rule, anywhere, can widen the result.
#
#   ./scripts/check-paths.sh             the index: everything staged or tracked
#   ./scripts/check-paths.sh --history   every commit reachable from any ref
#
# An entry passes only if its path is in the manifest AND it is a regular file with the
# mode the manifest gives. A symlink (120000), a gitlink (160000) or a file inside a
# directory that is named like an approved file can never pass.
#
# Adding a file to this repository means adding it here, in a reviewed change.
#
# Exit 0 = every entry allowed.
# Exit 1 = at least one entry rejected.
# Exit 2 = the check could not run (Git failed, or there was nothing to check).
#          Exit 2 is a failure. It is never a pass.
set -uo pipefail
export LC_ALL=C

die() { printf 'check-paths ERROR: %s\n' "$*" >&2; exit 2; }

REGULAR=100644
EXECUTABLE=100755

# ----------------------------------------------------------------------------------------
# The manifest
# ----------------------------------------------------------------------------------------
declare -A EXACT=(
  [.gitignore]=$REGULAR
  [.gitattributes]=$REGULAR
  [.gitleaks.toml]=$REGULAR
  [.pre-commit-config.yaml]=$REGULAR
  [.audit-allow]=$REGULAR
  [README.md]=$REGULAR
  [SECURITY.md]=$REGULAR
  [.github/workflows/ci.yml]=$REGULAR
  [docs/project-repository-requirements.md]=$REGULAR
  [reviews/README.md]=$REGULAR
  [scripts/audit-sanitize.sh]=$EXECUTABLE
  [scripts/check-paths.sh]=$EXECUTABLE
  [scripts/ignore-control.sh]=$EXECUTABLE
  [scripts/negative-control.sh]=$EXECUTABLE
)

# Review rounds are added over time, so they are admitted by their declared naming
# convention: a direct child of reviews/, never a nested path.
REVIEW_RE='^reviews/BP[0-9]{3}-R[0-9]{2}-(builder|reviewer)\.md$'

required_mode() { # prints the mode the manifest requires for a path, or nothing
  local p="$1"
  if [[ -n "${EXACT[$p]+set}" ]]; then printf '%s' "${EXACT[$p]}"; return 0; fi
  if [[ "$p" =~ $REVIEW_RE ]]; then printf '%s' "$REGULAR"; return 0; fi
  return 0
}

# ----------------------------------------------------------------------------------------
case "${1:-}" in
  "")        SCOPE=index ;;
  --history) SCOPE=history ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  *)         die "unknown argument: $1" ;;
esac
[ $# -le 1 ] || die "too many arguments"

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git working tree"
cd "$TOP" || die "cannot enter the repository root"

TMP="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$TMP"' EXIT

REJECTED=0
CHECKED=0

check_listing() { # check_listing <file of NUL-separated "meta TAB path" records> <label>
  local listing="$1" label="$2" rec meta path mode want
  while IFS= read -r -d '' rec; do
    case "$rec" in *$'\t'*) ;; *) die "unparseable entry from Git in $label" ;; esac
    meta="${rec%%$'\t'*}"
    path="${rec#*$'\t'}"
    mode="${meta%% *}"
    CHECKED=$((CHECKED+1))
    want="$(required_mode "$path")"
    if [ -z "$want" ]; then
      printf 'REJECT  %-8s %q  (path is not in the manifest)\n' "$label" "$path"
      REJECTED=$((REJECTED+1))
    elif [ "$mode" != "$want" ]; then
      printf 'REJECT  %-8s %q  (mode %s, manifest requires %s)\n' "$label" "$path" "$mode" "$want"
      REJECTED=$((REJECTED+1))
    fi
  done < "$listing"
}

if [ "$SCOPE" = index ]; then
  git ls-files -s -z > "$TMP/index" || die "git ls-files failed"
  check_listing "$TMP/index" "index"
  [ "$CHECKED" -gt 0 ] || die "the index is empty: refusing to report a pass after checking nothing"

  # Defense in depth only. This list depends on ignore rules, so it never decides what is
  # allowed; it can only add a rejection.
  git ls-files -ci --exclude-standard -z > "$TMP/ignored" || die "git ls-files -ci failed"
  while IFS= read -r -d '' path; do
    printf 'REJECT  %-8s %q  (tracked, but matches an ignore rule)\n' "index" "$path"
    REJECTED=$((REJECTED+1))
  done < "$TMP/ignored"
else
  shallow="$(git rev-parse --is-shallow-repository)" || die "git rev-parse failed"
  [ "$shallow" = "false" ] || die "shallow clone: a history check here would prove nothing"
  git rev-list --all > "$TMP/commits" || die "git rev-list failed"
  COMMITS=0
  while IFS= read -r commit; do
    [ -n "$commit" ] || continue
    COMMITS=$((COMMITS+1))
    git ls-tree -r -z "$commit" > "$TMP/tree" || die "git ls-tree failed on $commit"
    check_listing "$TMP/tree" "${commit:0:7}"
  done < "$TMP/commits"
  [ "$COMMITS" -gt 0 ] || die "no commits: refusing to report a pass after checking nothing"
fi

if [ "$REJECTED" -gt 0 ]; then
  printf 'check-paths FAIL (%s): %d rejected of %d entries checked\n' "$SCOPE" "$REJECTED" "$CHECKED"
  exit 1
fi
if [ "$SCOPE" = index ]; then
  printf 'check-paths PASS (index): %d entries, all in the manifest\n' "$CHECKED"
else
  printf 'check-paths PASS (history): %d entries across %d commits, all in the manifest\n' "$CHECKED" "$COMMITS"
fi
exit 0
