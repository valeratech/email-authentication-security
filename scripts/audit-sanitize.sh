#!/usr/bin/env bash
#
# audit-sanitize.sh: project-tuned sensitive-content audit.
#
# gitleaks catches secret SHAPES (keys, tokens). This catches what actually leaks from
# documentation written by someone with a production job: employer identifiers, customer
# domains, production addressing, license keys, internal path layouts, and host-machine
# details.
#
# RETUNED for email-authentication-security, an index that holds no lab evidence and no
# configuration. No lab subnet is approved here: any private address, IPv4 or IPv6, is a
# finding. Only documentation values (RFC 5737, RFC 3849, RFC 2606) and the standards
# hosts the index links to pass silently.
#
# Matches are CLASSIFIED, not just listed: approved documentation values pass silently,
# and only undecided items are surfaced for a human call.
#
# Usage:
#   ./scripts/audit-sanitize.sh              tracked and staged files, working copies
#   ./scripts/audit-sanitize.sh --staged     the staged content of every file in the
#                                            index. This is what the commit hook runs.
#   ./scripts/audit-sanitize.sh --all        every tracked file, working copies (CI)
#   ./scripts/audit-sanitize.sh <paths...>   specific paths
#
# Options (before any path):
#   --show-values      print the matched values. Off by default, so that hook output and
#                      CI logs never repeat a sensitive value. Use it locally only.
#   --no-denylist      run without the deny-list. For CI only, where the list cannot
#                      exist. Without this option a missing deny-list is an error.
#   --denylist FILE    read the deny-list from FILE instead of .audit-denylist.
#
# Exit 0 = CLEAN. Exit 1 = decisions required.
# Exit 2 = the audit could not run, or could not finish. Exit 2 is a failure, never a
#          pass: a search that fails has not shown that anything is clean.

set -uo pipefail
# Bytes, not characters: no file is skipped or misread because of its encoding, and
# letter-case folding is ASCII only.
export LC_ALL=C

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'
die() { printf '%sERROR%s %s\n' "$RED" "$RST" "$*"; exit 2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || die "cannot resolve the repository root"

# ----------------------------------------------------------------------------------------
# Approved values
# ----------------------------------------------------------------------------------------
# IPv4 literals that are never a leak: loopback, link-local, the RFC 5737 documentation
# ranges, wildcards and netmasks.
# NOTE: no RFC 1918 space is auto-approved. This index publishes no lab addresses, and a
# stray private address is exactly what a production paste looks like.
IP_OK_RE="^(127\.[0-9.]+|169\.254\.[0-9.]+|192\.0\.2\.[0-9]+|198\.51\.100\.[0-9]+|203\.0\.113\.[0-9]+|0\.0\.0\.0|255\.[0-9.]+)$"

# IPv6 literals that are never a leak are decided in ipv6_class below: the unspecified
# address, loopback, and the RFC 3849 documentation prefix 2001:db8::/32. Nothing else:
# unique-local, link-local and global addresses are all findings.

# Domains that legitimately appear in this index.
DOMAIN_OK_RE='(\.test|\.invalid|\.example|(^|\.)(example\.(com|org|net)|github\.com|githubusercontent\.com|ietf\.org|rfc-editor\.org|iana\.org))$'

# Lines that only show a placeholder where a credential would go.
PLACEHOLDER_RE='(changeme|placeholder|example|redacted|<[a-z-]+>|\$\{|xxxx|your-)'

# Committed allowlist of extra approved strings, one per line.
ALLOWFILE="${ROOT}/.audit-allow"

# GITIGNORED denylist: employer, customer, and production strings that must never appear.
# Keeping it out of git is the point: the denylist itself would be a leak.
DENYFILE="${ROOT}/.audit-denylist"

# The only files in which the inline exemption marker is honoured. Each one is reviewed.
# Anywhere else the marker has no effect and the line is audited like any other.
# Denylisted terms are never exempt, in any file.
MARKER='audit-ok'
MARKER_FILES=(
  scripts/audit-sanitize.sh
  scripts/ignore-control.sh
  .gitleaks.toml
  reviews/BP001-R03-builder.md
)

# ----------------------------------------------------------------------------------------
FINDINGS=0
SHOW=0
USE_DENY=1
MODE=default

usage() { sed -n '3,35p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --all)          MODE=all; shift ;;
    --staged)       MODE=staged; shift ;;
    --show-values)  SHOW=1; shift ;;
    --no-denylist)  USE_DENY=0; shift ;;
    --denylist)     [ $# -ge 2 ] || usage; DENYFILE="$2"; shift 2 ;;
    -h|--help)      usage ;;
    --)             shift; break ;;
    -*)             die "unknown option: $1" ;;
    *)              break ;;
  esac
done
if [ $# -gt 0 ]; then
  [ "$MODE" = default ] || die "give either paths or --$MODE, not both"
  MODE=paths
fi

for tool in grep file tr cmp mktemp; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done

TMP="$(mktemp -d)" || die "mktemp failed"
trap 'rm -rf "$TMP"' EXIT

report() { # report <severity> <class> <file:line> <detail>
  local sev="$1" cls="$2" loc="$3" det="$4" col="$YEL"
  [ "$sev" = HIGH ] && col="$RED"
  printf '%s  %-4s%s  %-22s %s\n' "$col" "$sev" "$RST" "$cls" "$loc"
  printf '        %s%s%s\n' "$DIM" "$det" "$RST"
  FINDINGS=$((FINDINGS+1))
}

val() { # val <matched value>: the value itself, or a placeholder unless --show-values
  if [ "$SHOW" -eq 1 ]; then printf '%s' "$1"; else printf '[value withheld; rerun locally with --show-values]'; fi
}

marker_file() { # marker_file <path>: true if the exemption marker is honoured in this file
  local f="${1#./}" m
  for m in "${MARKER_FILES[@]}"; do [ "$f" = "$m" ] && return 0; done
  return 1
}

# ----------------------------------------------------------------------------------------
# The deny-list: read it before anything else, so that a missing list is an error however
# the rest of the run would have gone.
# ----------------------------------------------------------------------------------------
TERMS=0
if [ "$USE_DENY" -eq 1 ]; then
  if [ ! -f "$DENYFILE" ] || [ ! -r "$DENYFILE" ]; then
    printf '%sERROR%s no readable deny-list. Create .audit-denylist (it is git-ignored) listing the\n' "$RED" "$RST"
    printf '        employer, customer and production strings that must never be committed.\n'
    exit 2
  fi
  : > "$TMP/terms" || die "cannot write to the temporary directory"
  while IFS= read -r term || [ -n "$term" ]; do
    term="${term%$'\r'}"                             # a list saved with Windows line endings
    term="${term#"${term%%[![:space:]]*}"}"          # leading blanks
    term="${term%"${term##*[![:space:]]}"}"          # trailing blanks
    [ -z "$term" ] && continue
    case "$term" in \#*) continue ;; esac
    printf '%s\n' "$term" >> "$TMP/terms" || die "cannot write to the temporary directory"
    TERMS=$((TERMS+1))
  done < "$DENYFILE" || die "cannot read the deny-list"
  [ "$TERMS" -gt 0 ] || die "the deny-list holds no terms; refusing to treat it as coverage"
fi

# ----------------------------------------------------------------------------------------
# Build the candidate list
# ----------------------------------------------------------------------------------------
CAND=()
case "$MODE" in
  paths)
    cd "$ROOT" || die "cannot enter the repository root"
    CAND=("$@")
    ;;
  all)
    cd "$ROOT" || die "cannot enter the repository root"
    git ls-files -z > "$TMP/list" || die "git ls-files failed"
    mapfile -d '' -t CAND < "$TMP/list"
    ;;
  default)
    cd "$ROOT" || die "cannot enter the repository root"
    git rev-parse --git-dir >/dev/null 2>&1 || die "not a Git repository: pass the paths to audit"
    git ls-files -z > "$TMP/list" || die "git ls-files failed"
    git diff --cached --name-only -z >> "$TMP/list" || die "git diff --cached failed"
    declare -A LISTED=()
    while IFS= read -r -d '' f; do
      [ -n "${LISTED[$f]+x}" ] && continue
      LISTED["$f"]=1; CAND+=("$f")
    done < "$TMP/list"
    ;;
  staged)
    # Audit what is in the index, not the working copy: export the index to a scratch
    # directory and read the files there. A clean working copy cannot hide a staged value.
    cd "$ROOT" || die "cannot enter the repository root"
    git rev-parse --git-dir >/dev/null 2>&1 || die "--staged needs a Git repository"
    mkdir "$TMP/index" || die "cannot write to the temporary directory"
    git checkout-index --all --prefix="$TMP/index/" || die "cannot export the index"
    git ls-files -z > "$TMP/list" || die "git ls-files failed"
    mapfile -d '' -t CAND < "$TMP/list"
    ALLOWFILE="$TMP/index/.audit-allow"
    cd "$TMP/index" || die "cannot enter the exported index"
    ;;
esac

# Approvals, read once. In --staged mode these are the staged approvals.
declare -A ALLOW=()
if [ -e "$ALLOWFILE" ]; then
  if [ ! -f "$ALLOWFILE" ] || [ ! -r "$ALLOWFILE" ]; then die "cannot read the allowlist"; fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    ALLOW["$line"]=1
  done < "$ALLOWFILE" || die "cannot read the allowlist"
fi
allowed() { [ -n "${ALLOW[$1]+x}" ]; }

# ----------------------------------------------------------------------------------------
# Classify every candidate: text to be searched, or a finding in its own right.
# A file counts as binary if file(1) says so OR it holds a NUL byte. Either test alone is
# enough, so neither is a single point of failure.
# ----------------------------------------------------------------------------------------
FILES=()
SEEN=0
for f in ${CAND[@]+"${CAND[@]}"}; do
  if [ -L "$f" ]; then
    SEEN=$((SEEN+1)); report HIGH "not-a-regular-file" "$f" "a symbolic link; this index holds regular files only"
    continue
  fi
  if [ ! -e "$f" ]; then
    case "$MODE" in
      paths)  die "no such file: $f" ;;
      staged) SEEN=$((SEEN+1)); report HIGH "not-a-regular-file" "$f" "in the index but not a file (a submodule entry?)" ;;
      *)      : ;;   # tracked but deleted in the working copy: nothing to read
    esac
    continue
  fi
  SEEN=$((SEEN+1))
  if [ ! -f "$f" ]; then
    report HIGH "not-a-regular-file" "$f" "not a regular file"
    continue
  fi
  [ -r "$f" ] || die "cannot read $f"
  if [ ! -s "$f" ]; then FILES+=("$f"); continue; fi     # empty: nothing to classify

  mime="$(file -b --mime -- "$f")" || die "file(1) failed on $f"
  [[ "$mime" == *"; charset="* ]] || die "unexpected output from file(1) for $f"

  # shellcheck disable=SC2094  # both commands only read the file
  tr -d '\000' < "$f" | cmp -s - "$f"
  st=("${PIPESTATUS[@]}")
  [ "${st[0]}" -eq 0 ] || die "cannot read $f"
  case "${st[1]}" in
    0) nul=0 ;;
    1) nul=1 ;;
    *) die "cmp failed on $f" ;;
  esac

  if [[ "$mime" == *"charset=binary"* ]] || [ "$nul" -eq 1 ]; then
    report HIGH "binary-committed" "$f" "binary content; this index holds text only and blocks binaries by policy"
    continue
  fi
  FILES+=("$f")
done

# An empty file list is a failure, not a pass. A gate that reports CLEAN after
# checking nothing is worse than no gate: it teaches misplaced trust.
[ "$SEEN" -gt 0 ] || die "no files matched; refusing to report CLEAN"

printf 'Auditing %d files' "$SEEN"
[ "$MODE" = staged ] && printf ' (staged content)'
printf '\n\n'
if [ "$USE_DENY" -eq 1 ]; then
  printf '%sdeny-list: %d term(s) loaded%s\n\n' "$DIM" "$TERMS" "$RST"
else
  printf '%s  note%s  deny-list NOT checked (--no-denylist). Employer, customer and production\n' "$YEL" "$RST"
  printf '        strings are covered only by the local run that has the list.\n\n'
fi

# ----------------------------------------------------------------------------------------
# Search helpers. Every search goes through hits(), and hits() treats any grep exit other
# than 0 (matches) or 1 (no matches) as fatal. That includes an unreadable file.
# ----------------------------------------------------------------------------------------
hits() { # hits <grep letters> <-e|-f> <pattern or file>: results in $TMP/hits
  local rc=0
  grep "-HZna$1" "$2" "$3" -- "${FILES[@]}" > "$TMP/hits" 2>/dev/null || rc=$?
  [ "$rc" -le 1 ] || die "a content search failed (grep exit $rc); nothing can be reported as clean"
}
# Records in $TMP/hits are: file, a NUL byte, then "line:text". Read them with
#   while IFS= read -r -d '' f && IFS= read -r rec; do n="${rec%%:*}"; text="${rec#*:}"

declare -A EXEMPT=()
EXEMPT_NOTES=()
exempt() { [ -n "${EXEMPT[${1#./}:$2]+x}" ]; }   # exempt <file> <line>

declare -A ONCE=()
first_time() { # first_time <key>: true the first time a key is seen since ONCE was reset
  [ -n "${ONCE[$1]+x}" ] && return 1
  ONCE["$1"]=1
  return 0
}

V6=no
ipv6_class() { # ipv6_class <token>: sets V6 to ok, bad, or no (not an IPv6 literal)
  local t="${1,,}" head tail g i zero=1
  local -a H=() T=() G=()
  V6=no
  [[ "$t" == *:*:* ]] || return 0
  [[ "$t" =~ ^[0-9a-f:.]+$ ]] || return 0
  # A dotted IPv4 tail stands for the last two groups. Its value does not change the class.
  if [[ "$t" =~ ^(.*:)[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then t="${BASH_REMATCH[1]}f:f"; fi
  [[ "$t" == *.* ]] && return 0
  [[ "$t" == *:::* ]] && return 0
  if [[ "$t" == *::* ]]; then
    head="${t%%::*}"; tail="${t#*::}"
    [[ "$tail" == *::* ]] && return 0
    [[ "$head" == :* || "$head" == *: || "$tail" == :* || "$tail" == *: ]] && return 0
    IFS=: read -ra H <<<"$head"
    IFS=: read -ra T <<<"$tail"
    (( ${#H[@]} + ${#T[@]} <= 7 )) || return 0
    G=(${H[@]+"${H[@]}"})
    for ((i=${#H[@]}+${#T[@]}; i<8; i++)); do G+=(0); done
    G+=(${T[@]+"${T[@]}"})
  else
    [[ "$t" == :* || "$t" == *: ]] && return 0
    IFS=: read -ra G <<<"$t"
    (( ${#G[@]} == 8 )) || return 0
  fi
  for g in "${G[@]}"; do [[ "$g" =~ ^[0-9a-f]{1,4}$ ]] || return 0; done
  V6=bad
  for ((i=0; i<7; i++)); do (( 16#${G[i]} == 0 )) || zero=0; done
  if (( zero == 1 )) && (( 16#${G[7]} <= 1 )); then V6=ok; fi                   # :: and ::1
  if (( 16#${G[0]} == 16#2001 )) && (( 16#${G[1]} == 16#db8 )); then V6=ok; fi  # RFC 3849
  return 0
}

if [ "${#FILES[@]}" -gt 0 ]; then

  # Index the exempted lines: marked lines, in the approved files only.
  for f in "${FILES[@]}"; do
    marker_file "$f" || continue
    rc=0
    grep -naF -e "$MARKER" -- "$f" > "$TMP/marked" 2>/dev/null || rc=$?
    [ "$rc" -le 1 ] || die "a content search failed (grep exit $rc); nothing can be reported as clean"
    c=0
    while IFS=: read -r n _; do EXEMPT["${f#./}:$n"]=1; c=$((c+1)); done < "$TMP/marked"
    [ "$c" -gt 0 ] && EXEMPT_NOTES+=("$c line(s) in ${f#./}")
  done

  # --------------------------------------------------------------------------------------
  # 1. Denylist: employer / customer / production strings (highest severity)
  #    Case-insensitive. Never exempted by the marker. The term is never echoed.
  # --------------------------------------------------------------------------------------
  if [ "$USE_DENY" -eq 1 ]; then
    hits Fi -f "$TMP/terms"
    while IFS= read -r -d '' f && IFS= read -r rec; do
      report HIGH "denylisted-term" "${f}:${rec%%:*}" "matched a term from the deny-list (term not echoed here by design)"
    done < "$TMP/hits"
  fi

  # --------------------------------------------------------------------------------------
  # 2. Network addressing: IPv4
  # --------------------------------------------------------------------------------------
  hits oE -e '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'
  ONCE=()
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; m="${rec#*:}"
    exempt "$f" "$n" && continue
    first_time "$f:$n:$m" || continue
    [[ "$m" =~ $IP_OK_RE ]] && continue
    allowed "$m" && continue
    # Version-like strings can look like addresses; they still surface for a decision.
    report HIGH "unapproved-ip" "${f}:${n}" "$(val "$m") (approved: loopback and the RFC 5737 documentation ranges)"
  done < "$TMP/hits"

  # --------------------------------------------------------------------------------------
  # 3. Network addressing: IPv6
  #    Every IPv6 literal has two colons with nothing but hex digits between them, so any
  #    such line is a candidate; each token on it is then parsed. Times and MAC addresses
  #    are not IPv6 literals and do not match.
  # --------------------------------------------------------------------------------------
  hits E -e ':[0-9A-Fa-f]*:'
  ONCE=()
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; text="${rec#*:}"
    exempt "$f" "$n" && continue
    for tok in ${text//[!0-9A-Za-z:.]/ }; do
      while [[ "$tok" == .* ]]; do tok="${tok#.}"; done
      while [[ "$tok" == *. ]]; do tok="${tok%.}"; done
      [[ "$tok" == *: && "$tok" != *:: ]] && tok="${tok%:}"
      [[ "$tok" == :* && "$tok" != ::* ]] && tok="${tok#:}"
      ipv6_class "$tok"
      [ "$V6" = bad ] || continue
      first_time "$f:$n:$tok" || continue
      allowed "$tok" && continue
      report HIGH "unapproved-ipv6" "${f}:${n}" "$(val "$tok") (approved: ::, ::1 and the RFC 3849 documentation prefix)"
    done
  done < "$TMP/hits"

  # --------------------------------------------------------------------------------------
  # 4. Hostnames and domains
  # --------------------------------------------------------------------------------------
  hits oiE -e '\b([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,24}\b'
  ONCE=()
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; d="${rec#*:}"; d="${d,,}"
    exempt "$f" "$n" && continue
    first_time "$f:$n:$d" || continue
    [[ "$d" =~ $DOMAIN_OK_RE ]] && continue
    allowed "$d" && continue
    # Ignore obvious filenames (script.sh, config.d, README.md)
    [[ "$d" =~ \.(sh|md|conf|d|log|txt|yml|yaml|json|png|jpg|php|css|js|crt|pem|key|toml|ini|gz|tar|py|sql|csv|html|tpl|cf|zone|repo|rpm|sieve|nft|inc|cnf|ext|csr|srl)$ ]] && continue
    # systemd units and similar dotted non-hostnames
    [[ "$d" =~ \.(service|socket|target|timer|mount|slice|device|path|swap)$ ]] && continue
    report HIGH "unapproved-domain" "${f}:${n}" "$(val "$d") (documentation uses example.com or a .invalid name)"
  done < "$TMP/hits"

  # --------------------------------------------------------------------------------------
  # 5. Credentials and key material
  # --------------------------------------------------------------------------------------
  hits E -e '-----BEGIN .*PRIVATE KEY-----'   # audit-ok
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"
    exempt "$f" "$n" && continue
    report HIGH "private-key" "${f}:${n}" "PEM private key block: key material never enters this repository"
  done < "$TMP/hits"

  hits E -e '\b(PLSK|CLN)\.[A-Z0-9]{6,}'
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; text="${rec#*:}"
    exempt "$f" "$n" && continue
    report HIGH "license-key" "${f}:${n}" "$(val "${text:0:60}")"
  done < "$TMP/hits"

  hits E -e "(password|passwd|secret|api[_-]?key|token|DB_PASSWORD)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9!@#\$%^&*_+-]{8,}"
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; text="${rec#*:}"; lower="${text,,}"
    exempt "$f" "$n" && continue
    [[ "$lower" =~ $PLACEHOLDER_RE ]] && continue
    report HIGH "credential-literal" "${f}:${n}" "$(val "${text:0:60}")"
  done < "$TMP/hits"

  # Mail-stack credential shapes: Dovecot passdb hashes and Valkey/Redis auth literals.
  # Kept from secure-mail-platform, the project this index links to.
  hits E -e '\{(BLF-CRYPT|ARGON2I|ARGON2ID|SHA512-CRYPT|SHA256-CRYPT|SSHA512|SSHA256|MD5-CRYPT|CRYPT)\}[^[:space:]]{8,}'
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; text="${rec#*:}"
    exempt "$f" "$n" && continue
    report HIGH "mail-password-hash" "${f}:${n}" "$(val "${text:0:60}")"
  done < "$TMP/hits"

  hits E -e '(requirepass|masterauth)[[:space:]]+[^[:space:]<$]{8,}'
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; text="${rec#*:}"; lower="${text,,}"
    exempt "$f" "$n" && continue
    [[ "$lower" =~ (changeme|placeholder|redacted) ]] && continue
    report HIGH "kv-store-auth" "${f}:${n}" "$(val "${text:0:60}")"
  done < "$TMP/hits"

  # --------------------------------------------------------------------------------------
  # 6. Host machine and hypervisor identifiers
  # --------------------------------------------------------------------------------------
  hits oE -e '\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b'
  ONCE=()
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; m="${rec#*:}"
    exempt "$f" "$n" && continue
    first_time "$f:$n:$m" || continue
    report WARN "mac-address" "${f}:${n}" "$(val "$m")"
  done < "$TMP/hits"

  hits E -e '\.(vmx|vmdk|nvram|vmsn)\b|vmware-[0-9]+\.log'
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; text="${rec#*:}"
    exempt "$f" "$n" && continue
    report WARN "vmware-identifier" "${f}:${n}" "$(val "${text:0:60}")"
  done < "$TMP/hits"

  hits oE -e '(/home/|/Users/|C:\\Users\\)[A-Za-z0-9._-]+'
  ONCE=()
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; m="${rec#*:}"
    exempt "$f" "$n" && continue
    first_time "$f:$n:$m" || continue
    case "${m,,}" in /home/user|/home/lab) continue ;; esac
    report WARN "absolute-home-path" "${f}:${n}" "$(val "$m")"
  done < "$TMP/hits"

  # --------------------------------------------------------------------------------------
  # 7. Personal data
  # --------------------------------------------------------------------------------------
  hits oiE -e '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
  ONCE=()
  while IFS= read -r -d '' f && IFS= read -r rec; do
    n="${rec%%:*}"; e="${rec#*:}"; e="${e,,}"
    exempt "$f" "$n" && continue
    first_time "$f:$n:$e" || continue
    [[ "$e" =~ (\.test|\.invalid|example\.(com|org|net))$ ]] && continue
    allowed "$e" && continue
    report HIGH "email-address" "${f}:${n}" "$(val "$e")"
  done < "$TMP/hits"

fi

# ----------------------------------------------------------------------------------------
# Exemption inventory: how many lines the marker actually exempted, and where.
# ----------------------------------------------------------------------------------------
for note in ${EXEMPT_NOTES[@]+"${EXEMPT_NOTES[@]}"}; do
  printf '%sexemption marker: %s%s\n' "$DIM" "$note" "$RST"
done
[ "${#EXEMPT_NOTES[@]}" -gt 0 ] && printf '\n'

# ----------------------------------------------------------------------------------------
if [ "$FINDINGS" -eq 0 ]; then
  printf '%sCLEAN%s no items requiring a decision\n' "$GRN" "$RST"
  exit 0
fi
printf '%s%d item(s) require a decision.%s\n' "$RED" "$FINDINGS" "$RST"
printf 'Redact at the source, or add a deliberate approval to .audit-allow with a reason.\n'
exit 1
