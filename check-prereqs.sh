#!/usr/bin/env bash
# SKO27 TechSummit - AI Workshop for Idira DC
# Prework checker for macOS and Linux.  (Windows: use check-prereqs.ps1)
#
#   bash check-prereqs.sh              check, and offer to fix what is missing
#   bash check-prereqs.sh --check-only check only, never change anything
#   bash check-prereqs.sh --yes        say yes to every offer (unattended)
#
# Two rules this script keeps, because the audience has no admin rights:
#   1. Nothing is installed outside your home folder and this project folder.
#   2. Nothing is changed without asking you first.

set -uo pipefail

# ---------------------------------------------------------------- appearance

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; DIM=$'\033[2m'; R=$'\033[0m'
  GRN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; BLU=$'\033[34m'
else
  B=''; DIM=''; R=''; GRN=''; RED=''; YEL=''; BLU=''
fi

ASSUME_YES=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes)        ASSUME_YES=1 ;;
    -c|--check-only) CHECK_ONLY=1 ;;
    -h|--help)       sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg  (try --help)"; exit 2 ;;
  esac
done

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$PROJECT/.venv"
VPY="$VENV/bin/python"
BINDIR="$HOME/bin"

# Results, printed as one table at the end.
SUMMARY=()
TODO=()

pass()  { SUMMARY+=("✅|$1|$2"); }
fixed() { SUMMARY+=("🛠️ |$1|$2"); }
fail()  { SUMMARY+=("❌|$1|$2"); TODO+=("$3"); }
manual(){ SUMMARY+=("👀|$1|$2"); }

step()  { printf '\n%s%s %s%s\n' "$B" "$1" "$2" "$R"; }
info()  { printf '   %s\n' "$1"; }
dim()   { printf '   %s%s%s\n' "$DIM" "$1" "$R"; }
good()  { printf '   %s✅ %s%s\n' "$GRN" "$1" "$R"; }
bad()   { printf '   %s❌ %s%s\n' "$RED" "$1" "$R"; }
warn()  { printf '   %s⚠️  %s%s\n' "$YEL" "$1" "$R"; }
run()   { printf '   %s$ %s%s\n' "$BLU" "$1" "$R"; }

# ask "question" -> 0 for yes.  Honours --yes and --check-only.
ask() {
  if [ "$CHECK_ONLY" = 1 ]; then
    printf '   %s(--check-only, so not offering to fix this)%s\n' "$DIM" "$R"
    return 1
  fi
  if [ "$ASSUME_YES" = 1 ]; then
    printf '   %s🤖 %s → yes (--yes)%s\n' "$DIM" "$1" "$R"
    return 0
  fi
  local reply=''
  printf '   %s🤔 %s [y/N] %s' "$B" "$1" "$R"
  read -r reply </dev/tty || return 1
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

have() { command -v "$1" >/dev/null 2>&1; }

cat <<BANNER

${B}🚀 SKO27 TechSummit - AI Workshop for Idira DC${R}
${DIM}   Prework checker · macOS / Linux · nothing here needs admin rights${R}

   Project folder : $PROJECT
BANNER

# ------------------------------------------------------- 1 · workshop folder

step "1️⃣ " "The workshop folder"

MISSING_DIRS=()
for d in lab sandbox-app ai-harness-app skills; do
  [ -d "$PROJECT/$d" ] || MISSING_DIRS+=("$d")
done

if [ ${#MISSING_DIRS[@]} -eq 0 ]; then
  good "lab, sandbox-app, ai-harness-app and skills are all here"
  pass "Workshop folder" "complete"
else
  bad "missing: ${MISSING_DIRS[*]}"
  info "Run this script from inside the workshop folder — the one your"
  info "workshop email pointed you at. Nothing else here will work without it."
  fail "Workshop folder" "missing ${MISSING_DIRS[*]}" \
       "Re-download the workshop folder and run this script from inside it"
fi

# --------------------------------------------------------------- 2 · python

step "2️⃣ " "Python 3.9 or newer 🐍"

PY=''
for cand in python3 python; do
  if have "$cand" && "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
    PY="$cand"; break
  fi
done

if [ -n "$PY" ]; then
  PYVER="$("$PY" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
  good "$PY is Python $PYVER"
  pass "Python" "$PY $PYVER"

  # The lab guide says `python` everywhere. If only python3 exists, offer the
  # same alias the prework page suggests, so no command has to be translated.
  if [ "$PY" = python3 ] && ! have python; then
    warn "'python' is not a command on this machine, only 'python3'"
    info "Every instruction in the lab says 'python'. An alias fixes that once."
    if ask "Add 'alias python=python3' to your shell profile?"; then
      PROFILE="$HOME/.zshrc"
      [ -n "${BASH_VERSION:-}" ] && [ "${SHELL##*/}" = bash ] && PROFILE="$HOME/.bashrc"
      {
        echo ''
        echo '# Added by the SKO27 Idira AI workshop prework checker'
        echo 'alias python="python3"'
        echo 'alias pip="pip3"'
      } >> "$PROFILE"
      good "added to $PROFILE — open a new terminal for it to take effect"
      fixed "python alias" "added to ${PROFILE##*/}"
    fi
  fi
else
  bad "no Python 3.9+ found"
  info "Please do NOT install Python yourself — on a managed laptop that is"
  info "exactly the step that asks for admin rights. 📧 Reply to your workshop"
  info "email instead and we will sort it out with you before the day."
  fail "Python" "not found" "Reply to the workshop email about Python — do not install it yourself"
fi

# ------------------------------------------------- 3 · virtual environment

step "3️⃣ " "A virtual environment in this folder"

if [ -x "$VPY" ]; then
  good ".venv exists ($("$VPY" -c 'import sys; print("Python %d.%d.%d" % sys.version_info[:3])'))"
  pass "Virtual environment" ".venv ready"
elif [ -z "$PY" ]; then
  bad "cannot create one without Python"
  fail "Virtual environment" "blocked by Python" "Fix Python first, then re-run this script"
else
  bad "no .venv folder here"
  dim "A virtual environment is a private folder of Python libraries for this"
  dim "project only. Nothing system-wide, no admin rights, delete-to-clean-up."
  if ask "Create it now? (writes $VENV)"; then
    run "$PY -m venv .venv"
    if "$PY" -m venv "$VENV"; then
      good "created"
      fixed "Virtual environment" "created .venv"
    else
      bad "creating it failed"
      fail "Virtual environment" "creation failed" "Raise this in a reply to the workshop email"
    fi
  else
    fail "Virtual environment" "not created" "Run: $PY -m venv .venv"
  fi
fi

# --------------------------------------------------------- 4 · dependencies

step "4️⃣ " "The libraries the workshop needs 📦"

check_import() {  # check_import <module> -> 0 if importable in the venv
  [ -x "$VPY" ] && "$VPY" -c "import $1" >/dev/null 2>&1
}

if [ ! -x "$VPY" ]; then
  bad "skipped — no virtual environment yet"
  fail "Libraries" "blocked by .venv" "Create the virtual environment, then re-run this script"
else
  NEED=()
  check_import boto3 || NEED+=("sandbox-app/requirements.txt")
  # rich powers ui.py, which every lesson imports. Without checking it, a failed
  # rich install reports PASS here and then crashes on import in the room. Both
  # live in the same requirements file, so test them together and list it once.
  check_import anthropic && check_import rich || NEED+=("ai-harness-app/requirements.txt")

  if [ ${#NEED[@]} -eq 0 ]; then
    good "boto3 is ready (the sandbox app)"
    good "anthropic is ready (the harness lessons in Part 1)"
    good "rich is ready (the terminal UI)"
    pass "Libraries" "boto3 + anthropic + rich"
  else
    bad "missing libraries from: ${NEED[*]}"
    if ask "Install them into .venv now? (needs internet, ~1 minute)"; then
      OK=1
      "$VPY" -m pip install --quiet --upgrade pip >/dev/null 2>&1
      for req in "${NEED[@]}"; do
        run "python -m pip install -r $req"
        "$VPY" -m pip install --quiet -r "$PROJECT/$req" || OK=0
      done
      if [ "$OK" = 1 ] && check_import boto3 && check_import anthropic && check_import rich; then
        good "boto3, anthropic and rich all import cleanly"
        fixed "Libraries" "installed"
      else
        bad "the install did not finish cleanly"
        fail "Libraries" "install failed" "Re-run: .venv/bin/python -m pip install -r sandbox-app/requirements.txt"
      fi
    else
      fail "Libraries" "not installed" "Run: .venv/bin/python -m pip install -r ${NEED[0]}"
    fi
  fi
fi

# --------------------------------------------------------- 5 · claude code

step "5️⃣ " "Claude Code 🤖"

if have claude; then
  good "claude $(claude --version 2>/dev/null | head -1)"
  pass "Claude Code" "installed"
else
  bad "the 'claude' command was not found"
  dim "It installs into your home folder. No admin rights, no Node.js."
  if ask "Install Claude Code now? (runs the official installer)"; then
    run "curl -fsSL https://claude.ai/install.sh | bash"
    if curl -fsSL https://claude.ai/install.sh | bash; then
      if have claude || [ -x "$HOME/.local/bin/claude" ]; then
        good "installed — open a NEW terminal, then run: claude --version"
        fixed "Claude Code" "installed (new terminal needed)"
      else
        warn "installed, but not on your PATH in this window yet"
        fixed "Claude Code" "installed (open a new terminal)"
      fi
    else
      bad "the installer failed"
      fail "Claude Code" "install failed" "Try again on a network without a proxy, or reply to the workshop email"
    fi
  else
    fail "Claude Code" "not installed" "Run: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# --------------------------------------------------------------- 6 · idsec

step "6️⃣ " "The idsec CLI ⌨️"

idsec_release_url() {  # echo a download URL for this machine, or nothing
  local os arch
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux)  os=linux ;;
    *)      return 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64)  arch=amd64 ;;
    *)             return 1 ;;
  esac
  curl -fsSL https://api.github.com/repos/cyberark/idsec-cli-golang/releases/latest 2>/dev/null \
    | grep -o '"browser_download_url"[^,]*' \
    | sed 's/.*"\(https[^"]*\)".*/\1/' \
    | grep -i -- "$os" | grep -i -- "$arch" \
    | grep -Ei '\.(tar\.gz|tgz|zip)$' | head -1
}

if have idsec; then
  good "idsec $(idsec version 2>/dev/null | head -1)"
  pass "idsec CLI" "installed"
elif [ -x "$BINDIR/idsec" ]; then
  warn "idsec is at $BINDIR/idsec but not on your PATH in this window"
  if ask "Add $BINDIR to your PATH in ~/.zshrc?"; then
    printf '\n# Added by the SKO27 Idira AI workshop prework checker\nexport PATH="$HOME/bin:$PATH"\n' >> "$HOME/.zshrc"
    good "added — open a new terminal, then run: idsec version"
    fixed "idsec CLI" "PATH fixed (new terminal needed)"
  else
    fail "idsec CLI" "not on PATH" 'Add to ~/.zshrc: export PATH="$HOME/bin:$PATH"'
  fi
else
  bad "the 'idsec' command was not found"
  dim "It is a single file — no installer, nothing registered with macOS."
  if ask "Download the latest idsec into $BINDIR and set it up?"; then
    URL="$(idsec_release_url)"
    if [ -z "$URL" ]; then
      bad "could not work out which release file to download"
      info "Do it by hand — the lab page walks you through it:"
      info "🔗 https://github.com/cyberark/idsec-cli-golang/releases"
      fail "idsec CLI" "auto-download failed" "Install idsec by hand — see prework step 5 in the lab guide"
    else
      TMP="$(mktemp -d)"
      FILE="$TMP/${URL##*/}"
      run "curl -fsSL -o $FILE $URL"
      mkdir -p "$BINDIR"
      if curl -fsSL -o "$FILE" "$URL"; then
        case "$FILE" in
          *.zip)          unzip -qo "$FILE" -d "$TMP" ;;
          *.tar.gz|*.tgz) tar -xzf "$FILE" -C "$TMP" ;;
        esac
        # The archive names the binary after its platform. On a Mac that is
        # idsec-darwin, and it arrives next to a LICENSE.txt and a README.md.
        # So match the prefix rather than an exact name, which also means a
        # release that renames again still installs. It becomes plain 'idsec'
        # a few lines down.
        find_binary() {
          find "$TMP" -type f -name 'idsec*' \
            ! -name '*.txt' ! -name '*.md' "$@" 2>/dev/null | head -1
        }
        FOUND="$(find_binary -perm -u+x)"
        [ -z "$FOUND" ] && FOUND="$(find_binary)"
        if [ -n "$FOUND" ]; then
          mv "$FOUND" "$BINDIR/idsec"
          chmod +x "$BINDIR/idsec"
          # macOS quarantines anything downloaded by a browser or curl.
          xattr -d com.apple.quarantine "$BINDIR/idsec" 2>/dev/null || true
          good "installed to $BINDIR/idsec"
          case ":$PATH:" in
            *":$BINDIR:"*) : ;;
            *) if ask "Add $BINDIR to your PATH in ~/.zshrc?"; then
                 printf '\n# Added by the SKO27 Idira AI workshop prework checker\nexport PATH="$HOME/bin:$PATH"\n' >> "$HOME/.zshrc"
                 good "added — open a new terminal afterwards"
               fi ;;
          esac
          fixed "idsec CLI" "installed (new terminal needed)"
        else
          bad "downloaded the archive, but found no idsec binary inside it"
          fail "idsec CLI" "unexpected archive" "Install idsec by hand — see prework step 5 in the lab guide"
        fi
      else
        bad "the download failed"
        fail "idsec CLI" "download failed" "Install idsec by hand — see prework step 5 in the lab guide"
      fi
      rm -rf "$TMP"
    fi
  else
    fail "idsec CLI" "not installed" "Install idsec — see prework step 5 in the lab guide"
  fi
fi

# ------------------------------------------------------- 7 · idsec profile

step "7️⃣ " "An idsec profile you can log in with 🔐"

PROFILE_FOUND=''
for p in "$HOME/.idsec" "$HOME/.idsec_profiles" "$HOME/.ark_profiles" "$HOME/.cyberark"; do
  [ -e "$p" ] && PROFILE_FOUND="$p" && break
done

if [ -n "$PROFILE_FOUND" ]; then
  good "found idsec settings at $PROFILE_FOUND"
  dim "Confirm it works before the day by running: idsec login"
  pass "idsec profile" "configured"
elif ! have idsec && [ ! -x "$BINDIR/idsec" ]; then
  bad "skipped — idsec is not installed yet"
  fail "idsec profile" "blocked by idsec" "Install idsec, then run: idsec configure"
else
  bad "no idsec settings found"
  info "'idsec configure' asks a few questions. Answer them with the tenant"
  info "subdomain and username from your workshop email. 📧"
  if ask "Run 'idsec configure' now? (it will ask you questions)"; then
    IDSEC="$(command -v idsec || echo "$BINDIR/idsec")"
    if "$IDSEC" configure </dev/tty; then
      good "configured — now prove it works with: idsec login"
      fixed "idsec profile" "configured (run idsec login next)"
    else
      bad "configure did not complete"
      fail "idsec profile" "not configured" "Run: idsec configure"
    fi
  else
    fail "idsec profile" "not configured" "Run: idsec configure (once — a second run overwrites it)"
  fi
fi

# ------------------------------------------------------------ 8 · AWS access

step "8️⃣ " "AWS access through the portal ☁️"

warn "no script can check this one for you — please click through it 🙏"
info "1. Open https://ngid.cyberark.cloud/ and sign in"
info "2. Open CYBR User Portal, then click the AWS tile"
info "3. You should land on a page ending in awsapps.com/start/#"
info "4. Next to your account, click 'Access keys' (or 'Get credentials')"
info "5. Confirm you see 'Option 1: Set AWS environment variables'"
dim "Nothing to copy yet. You just need to know the link is there."
dim "No AWS tile, no accounts, or no Access keys link? 📧 Reply to the workshop"
dim "email TODAY — it is an entitlement, and it cannot be fixed from your seat."
manual "AWS portal access" "check it by hand — step 8 above"

# --------------------------------------------------------------- summary

printf '\n%s%s%s\n' "$B" "────────────────────────  Summary  ────────────────────────" "$R"
printf '\n'
for row in "${SUMMARY[@]}"; do
  IFS='|' read -r icon what detail <<< "$row"
  printf '  %s  %-24s %s%s%s\n' "$icon" "$what" "$DIM" "$detail" "$R"
done

# Two things no script can settle, and both need a reply days ahead rather than a
# raised hand on the day: an entitlement nobody in the room can grant, and an
# endpoint policy nobody in the room can change. Print them loudly in both the
# pass and the fail path, because the pass path is the one people actually read.
only_you() {
  cat <<ONLYYOU

  ${YEL}${B}──────────  Two things only you can confirm  ──────────${R}

  ${B}1. The AWS portal (8️⃣  above).${R} Click through it now if you have not.
     No AWS tile, no accounts, or no 'Access keys' link means you are missing an
     ${B}entitlement${R}. Nobody can grant it from a seat on the day.

  ${B}2. Does this laptop actually let these programs run?${R}
     Try both, in a new terminal:

         ${BLU}idsec version${R}
         ${BLU}claude --version${R}

     A version number from each means you are fine. But if either one is found
     and still refuses to start — a message about a policy, an administrator,
     'this application is blocked', or ${B}Idira EPM${R} — that is endpoint
     application control, not a setup problem. This script cannot fix it and
     neither can a helper: it needs an endpoint policy change with a lead time
     of days. If a ${B}Request for authorization${R} prompt appears, use it.

  ${B}Either of those looking wrong? 📧 Reply to the workshop email TODAY.${R}
  Not tomorrow, and definitely not on the morning of the workshop. Both take
  days to sort out, and both stop you doing the hands-on work entirely.
ONLYYOU
}

if [ ${#TODO[@]} -eq 0 ]; then
  printf '\n  %s%s🎉 Every check this script can make has passed.%s\n' "$GRN" "$B" "$R"
  only_you
  cat <<DONE

  Bring: this laptop, a charger, and your workshop email. See you there! 👋
DONE
  exit 0
fi

printf '\n  %s%s⚠️  Still to do:%s\n\n' "$YEL" "$B" "$R"
i=1
SEEN=''
for t in "${TODO[@]}"; do
  # One failure often cascades into the next check, so the same instruction can
  # be queued twice. Print each one once.
  case "$SEEN" in *"[$t]"*) continue ;; esac
  SEEN="$SEEN[$t]"
  printf '  %d. %s\n' "$i" "$t"
  i=$((i + 1))
done
cat <<NEXT

  Re-run this script when you have worked through those:

      ${BLU}bash check-prereqs.sh${R}

  Stuck on any of them? 📧 Reply to the workshop email this week — we would
  much rather fix it now than on the day.
NEXT
only_you
exit 1
