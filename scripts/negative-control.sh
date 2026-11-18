#!/usr/bin/env bash
# Proves audit-sanitize.sh can still FAIL. A gate that only ever passes is not a gate.
#
# Exists because a real bug shipped in the portfolio template: grep omits the filename
# prefix when given exactly one file, so the field parse shifted and every pattern
# silently missed. The audit reported CLEAN on a file holding a production address and a
# real email, and single-file is precisely how pre-commit invoked it.
#
# NOTE ON CONSTRUCTION: the fixtures are ASSEMBLED at runtime, never written literally.
# A file containing a literal key header or plausible address is itself a finding, so a
# naive version of this script trips the audit, detect-private-key, and gitleaks all at
# once. Allowlisting it would blunt three gates to test one. Joining the pieces below
# keeps the committed file clean while the generated fixtures are genuinely bad.
#
# Groups:
#    1  known-bad input is rejected          7  IPv6 addresses
#    2  findings do not repeat the value     8  binary and unreadable content
#    3  known-good input passes              9  the staged content is what is audited
#    4  the exemption marker's scope        10  operational failures: every call the
#    5  the deny-list                           audit makes to grep, file, tr, cmp and
#    6  an audit of nothing is an error         git is made to fail in turn
#
# Exit 0 = every control held. Exit 1 = a control failed. Exit 2 = setup error.
set -uo pipefail
export LC_ALL=C
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

AUDIT="$PWD/scripts/audit-sanitize.sh"
[ -x "$AUDIT" ] || { printf 'ERROR: %s is missing or not executable\n' "$AUDIT"; exit 2; }
TMP=$(mktemp -d) || exit 2
trap 'rm -rf "$TMP"' EXIT

# Group 9 builds a scratch repository. Cut it off from the caller's Git context, exactly
# as ignore-control.sh does.
local_vars="$(git rev-parse --local-env-vars)" || { printf 'ERROR: git rev-parse failed\n'; exit 2; }
for v in $local_vars; do unset "$v"; done
mkdir "$TMP/home" || exit 2
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1

fails=0
checks=0
bad() { printf 'FAIL: %s\n' "$*"; fails=1; }

expect() { # expect <wanted exit> <label> <audit arguments...>
  local want="$1" label="$2" rc=0; shift 2
  "$AUDIT" "$@" > "$TMP/out.txt" 2>&1 || rc=$?
  checks=$((checks+1))
  [ "$rc" -eq "$want" ] || bad "$label (exit $rc, expected $want)"
}
says() { # says <label> <string>: the last audit output must contain it
  checks=$((checks+1))
  grep -qF -- "$2" "$TMP/out.txt" || bad "$1"
}
silent_on() { # silent_on <label> <string>: the last audit output must not contain it
  checks=$((checks+1))
  if grep -qiF -- "$2" "$TMP/out.txt"; then bad "$1"; fi
}

# ---- Fixtures -------------------------------------------------------------------------------
sp=' '
octets=(10 42 7 99)
bad_ip="$(IFS=.; printf '%s' "${octets[*]}")"
bad_domain="$(printf '%s%s%s' realcorp . com)"
bad_email="$(printf '%s@%s' admin "$bad_domain")"
dashes="$(printf -- '-%.0s' 1 2 3 4 5)"
key_header="${dashes}BEGIN RSA PRIVATE${sp}KEY${dashes}"

printf 'production host %s\ncustomer domain %s\ncontact %s\n' \
  "$bad_ip" "$bad_domain" "$bad_email" > "$TMP/bad-identifiers.txt"
printf '%s\n' "$key_header" > "$TMP/bad-keymaterial.txt"

# A Dovecot passdb hash literal, assembled so this file stays clean.
scheme="$(printf '{%s-%s}' BLF CRYPT)"
printf 'alice@lab.test:%s%s\n' "$scheme" "$(printf '$2y$05$%s' abcdefghijklmnopqrstuv)" > "$TMP/bad-mailhash.txt"

# Documentation values only, including the IPv6 forms that must pass: the RFC 3849
# prefix in three spellings, loopback, the unspecified address, and two things that look
# like IPv6 and are not (a time, and a double colon between words).
doc6="$(printf '%s:%s' 2001 db8)"
printf 'documentation host 192.0.2.10 serving www.example.com for postmaster@example.com\n' > "$TMP/good.txt"
{
  printf 'documentation hosts %s::25 and %s:0:0:0:0:0:1 and [%s::1]:443 in %s::/32\n' "$doc6" "2001:0DB8" "$doc6" "$doc6"
  printf 'fully expanded %s:0000:0000:0000:0000:0000:0001\n' "2001:0db8"
  printf 'loopback ::1, unspecified ::, logged at 12:53:01, see scope::item\n'
} >> "$TMP/good.txt"

# ---- 1. Known-bad input is rejected, one file at a time and together ----------------------
for f in "$TMP/bad-identifiers.txt" "$TMP/bad-keymaterial.txt" "$TMP/bad-mailhash.txt"; do
  expect 1 "audit passed a file it must reject: $(basename "$f")" --no-denylist "$f"
done
expect 1 "audit passed multi-file known-bad input" --no-denylist "$TMP"/bad-*.txt
# A text file in a legacy encoding must still be searched, whatever the caller's locale.
printf 'caf\351 on production host %s\n' "$bad_ip" > "$TMP/legacy-encoding.txt"
utf8_locale="$(printf '%s.%s' C UTF-8)"
rc=0; LC_ALL="$utf8_locale" "$AUDIT" --no-denylist "$TMP/legacy-encoding.txt" > "$TMP/out.txt" 2>&1 || rc=$?
checks=$((checks+1)); [ "$rc" -eq 1 ] || bad "a file in a legacy encoding was not searched (exit $rc, expected 1)"

# ---- 2. Findings do not repeat the value unless asked -------------------------------------
expect 1 "audit passed bad identifiers" --no-denylist "$TMP/bad-identifiers.txt"
silent_on "audit output repeated an address without --show-values" "$bad_ip"
silent_on "audit output repeated a domain without --show-values" "$bad_domain"

# ---- 3. Known-good input passes ------------------------------------------------------------
# Without this, the audit could simply be rejecting everything and the tests above would
# prove nothing.
expect 0 "audit rejected a file containing only documentation values" --no-denylist "$TMP/good.txt"

# ---- 4. The exemption marker works only in the approved files ------------------------------
marker="$(printf '%s-%s' audit ok)"
printf 'production host %s  # %s\n' "$bad_ip" "$marker" > "$TMP/marked.txt"
expect 1 "the exemption marker excused a line in a file that is not approved for it" --no-denylist "$TMP/marked.txt"

# ---- 5. The deny-list ----------------------------------------------------------------------
term="$(printf '%s%s' zzcontrol term)"
upper="$(printf '%s' "$term" | tr '[:lower:]' '[:upper:]')"
printf '# synthetic deny-list for the control\n%s\n' "$term" > "$TMP/deny.txt"
printf 'previously at %s, in another letter case\n' "$upper" > "$TMP/deny-probe.txt"
printf 'previously at %s  # %s\n' "$term" "$marker" > "$TMP/deny-marked.txt"

expect 0 "the deny-list probe is not clean without the list, so it proves nothing" --no-denylist "$TMP/deny-probe.txt"
expect 1 "a deny-listed term in another letter case was not caught" --denylist "$TMP/deny.txt" "$TMP/deny-probe.txt"
silent_on "audit output echoed a deny-listed term" "$term"
expect 1 "the exemption marker excused a deny-listed term" --denylist "$TMP/deny.txt" "$TMP/deny-marked.txt"
expect 0 "a clean file failed against the synthetic deny-list" --denylist "$TMP/deny.txt" "$TMP/good.txt"

# A list saved with Windows line endings and stray blanks must still match.
printf '# saved on Windows\r\n  %s \r\n' "$term" > "$TMP/deny-crlf.txt"
expect 1 "a deny-list with Windows line endings stopped matching" --denylist "$TMP/deny-crlf.txt" "$TMP/deny-probe.txt"

# A missing or empty deny-list is an error, not a pass.
expect 2 "a missing deny-list was treated as a pass" --denylist "$TMP/absent.txt" "$TMP/good.txt"
printf '# comments only\n\n' > "$TMP/deny-empty.txt"
expect 2 "an empty deny-list was treated as a pass" --denylist "$TMP/deny-empty.txt" "$TMP/good.txt"

# ---- 6. An audit of nothing is an error, and so is a path that does not exist --------------
expect 2 "an audit of a missing file was treated as a pass" --no-denylist "$TMP/absent.txt"
expect 2 "a missing file beside a good one was skipped silently" --no-denylist "$TMP/good.txt" "$TMP/absent.txt"

# ---- 7. IPv6 --------------------------------------------------------------------------------
# Each address is assembled from pieces. One per file, so that each must be caught alone.
v6_cases=(
  "$(printf '%s:%s:%s:%s::%s' fd12 3456 789a 1 25)"            # unique-local
  "$(printf '%s:%s::%s' FD00 AB 1)"                            # unique-local, upper case
  "$(printf '%s::%s' fe80 1)"                                  # link-local
  "$(printf '%s:%s::%s' 2606 4700 1111)"                       # global unicast
  "$(printf '%s:%s:%s:%s:%s:%s:%s:%s' 2a00 1 2 3 4 5 6 7)"     # eight groups, no ::
  "$(printf '%s:%s:%s:%s:%s:%s:%s:%s' fd12 3456 789a 0001 0000 0000 0000 0025)"  # unique-local, fully expanded
  "$(printf '[%s::%s]:25' fd00 9)"                             # bracketed, with a port
  "$(printf '::%s:%s.%s.%s.%s' ffff 192 0 2 1)"                # IPv4-mapped
  "$(printf '%s:%s::%s' 2001 db9 1)"                           # one digit off the RFC 3849 prefix
)
i=0
for addr in "${v6_cases[@]}"; do
  i=$((i+1))
  printf 'reachable at %s today\n' "$addr" > "$TMP/v6-$i.txt"
  expect 1 "IPv6 case $i was not caught" --no-denylist "$TMP/v6-$i.txt"
  says "IPv6 case $i was caught by something other than the IPv6 check" "unapproved-ipv6"
  core="${addr#[}"; core="${core%%]*}"
  silent_on "audit output repeated an IPv6 address without --show-values" "$core"
done

# ---- 8. Binary content ----------------------------------------------------------------------
# Under an approved-looking name, because a name says nothing about content.
printf 'text\000more\n' > "$TMP/with-nul.md"
printf '\211PNG\r\n\032\nAAAAAAAAAAAAAAAAAAAAAAAA' > "$TMP/no-nul.md"

expect 1 "a file holding a NUL byte was not rejected" --no-denylist "$TMP/with-nul.md"
says "the NUL-byte file was not reported as binary" "binary-committed"
expect 1 "a binary file with no NUL byte was not rejected" --no-denylist "$TMP/no-nul.md"
says "the binary file was not reported as binary" "binary-committed"
expect 1 "a binary file beside a clean one was not rejected" --no-denylist "$TMP/good.txt" "$TMP/with-nul.md"

# Each detector alone is enough. With file(1) replaced by one that calls everything text,
# the NUL check must still catch the first fixture.
mkdir "$TMP/liar" || exit 2
printf '#!/bin/sh\necho "text/plain; charset=us-ascii"\n' > "$TMP/liar/file"
chmod +x "$TMP/liar/file" || exit 2
rc=0; PATH="$TMP/liar:$PATH" "$AUDIT" --no-denylist "$TMP/with-nul.md" > "$TMP/out.txt" 2>&1 || rc=$?
checks=$((checks+1)); [ "$rc" -eq 1 ] || bad "with file(1) misreporting, the NUL check did not catch a binary (exit $rc)"
# And file(1) producing something unrecognisable is an error, not a pass.
printf '#!/bin/sh\necho "no idea"\n' > "$TMP/liar/file"
rc=0; PATH="$TMP/liar:$PATH" "$AUDIT" --no-denylist "$TMP/good.txt" > "$TMP/out.txt" 2>&1 || rc=$?
checks=$((checks+1)); [ "$rc" -eq 2 ] || bad "unrecognisable output from file(1) was not treated as an error (exit $rc)"

# An unreadable file is an error. Root can read anything, so this needs an ordinary user.
if [ "$(id -u)" -ne 0 ]; then
  cp "$TMP/good.txt" "$TMP/locked.txt" || exit 2
  chmod 000 "$TMP/locked.txt" || exit 2
  expect 2 "an unreadable file was not treated as an error" --no-denylist "$TMP/locked.txt"
  expect 2 "an unreadable file beside a good one was skipped silently" --no-denylist "$TMP/good.txt" "$TMP/locked.txt"
  chmod 600 "$TMP/locked.txt"
  UNREADABLE="ran"
else
  UNREADABLE="SKIPPED (running as root, which can read any file)"
fi

# ---- 9. The staged content is what is audited ------------------------------------------------
S="$TMP/staged"
mkdir -p "$S/scripts" || exit 2
cp "$AUDIT" "$S/scripts/audit-sanitize.sh" || exit 2
git -C "$S" init -q . || { printf 'ERROR: git init failed\n'; exit 2; }
printf 'clean line\n' > "$S/README.md"
printf 'reachable at %s\n' "$bad_ip" > "$S/notes.md"
git -C "$S" add README.md notes.md || { printf 'ERROR: git add failed\n'; exit 2; }
printf 'clean line\n' > "$S/notes.md"          # the working copy is clean again; the index is not
STAGED_AUDIT="$S/scripts/audit-sanitize.sh"

rc=0; "$STAGED_AUDIT" --no-denylist > "$TMP/out.txt" 2>&1 || rc=$?
checks=$((checks+1)); [ "$rc" -eq 0 ] || bad "setup: the working copies are not clean, so the next check proves nothing (exit $rc)"
rc=0; "$STAGED_AUDIT" --staged --no-denylist > "$TMP/out.txt" 2>&1 || rc=$?
checks=$((checks+1)); [ "$rc" -eq 1 ] || bad "--staged did not catch a value that is staged but gone from the working copy (exit $rc)"
says "--staged did not name the staged file" "notes.md"

# A symbolic link and a submodule entry in the index are findings, not files to follow.
git -C "$S" add notes.md || { printf 'ERROR: git add failed\n'; exit 2; }   # a clean index again
ln -s README.md "$S/link.md" || { printf 'ERROR: ln failed\n'; exit 2; }
git -C "$S" add link.md || { printf 'ERROR: git add failed\n'; exit 2; }
git -C "$S" update-index --add --cacheinfo 160000,1111111111111111111111111111111111111111,sub.md \
  || { printf 'ERROR: git update-index failed\n'; exit 2; }
rc=0; "$STAGED_AUDIT" --staged --no-denylist > "$TMP/out.txt" 2>&1 || rc=$?
checks=$((checks+1)); [ "$rc" -eq 1 ] || bad "--staged accepted a symbolic link and a submodule entry (exit $rc)"
says "--staged did not report the symbolic link" "link.md"
says "--staged did not report the submodule entry" "sub.md"
git -C "$S" rm -q --cached link.md sub.md || { printf 'ERROR: git rm failed\n'; exit 2; }
rm "$S/link.md" || { printf 'ERROR: rm failed\n'; exit 2; }

# ---- 10. Operational failures ---------------------------------------------------------------
# For one tool at a time: count how many times a normal run calls it, then run again that
# many times, making a different call fail each time. Every one of those runs must exit 2.
# A run that exits 0 is a search that failed and was reported as clean.
INJECTED=0
inject() { # inject <tool> <exit status to inject> <label> <command...>
  local tool="$1" irc="$2" label="$3" real total=0 k rc; shift 3
  real="$(type -P "$tool")" || { bad "cannot find $tool to wrap"; return; }
  rm -rf "$TMP/shim"
  mkdir "$TMP/shim" || exit 2
  printf '%s\n' "$real" > "$TMP/shim/real-$tool"
  cat > "$TMP/shim/$tool" <<'EOF'
#!/usr/bin/env bash
dir="${0%/*}"; name="${0##*/}"
read -r real < "$dir/real-$name"
count=0
[ -r "$dir/count" ] && read -r count < "$dir/count"
count=$((count+1))
printf '%s\n' "$count" > "$dir/count"
[ "$count" -eq "${INJECT_AT:-0}" ] && exit "${INJECT_RC:-2}"
exec "$real" "$@"
EOF
  chmod +x "$TMP/shim/$tool" || exit 2

  INJECT_AT=0 PATH="$TMP/shim:$PATH" "$@" > /dev/null 2>&1
  [ -r "$TMP/shim/count" ] && read -r total < "$TMP/shim/count"
  checks=$((checks+1))
  [ "$total" -gt 0 ] || { bad "$label: the audit never called $tool, so nothing was injected"; return; }

  for ((k=1; k<=total; k++)); do
    rm -f "$TMP/shim/count"
    rc=0
    INJECT_AT="$k" INJECT_RC="$irc" PATH="$TMP/shim:$PATH" "$@" > /dev/null 2>&1 || rc=$?
    checks=$((checks+1)); INJECTED=$((INJECTED+1))
    [ "$rc" -eq 2 ] || bad "$label: with call $k of $total to $tool failing, the audit exited $rc instead of 2"
  done
}

# A file with findings, a clean file, and both with a deny-list, so every search runs.
inject grep 2 "bad input"   "$AUDIT" --denylist "$TMP/deny.txt" "$TMP/bad-identifiers.txt" "$TMP/deny-probe.txt"
inject grep 2 "clean input" "$AUDIT" --denylist "$TMP/deny.txt" "$TMP/good.txt"
inject file 1 "bad input"   "$AUDIT" --denylist "$TMP/deny.txt" "$TMP/bad-identifiers.txt"
inject file 1 "clean input" "$AUDIT" --denylist "$TMP/deny.txt" "$TMP/good.txt"
inject tr   1 "clean input" "$AUDIT" --denylist "$TMP/deny.txt" "$TMP/good.txt"
inject cmp  2 "clean input" "$AUDIT" --denylist "$TMP/deny.txt" "$TMP/good.txt"
inject git 128 "staged mode"  "$STAGED_AUDIT" --staged --no-denylist
inject git 128 "default mode" "$STAGED_AUDIT" --no-denylist

# ---------------------------------------------------------------------------------------------
printf 'unreadable-file control: %s\n' "$UNREADABLE"
if [ "$fails" -eq 0 ]; then
  printf 'negative control PASS: %d checks, %d of them injected failures; audit rejects known-bad, accepts known-good, and never passes on an error\n' "$checks" "$INJECTED"
  exit 0
fi
exit 1
