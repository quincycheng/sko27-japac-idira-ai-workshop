#!/usr/bin/env bash
# SKO27 TechSummit - AI Workshop for Idira DC
# Setup checker for macOS and Linux.  (Windows: use check-prereqs.ps1)
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

# The workshop repo is public, so the fetch below is anonymous and read-only, and
# a credential cannot make it succeed when it would otherwise fail. Left to
# itself git will still ask for one whenever it meets a 401, which on a managed
# laptop often comes from the proxy rather than from GitHub. An empty
# credential.helper resets the helper list, so nothing pops up asking to sign in,
# and GIT_TERMINAL_PROMPT=0 stops git asking in the terminal instead, which would
# stall this script. A failed fetch is already handled below. Per call: the
# attendee's own git config is not touched.
# Those flags stop the prompt. They do not stop a 401 happening, because a stale
# extraheader is sent whatever the helper list says. repair_packaged_git deals
# with that, and the two are needed together.
git_anon() { GIT_TERMINAL_PROMPT=0 GIT_ASKPASS='' \
  git -c credential.helper= -c credential.interactive=false -c core.askPass= "$@"; }

# Repairs two things the workshop download itself got wrong. Both are ours, not
# the attendee's, and both are inside this project folder only.
#
# 1. A dead access token. The zip is built by a GitHub Actions job, and
#    actions/checkout writes a one-hour token into .git/config as an
#    http.<host>.extraheader. The zip then ships it, and by the time anyone
#    unpacks it the token has expired. It is an HTTP header, not a credential, so
#    the flags above do not stop git sending it: GitHub answers 401, and git asks
#    for a login. Nobody in the room needs an account. The repo is public, and an
#    anonymous fetch works as soon as the dead header is gone. So it goes.
#
# 2. No credential helper for this folder. Belt and braces for a 401 we do not
#    control, such as an inspecting proxy. Nothing outside this folder is touched.
#
# release.yml now passes persist-credentials: false, so a package built after that
# carries no token and part 1 finds nothing to do. This stays for every folder
# downloaded before then.
repair_packaged_git() {
  local header='http.https://github.com/.extraheader'
  if [ -n "$(git -C "$PROJECT" config --get-all "$header" 2>/dev/null)" ]; then
    git_anon -C "$PROJECT" config --unset-all "$header" 2>/dev/null \
      && dim "removed a dead access token that the download left in this folder"
  fi
  # Only when this folder has no helper of its own. Someone who set one
  # deliberately keeps it.
  if ! git -C "$PROJECT" config --local --get-all credential.helper >/dev/null 2>&1; then
    git_anon -C "$PROJECT" config --local --replace-all credential.helper '' 2>/dev/null
  fi
  # 3. The packaged repo is checked out at a tag, so main has no upstream and a
  #    hand-typed "git pull" answers "no tracking information" instead of
  #    pulling. Pure config, no network. update.sh does not need this, it uses
  #    explicit refspecs, but a helper typing git pull does.
  local branch
  branch="$(git -C "$PROJECT" symbolic-ref --short -q HEAD 2>/dev/null)"
  if [ -n "$branch" ] \
     && ! git -C "$PROJECT" config --local --get "branch.$branch.remote" >/dev/null 2>&1; then
    git_anon -C "$PROJECT" config --local "branch.$branch.remote" origin 2>/dev/null
    git_anon -C "$PROJECT" config --local "branch.$branch.merge" "refs/heads/$branch" 2>/dev/null
  fi
}

# `command -v` only proves a file is on PATH. On a managed laptop the file can be
# there and still refuse to start, because application control decides which
# programs may run. So every tool below is checked by actually running it.
runs() { "$@" >/dev/null 2>&1; }

# Printed when a program is on PATH but will not execute. Deliberately does not
# suggest a workaround: routing around application control is the opposite of
# what this workshop teaches.
blocked() {  # blocked <command name> [path it was found at]
  if [ -n "${2:-}" ]; then
    bad "'$1' is at $2 but will not run"
  else
    bad "'$1' is on your PATH but will not run"
  fi
  info "That is endpoint application control, not a PATH problem. It decides"
  info "which programs may run on a managed laptop. Please do not work around it."
  info "Offered a 'Request for authorization' button? Use it. Otherwise ask in"
  info "the 💬 #cybr-japac-ts-all Slack channel TODAY."
}

cat <<BANNER

${B}🚀 SKO27 TechSummit - AI Workshop for Idira DC${R}
${DIM}   Setup checker · macOS / Linux · nothing here needs admin rights${R}

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
  info "Run this script from inside the workshop folder — the one linked in"
  info "#cybr-japac-ts-all. Nothing else here will work without it."
  fail "Workshop folder" "missing ${MISSING_DIRS[*]}" \
       "Re-download the workshop folder and run this script from inside it"
fi

# git reports and never gates.  Every lesson in Part 1 and nearly all of Part 2
# runs without it, so a missing git is a 👀 rather than a ❌.  Two things do need
# it, and both have a lead time: update.sh cannot run at all without it, and
# Lesson 08's /security-review reads this folder's history.  Before this check
# existed git was used here silently, so anyone without it got no version line,
# no summary row and no explanation of either.
HAS_GIT=0
if ! have git; then
  warn "git is not installed"
  info "Nothing in Part 1 needs it. Two later things do: update.sh, which the"
  info "trainer asks the room to run on the day, and Lesson 08, which reads this"
  info "folder's history. On a Mac git arrives with the command line tools:"
  run "xcode-select --install"
  info "Accept the dialog it opens, wait for it to finish, then re-run this script."
  manual "git" "not installed — run: xcode-select --install"
elif ! runs git --version; then
  blocked "git"
  manual "git" "on PATH but will not run — ask in 💬 #cybr-japac-ts-all TODAY"
else
  HAS_GIT=1
  good "$(git --version 2>/dev/null | head -1)"
fi

# Is the copy current?  The guide changes after people download it, so a version
# that was right last week can be wrong today.  This only reports; update.sh is
# what applies an update, and it is the trainer who calls for one on the day.
# Anything unusual here is left to update.sh to explain rather than duplicated.
if [ "$HAS_GIT" = 1 ] && ! git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
  # No .git here.  This is what a plain "Source code (zip)" download gives you,
  # rather than the workshop package.  update.sh offers to repair it, so this
  # only names the problem and points there.
  warn "this folder has no version history, so its version is unknown"
  info "Lesson 08 reads that history, and update.sh needs it to update you."
  info "One command offers to repair it:"
  run "bash update.sh"
  manual "Workshop version" "no history in this folder — run: bash update.sh"
elif [ "$HAS_GIT" = 1 ]; then
  # Before the fetch, or the fetch is the thing that asks for a login.
  repair_packaged_git
  LOCAL_VER="$(git -C "$PROJECT" describe --tags --always 2>/dev/null || echo unknown)"
  if git_anon -C "$PROJECT" fetch --tags --quiet origin \
       '+refs/heads/main:refs/remotes/origin/main' 2>/dev/null; then
    BEHIND="$(git -C "$PROJECT" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
    if [ "${BEHIND:-0}" = 0 ]; then
      good "version $LOCAL_VER, which is the current one"
      pass "Workshop version" "$LOCAL_VER, current"
    else
      warn "version $LOCAL_VER — $BEHIND change(s) behind. One command fixes it:"
      run "bash update.sh"
      manual "Workshop version" "$BEHIND behind — run: bash update.sh"
    fi
  else
    dim "version $LOCAL_VER — could not reach GitHub to check for a newer one"
  fi
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

  # No alias is offered. The virtual environment in step 3 supplies a plain
  # `python` of its own, so `python3` is only needed for the one command that
  # creates it. An alias would be a permanent change to the user's shell profile
  # to solve a problem that lasts one line.
  if [ "$PY" = python3 ] && ! have python; then
    dim "'python' is not a command here, only 'python3'. That is normal on a Mac"
    dim "and nothing needs fixing: the virtual environment in step 3 supplies its"
    dim "own 'python', so every instruction in the lab works once it is switched on."
  fi
else
  bad "no Python 3.9+ found"
  info "Please do NOT install Python yourself — on a managed laptop that is"
  info "exactly the step that asks for admin rights. 💬 Ask in the"
  info "#cybr-japac-ts-all Slack channel and we will sort it out before the day."
  fail "Python" "not found" "Ask in #cybr-japac-ts-all about Python — do not install it yourself"
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
      fail "Virtual environment" "creation failed" "Raise this in #cybr-japac-ts-all"
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

# Every library can be installed and Part 1 still not start. The lesson modules
# are Python source too, and an interpreter that is too old for their syntax
# parses them and then refuses to run them. That shows up as one error message
# on the first lesson, in the room. So import what the lessons import.
# Library modules only: importing 01_bare_call.py would fire a real model call.
part1_ok() {  # -> 0 if Part 1 will start.  Records its own ❌ row if not.
  local err ver
  if err="$(cd "$PROJECT/ai-harness-app" && "$VPY" -c 'import ui, tools, session, agent, harness' 2>&1)"; then
    good "the Part 1 lesson code imports cleanly"
    return 0
  fi
  ver="$("$VPY" -c 'import platform; print(platform.python_version())' 2>/dev/null)"
  bad "the libraries are installed, but the Part 1 lesson code will not import"
  dim "$(printf '%s\n' "$err" | tail -1)"
  dim "this .venv runs Python ${ver:-unknown}"
  fail "Libraries" "Part 1 will not import" \
       "Delete .venv, create it again with a newer Python (see the Setup page), then re-run this script"
  return 1
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
    if part1_ok; then
      pass "Libraries" "boto3 + anthropic + rich"
    fi
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
        if part1_ok; then
          fixed "Libraries" "installed"
        fi
      else
        bad "the install did not finish cleanly"
        fail "Libraries" "install failed" \
             "Re-run: .venv/bin/python -m pip install -r ai-harness-app/requirements.txt -r sandbox-app/requirements.txt"
      fi
    else
      fail "Libraries" "not installed" "Run: .venv/bin/python -m pip install -r ${NEED[0]}"
    fi
  fi
fi

# --------------------------------------------------------- 5 · claude code

step "5️⃣ " "Claude Code 🤖"

# The installer puts claude in ~/.local/bin and adds that folder to the PATH in
# your shell profile. A profile change only reaches terminals opened after it, so
# in the terminal that ran the installer `claude` is still not a command. Checking
# the PATH alone reads that as "not installed" and offers to install it again,
# which is a loop: the installer succeeds every time and the check fails every
# time. So the known location is looked at before giving up.
CLAUDE_EXE=''
for c in "$HOME/.local/bin/claude" "$BINDIR/claude"; do
  [ -x "$c" ] && { CLAUDE_EXE="$c"; break; }
done

if have claude && runs claude --version; then
  good "claude $(claude --version 2>/dev/null | head -1)"
  pass "Claude Code" "runs"
elif have claude; then
  blocked claude
  fail "Claude Code" "found but will not run" \
       "Get Claude Code allowed by your endpoint policy — ask in #cybr-japac-ts-all"
elif [ -n "$CLAUDE_EXE" ] && runs "$CLAUDE_EXE" --version; then
  good "Claude Code is installed at $CLAUDE_EXE"
  info "It is not on your PATH in this window yet. Open a NEW terminal, then:"
  run "claude --version"
  manual "Claude Code" "installed — open a new terminal"
elif [ -n "$CLAUDE_EXE" ]; then
  # The file is there and will not start. That is application control, not a PATH
  # problem, and installing it again cannot help.
  bad "'claude' is at $CLAUDE_EXE but will not run"
  info "That is endpoint application control, not a PATH problem. It decides"
  info "which programs may run on a managed laptop. Please do not work around it."
  info "Offered a 'Request for authorization' button? Use it. Otherwise ask in"
  info "the 💬 #cybr-japac-ts-all Slack channel TODAY."
  fail "Claude Code" "found but will not run" \
       "Get Claude Code allowed by your endpoint policy — ask in #cybr-japac-ts-all"
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
      fail "Claude Code" "install failed" "Try again on a network without a proxy, or ask in #cybr-japac-ts-all"
    fi
  else
    fail "Claude Code" "not installed" "Run: curl -fsSL https://claude.ai/install.sh | bash"
  fi
fi

# ---------------------------------------------------------- 6 · idsec and jq

step "6️⃣ " "The idsec CLI and jq ⌨️"

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

# idsec and jq are both a single binary in $BINDIR, and both arrive here the same
# way: the file exists, the command does not. There are three real answers, and
# one message used to cover all of them. It appended the PATH line without
# looking for a copy already there, and it recorded the tool as fixed even when
# the attendee answered no. So a tool nobody could reach read as sorted in the
# summary. Defined above its callers: a shell reads top to bottom, so a function
# called by the idsec block but written below it does not exist yet.
resolve_bindir_tool() {  # resolve_bindir_tool <command> <label> <path> [version args...]
  local name="$1" label="$2" exe="$3"
  shift 3
  # Run it before saying anything about the PATH. On a managed laptop the file
  # can be there and refuse to start, and that has no PATH fix.
  if ! runs "$exe" "$@"; then
    blocked "$name" "$exe"
    fail "$label" "found but will not run" \
         "Get $name allowed by your endpoint policy — ask in #cybr-japac-ts-all"
    return
  fi
  good "$name runs from $exe"
  # Two ways a new terminal already finds it, and neither needs ~/.zshrc touched.
  # $BINDIR on this PATH means the shell config every terminal reads puts it
  # there; the marker means the line is in ~/.zshrc waiting for the next one.
  # hash -r is for this terminal: zsh remembers that the command was missing.
  case ":$PATH:" in
    *":$BINDIR:"*)
      hash -r 2>/dev/null || true
      # hash -r was the whole fix, so check rather than assume: telling somebody
      # to open a new terminal for a command that works in this one reads as a
      # script that does not know what it just did.
      if have "$name"; then
        good "$name is on your PATH, in this terminal and in new ones"
        pass "$label" "runs"
        return
      fi
      dim "$BINDIR is on your PATH, so only this terminal is out of date"
      info "Open a NEW terminal, then check it:"
      run "$name $*"
      manual "$label" "installed — open a new terminal"
      return ;;
  esac
  if grep -q 'SKO27 Idira AI workshop prework checker' "$HOME/.zshrc" 2>/dev/null; then
    dim "the PATH line is already in ~/.zshrc, so only this terminal is out of date"
    # ~/.zshrc is read by new terminals only, so this one is fixed by hand. The
    # steps below run idsec, and so does the attendee, in the terminal they are
    # already looking at.
    export PATH="$BINDIR:$PATH"
    hash -r 2>/dev/null || true
    if have "$name"; then
      good "$name is on your PATH, in this terminal and in new ones"
      pass "$label" "runs"
      return
    fi
    info "Open a NEW terminal, then check it:"
    run "$name $*"
    manual "$label" "installed — open a new terminal"
    return
  fi
  warn "$BINDIR is not on the PATH a new terminal gets, so $name will not be found"
  if ask "Add $BINDIR to your PATH in ~/.zshrc?"; then
    printf '\n# Added by the SKO27 Idira AI workshop prework checker\nexport PATH="$HOME/bin:$PATH"\n' >> "$HOME/.zshrc"
    good "added to ~/.zshrc"
    # And this terminal, which will never read the line that was just written.
    export PATH="$BINDIR:$PATH"
    hash -r 2>/dev/null || true
    if have "$name"; then
      good "$name is on your PATH, in this terminal and in new ones"
      fixed "$label" "PATH fixed"
    else
      info "Open a NEW terminal, then check it:"
      run "$name $*"
      fixed "$label" "PATH fixed (new terminal needed)"
    fi
  else
    fail "$label" "installed, not on PATH" 'Add to ~/.zshrc: export PATH="$HOME/bin:$PATH"'
  fi
}

if have idsec && runs idsec version; then
  good "idsec $(idsec version 2>/dev/null | head -1)"
  pass "idsec CLI" "runs"
elif have idsec; then
  blocked idsec
  fail "idsec CLI" "found but will not run" \
       "Get idsec allowed by your endpoint policy — ask in #cybr-japac-ts-all"
elif [ -x "$BINDIR/idsec" ]; then
  resolve_bindir_tool idsec "idsec CLI" "$BINDIR/idsec" version
else
  bad "the 'idsec' command was not found"
  dim "It is a single file — no installer, nothing registered with macOS."
  if ask "Download the latest idsec into $BINDIR and set it up?"; then
    URL="$(idsec_release_url)"
    if [ -z "$URL" ]; then
      bad "could not work out which release file to download"
      info "Do it by hand — the lab page walks you through it:"
      info "🔗 https://github.com/cyberark/idsec-cli-golang/releases"
      fail "idsec CLI" "auto-download failed" "Install idsec by hand — see setup step 5 in the lab guide"
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
          # A file arriving is not the same as a command working, so the fresh
          # install gets the same three-way check as one that was already there.
          resolve_bindir_tool idsec "idsec CLI" "$BINDIR/idsec" version
        else
          bad "downloaded the archive, but found no idsec binary inside it"
          fail "idsec CLI" "unexpected archive" "Install idsec by hand — see setup step 5 in the lab guide"
        fi
      else
        bad "the download failed"
        fail "idsec CLI" "download failed" "Install idsec by hand — see setup step 5 in the lab guide"
      fi
      rm -rf "$TMP"
    fi
  else
    fail "idsec CLI" "not installed" "Install idsec — see setup step 5 in the lab guide"
  fi
fi

# jq comes next, in the same step, because the two are used together: idsec
# returns the AWS credentials as JSON and jq is what lifts them out of it. Also a
# single static binary, so it installs the same way and needs no admin rights.

jq_release_url() {  # echo a download URL for this machine, or nothing
  local os arch
  case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux)  os=linux ;;
    *)      return 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64)  arch=amd64 ;;
    *)             return 1 ;;
  esac
  printf 'https://github.com/jqlang/jq/releases/latest/download/jq-%s-%s\n' "$os" "$arch"
}

if have jq && runs jq --version; then
  good "jq $(jq --version 2>/dev/null | head -1)"
  pass "jq" "runs"
elif have jq; then
  blocked jq
  fail "jq" "found but will not run" \
       "Get jq allowed by your endpoint policy — ask in #cybr-japac-ts-all"
elif [ -x "$BINDIR/jq" ]; then
  resolve_bindir_tool jq jq "$BINDIR/jq" --version
else
  bad "the 'jq' command was not found"
  dim "Also a single file. It reads your AWS credentials out of Idira's answer."
  if ask "Download jq into $BINDIR and set it up?"; then
    URL="$(jq_release_url)"
    if [ -z "$URL" ]; then
      bad "could not work out which build to download"
      info "🔗 https://github.com/jqlang/jq/releases"
      fail "jq" "auto-download failed" "Install jq by hand — see setup step 5 in the lab guide"
    else
      mkdir -p "$BINDIR"
      run "curl -fsSL -o $BINDIR/jq $URL"
      if curl -fsSL -o "$BINDIR/jq" "$URL"; then
        chmod +x "$BINDIR/jq"
        xattr -d com.apple.quarantine "$BINDIR/jq" 2>/dev/null || true
        good "installed to $BINDIR/jq"
        resolve_bindir_tool jq jq "$BINDIR/jq" --version
      else
        rm -f "$BINDIR/jq"
        bad "the download failed"
        fail "jq" "download failed" "Install jq by hand — see setup step 5 in the lab guide"
      fi
    fi
  else
    fail "jq" "not installed" "Install jq — see setup step 5 in the lab guide"
  fi
fi

# ------------------------------------------------------- 7 · idsec profile

step "7️⃣ " "An idsec profile, and a login that works 🔐"

IDSEC=''
if have idsec && runs idsec version; then
  IDSEC=idsec
elif [ -x "$BINDIR/idsec" ] && runs "$BINDIR/idsec" version; then
  IDSEC="$BINDIR/idsec"
fi

cybrworld_values() {
  info "'idsec configure' asks a few questions. Three answers matter:"
  info "  Identity Tenant Subdomain  demo"
  info "  Identity URL               https://aam4614.my.idaptive.app/"
  info "  Username                   your own, ending in @cyberarklab.com"
  dim "That is your own CYBRWorld account. Nobody issues you a workshop login."
}

# Every command in the lab guide, on the cheat sheet and in this script is a bare
# 'idsec ...' with no --profile-name, so they all use the default profile, the one
# called 'idsec'. A profile called something else is invisible to all of them.
# Printed whenever the profiles on this laptop do not include 'idsec'.
default_profile_advice() {
  info "The lab needs CYBRWorld on the DEFAULT profile, the one called 'idsec'."
  info "Every command in the guide leaves --profile-name off, so it uses that one."
  info ""
  info "Using 'idsec' for another tenant already? Keep it, under a name of its own:"
  run "cp -R ~/.idsec/profiles ~/idsec-profiles-backup   # keep a copy first"
  run "idsec configure --profile-name <that-tenant>      # re-enter its values"
  run "idsec configure                                   # now CYBRWorld, as default"
  dim "Your profiles are files in ~/.idsec/profiles. Copy the folder back afterwards"
  dim "if you want your old default returned."
}

# Which profiles exist, one per line. 'profiles list' first, because it is what
# this build actually believes: 0.8.0 answers with a JSON array of names, so the
# brackets, commas and quotes come off here rather than through jq, which may not
# be installed yet at this point in the script.
#
# The fallback is ~/.idsec/profiles, a DIRECTORY holding one file per profile,
# named after the profile. Its dotfiles are bookkeeping, not profiles.
profile_names() {
  local out p
  [ -n "$IDSEC" ] || return 0
  if out="$("$IDSEC" profiles list 2>/dev/null)" && [ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
    printf '%s\n' "$out" \
      | tr -d '[]",' \
      | sed 's/^[[:space:]]*[-*•][[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//' \
      | grep -v '^$'
    return 0
  fi
  if [ -d "$HOME/.idsec/profiles" ]; then
    for p in "$HOME"/.idsec/profiles/*; do
      [ -f "$p" ] && printf '%s\n' "$(basename "$p")"
    done
    return 0
  fi
  for p in "$HOME"/.idsec_profiles* "$HOME"/.ark_profiles*; do
    # Something is configured, but this build will not name it. Treat that as the
    # default profile: it is the only one the lab commands could reach anyway.
    [ -e "$p" ] && { echo idsec; return 0; }
  done
  return 0
}

# The check that matters. Not "is anything configured?" but "is CYBRWorld on the
# profile the lab commands will actually use?" The old version accepted any
# profile, so an attendee with one named profile for another tenant was told
# everything was fine and then watched the login fail for no stated reason.
PROFILES=''
HAS_DEFAULT=0
if [ -n "$IDSEC" ]; then
  PROFILES="$(profile_names)"
  printf '%s\n' "$PROFILES" | grep -qx 'idsec' && HAS_DEFAULT=1
fi

# Runs a real login, because a profile with one wrong answer in it looks perfect
# until the day. </dev/tty so the password and MFA prompts reach the user even
# though this script's own stdin may be a pipe.
verify_login() {
  run "$IDSEC login"
  if "$IDSEC" login </dev/tty; then
    good "logged in to CYBRWorld"
    return 0
  fi
  bad "the login did not succeed"
  info "Check the three values, then fix whichever one is wrong:"
  run "$IDSEC profiles show"
  run "$IDSEC configure"
  cybrworld_values
  info ""
  default_profile_advice
  info "Still failing? Ask in the 💬 #cybr-japac-ts-all Slack channel."
  info "Do it this week, not on the day."
  return 1
}

if [ -z "$IDSEC" ]; then
  bad "skipped — idsec does not run in this window yet"
  fail "idsec login" "blocked by idsec" "Finish step 6, open a new terminal, then re-run this script"
elif [ "$HAS_DEFAULT" = 1 ]; then
  good "the default profile, 'idsec', exists"
  if ask "Log in now, to prove the profile actually works?"; then
    if verify_login; then
      pass "idsec login" "signed in to CYBRWorld"
    else
      fail "idsec login" "login failed" "Fix your idsec profile: idsec configure — then: idsec login"
    fi
  else
    manual "idsec login" "run it by hand: idsec login"
  fi
elif [ -n "$(printf '%s' "$PROFILES" | tr -d '[:space:]')" ]; then
  # The case this whole step exists for: profiles are configured, but none of them
  # is the one the lab commands use.
  bad "you have idsec profiles, but none of them is called 'idsec'"
  info "Found: $(printf '%s' "$PROFILES" | tr '\n' ' ')"
  info ""
  default_profile_advice
  info ""
  cybrworld_values
  if ask "Run 'idsec configure' now, to add CYBRWorld as the default profile?"; then
    if "$IDSEC" configure </dev/tty; then
      good "configured"
      if verify_login; then
        fixed "idsec login" "CYBRWorld on the default profile, signed in"
      else
        fail "idsec login" "configured, login failed" "Fix the values: idsec configure — then: idsec login"
      fi
    else
      bad "configure did not complete"
      fail "idsec login" "no default profile" "Run: idsec configure (CYBRWorld, as the default profile)"
    fi
  else
    fail "idsec login" "no default profile" \
         "Run: idsec configure — CYBRWorld must be the default profile, 'idsec'"
  fi
else
  bad "no idsec profile found"
  cybrworld_values
  dim "Leave --profile-name off when it asks. CYBRWorld belongs on the default"
  dim "profile, because every command in the lab guide leaves it off too."
  if ask "Run 'idsec configure' now? (it will ask you questions)"; then
    if "$IDSEC" configure </dev/tty; then
      good "configured"
      if verify_login; then
        fixed "idsec login" "configured and signed in"
      else
        fail "idsec login" "configured, login failed" "Fix the values: idsec configure — then: idsec login"
      fi
    else
      bad "configure did not complete"
      fail "idsec login" "not configured" "Run: idsec configure"
    fi
  else
    fail "idsec login" "not configured" "Run: idsec configure (once — a second run overwrites it)"
  fi
fi

# ------------------------------------------------------------ 8 · AWS access

step "8️⃣ " "Short-lived AWS credentials from idsec ☁️"

AWS_WORKSPACE='409556437035'
AWS_ROLE='arn:aws:iam::409556437035:role/CW-SCA-AdminAccess'

JQ=''
if have jq && runs jq --version; then
  JQ=jq
elif [ -x "$BINDIR/jq" ] && runs "$BINDIR/jq" --version; then
  JQ="$BINDIR/jq"
fi

# macOS ships no `timeout`, and an elevate call can sit waiting on an approval,
# so wrap it. Returns 124 when the time runs out, like GNU timeout does.
with_timeout() {  # with_timeout <seconds> <command...>
  local secs="$1"; shift
  "$@" &
  local pid=$! i=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge "$secs" ]; then
      kill -TERM "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
    i=$((i + 1))
  done
  wait "$pid"
}

# The whole path, run for real: ask Idira to elevate, then ask AWS who you are.
# The credentials stay inside this function. Nothing is printed and nothing is
# written to a file. They expire on their own, long after this script has exited.
rehearse_aws() {
  local raw='' creds='' arn='' rc=0
  info "asking Idira for credentials — this can take a moment"
  raw="$(with_timeout 120 "$IDSEC" exec sca cloud-access elevate --csp aws \
           --workspace-id "$AWS_WORKSPACE" --roleIds "$AWS_ROLE" --raw 2>/dev/null)"
  rc=$?
  if [ "$rc" -eq 124 ]; then
    bad "the elevate call did not finish in two minutes"
    info "It may be waiting on an approval. Run it by hand — setup step 7."
    manual "AWS credentials" "elevate timed out — run it by hand, setup step 7"
    return 1
  fi
  creds="$(printf '%s' "$raw" | "$JQ" -r '.response.results[0].accessCredentials | fromjson |
    "export AWS_ACCESS_KEY_ID=\(.aws_access_key)
export AWS_SECRET_ACCESS_KEY=\(.aws_secret_access_key)
export AWS_SESSION_TOKEN=\(.aws_session_token)"' 2>/dev/null)"
  raw=''
  if [ -z "$creds" ]; then
    bad "no credentials came back"
    info "The role exists, so this is usually a policy on the role itself."
    info "💬 Ask in #cybr-japac-ts-all today and paste in what you ran."
    fail "AWS credentials" "elevate returned nothing" \
         "💬 Ask in #cybr-japac-ts-all — elevate gave no credentials"
    return 1
  fi
  good "credentials received"
  # verify=False for the same reason ai-harness-app/config.py sets it: a TLS-inspecting
  # proxy would otherwise fail this call and be reported as "AWS rejected them", which
  # sends the attendee after the wrong problem. Step 9 below is where TLS gets judged.
  arn="$(eval "$creds"; "$VPY" -c 'import boto3, urllib3
urllib3.disable_warnings()
print(boto3.client("sts", verify=False).get_caller_identity()["Arn"])' 2>/dev/null)"
  if [ -n "$arn" ]; then
    good "AWS accepted them: $arn"
    dim "They are gone now. This script never saved them anywhere."
    pass "AWS credentials" "elevate and AWS both worked"
  else
    bad "the credentials came back, but AWS did not accept them"
    info "Do the two commands by hand — setup step 7 explains every error."
    fail "AWS credentials" "AWS rejected them" \
         "Run setup step 7 by hand, then 💬 ask in #cybr-japac-ts-all"
  fi
}

if [ -z "$IDSEC" ]; then
  bad "skipped — idsec does not run in this window yet"
  fail "AWS credentials" "idsec unavailable" \
       "Finish step 6, open a new terminal, then re-run this script"
else
  run "$IDSEC exec sca cloud-access list-targets --csp aws"
  TARGETS="$("$IDSEC" exec sca cloud-access list-targets --csp aws 2>&1)"
  # Every AWS role comes back as an ARN, whether this build prints JSON or a
  # table, so counting ARNs works either way.
  TARGETS_N="$(printf '%s\n' "$TARGETS" | grep -c 'arn:aws:iam::')"
  if [ "${TARGETS_N:-0}" -lt 1 ]; then
    bad "no AWS role came back"
    # Two very different causes print the same empty list. Rule the cheap one out
    # first, or an attendee emails about an entitlement they already have.
    if [ "$HAS_DEFAULT" != 1 ]; then
      warn "the default profile is not CYBRWorld, so this asked the wrong tenant"
      default_profile_advice
      fail "AWS credentials" "wrong tenant" \
           "Put CYBRWorld on the default profile: idsec configure — then re-run this script"
    else
      dim "This is an access entitlement. It cannot be fixed from your seat, and"
      dim "it takes days. 💬 Ask in #cybr-japac-ts-all TODAY."
      dim "Logged in to a tenant other than CYBRWorld? Check with: idsec profiles show"
      fail "AWS credentials" "no entitlement" \
           "💬 Ask in #cybr-japac-ts-all today — you have no AWS role yet"
    fi
  elif [ -z "$JQ" ]; then
    good "$TARGETS_N AWS role(s) available to you"
    warn "jq does not run in this window, so the rest of this step is skipped"
    manual "AWS credentials" "finish step 6, then re-run this script"
  elif [ ! -x "$VPY" ]; then
    good "$TARGETS_N AWS role(s) available to you"
    warn "no virtual environment yet, so the rest of this step is skipped"
    manual "AWS credentials" "finish step 3, then re-run this script"
  else
    good "$TARGETS_N AWS role(s) available to you"
    if ask "Run the full rehearsal now? It gets real credentials and throws them away."; then
      rehearse_aws
    else
      manual "AWS credentials" "run the elevate one-liner by hand — setup step 7"
    fi
  fi
fi

# ------------------------------------------------------- 9 · TLS to Bedrock

# Every model call in this workshop is HTTPS to Bedrock, from Python in Part 1 and
# from Claude Code in Part 2. A network that re-signs certificates breaks both, in
# the same way, with an error that reads like a credential problem. It is worth two
# seconds here because it is the one failure a helper cannot fix at the desk.

# INFORMATION ONLY, and deliberately so. Part 1's Python does not verify
# certificates at all (see the TLS note at the top of ai-harness-app/config.py), so
# an inspecting proxy can no longer end somebody's session -- which means nothing
# this step finds is a reason to escalate, and it never calls `fail`.
#
# It stays in the script because the ANSWER is still worth having: knowing that the
# venue network re-signs certificates tells the workshop owner what to expect from
# Claude Code in Part 2, which does verify. Kept as a warning, not a gate.
step "9️⃣ " "How this network treats HTTPS 🔐 (information only)"

TLSPY=''
if [ -x "$VPY" ]; then TLSPY="$VPY"; elif have python3; then TLSPY="$(command -v python3)"; fi

# A CA bundle variable left pointing at a file that no longer exists used to break
# every Python call in the workshop. It no longer does, because nothing here reads
# a bundle any more. Still worth naming: it will bite something else on this laptop.
STALE_BUNDLE=''
for v in AWS_CA_BUNDLE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE SSL_CERT_FILE; do
  val="$(eval "printf '%s' \"\${$v:-}\"")"
  [ -n "$val" ] && [ ! -f "$val" ] && STALE_BUNDLE="$v"
done

if [ -n "$STALE_BUNDLE" ]; then
  warn "$STALE_BUNDLE points at a file that does not exist"
  dim "Nothing in this workshop reads it, so the lessons will run regardless."
  dim "It will break other tools on this laptop, though, so worth tidying:"
  run "unset AWS_CA_BUNDLE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE SSL_CERT_FILE"
  manual "HTTPS to Bedrock" "$STALE_BUNDLE is stale — harmless here, worth tidying"
elif [ -z "$TLSPY" ]; then
  dim "skipped — no Python to test with yet, and nothing depends on the answer"
  manual "HTTPS to Bedrock" "not checked — needs Python, but the lessons do not need this"
else
  # Written to a temp file rather than piped in through a here-document: bash 3.2,
  # which is still the system bash on macOS, mis-parses an apostrophe inside a
  # quoted here-document when the whole thing sits in a $( ) substitution.
  TLS_PROBE="${TMPDIR:-/tmp}/idira-tls-probe.$$.py"
  cat > "$TLS_PROBE" <<'PYEOF'
import os, socket, ssl

HOST = "bedrock-runtime.us-east-1.amazonaws.com"


def handshake(context):
    """Return the peer certificate, or raise. No I/O beyond one TLS handshake."""
    with socket.create_connection((HOST, 443), timeout=10) as raw:
        with context.wrap_socket(raw, server_hostname=HOST) as tls:
            return tls.getpeercert()


def issuer_of(cert):
    parts = dict(part[0] for part in cert.get("issuer", ()))
    return parts.get("organizationName", "unknown")


def certifi_context():
    import certifi
    return ssl.create_default_context(cafile=certifi.where())


# Test the trust store botocore will ACTUALLY use, in the order botocore uses: an
# explicit bundle variable wins, then certifi, then the platform store. Checking a
# different store from the one the lesson uses would make this check worse than
# not running it at all.
bundle_var = next(
    (name for name in ("AWS_CA_BUNDLE", "REQUESTS_CA_BUNDLE")
     if os.environ.get(name) and os.path.isfile(os.environ[name])),
    None,
)

try:
    ctx = ssl.create_default_context(cafile=os.environ[bundle_var]) if bundle_var else certifi_context()
except Exception:
    bundle_var = None
    ctx = ssl.create_default_context()

try:
    print("OK|" + issuer_of(handshake(ctx)))
except ssl.SSLCertVerificationError as error:
    # A bundle variable is set and did not work. Retry with certifi to tell the two
    # cases apart: a bundle that does not cover AWS is one unset away from working,
    # and telling someone their network is hostile when it is not wastes a reply.
    if bundle_var:
        try:
            handshake(certifi_context())
            print("BUNDLE|%s" % bundle_var)
        except Exception:
            print("INTERCEPT|%s" % error)
    else:
        print("INTERCEPT|%s" % error)
except Exception as error:
    print("NET|%s: %s" % (type(error).__name__, error))
PYEOF

  TLS_RESULT="$("$TLSPY" "$TLS_PROBE" 2>/dev/null | tail -1)"
  rm -f "$TLS_PROBE"

  TLS_KIND="${TLS_RESULT%%|*}"
  TLS_DETAIL="${TLS_RESULT#*|}"

  case "$TLS_KIND" in
    OK)
      if [ "$TLS_DETAIL" = "Amazon" ]; then
        good "reached AWS, certificate issued by Amazon — a clean path"
        pass "HTTPS to Bedrock" "clean path (Amazon)"
      else
        good "reached AWS — but the certificate was issued by: $TLS_DETAIL"
        dim "Not Amazon, so something on this network is inspecting HTTPS. Part 1"
        dim "does not care: it does not verify certificates. Claude Code in Part 2"
        dim "does, so mention it in #cybr-japac-ts-all. Useful for us to know. 💬"
        manual "HTTPS to Bedrock" "inspected by $TLS_DETAIL — fine for Part 1"
      fi
      ;;
    BUNDLE|INTERCEPT)
      good "reached AWS — the certificate did not verify on this machine"
      dim "$TLS_DETAIL"
      dim "Either a proxy is re-signing certificates, or a CA bundle variable here"
      dim "does not cover AWS. Part 1 runs anyway — it does not verify at all, on"
      dim "purpose (ai-harness-app/config.py explains why, and why you should not"
      dim "copy that choice). Claude Code in Part 2 DOES verify, so a reply telling"
      dim "us this is genuinely useful, and a corporate root CA path even more so:"
      run "export NODE_EXTRA_CA_CERTS=/path/to/corp-root.pem"
      manual "HTTPS to Bedrock" "inspected — fine for Part 1, may affect Part 2"
      ;;
    NET)
      warn "could not reach Bedrock at all"
      dim "$TLS_DETAIL"
      dim "Offline, a VPN, or egress filtering. This one WOULD stop the workshop, so"
      dim "re-run it on the network you will actually use on the day."
      manual "HTTPS to Bedrock" "no route from here — re-test on the day's network"
      ;;
    *)
      dim "the check did not produce a usable answer, and nothing depends on it"
      manual "HTTPS to Bedrock" "inconclusive — mention it if the day goes wrong"
      ;;
  esac
fi

# ------------------------------------------------- 10 · console sign-in

# Lessons 09 and 10 read the console in a browser: the same CYBRWorld tenant idsec
# uses, reached the other way. Nothing to install, and this script cannot test it,
# because it needs a real sign-in with a real MFA prompt. It is printed as a
# reminder and never as a gate, the same treatment as the HTTPS step above.
step "🔟 " "A browser sign-in to the console 🪪 (information only)"

info "Lesson 10 opens https://demo.cyberark.cloud/ in a browser. That is the same"
info "tenant idsec uses, and this script cannot test the browser half."
info "Open it now and sign in with your own account. If the console loads, you are"
info "done. Note which browser you used: lesson 10 opens a sign-in page from the"
info "terminal, and it uses whichever browser is your default."
manual "console sign-in" "check it in a browser — setup step 9"

# --------------------------------------------------------------- summary

printf '\n%s%s%s\n' "$B" "────────────────────────  Summary  ────────────────────────" "$R"
printf '\n'
for row in "${SUMMARY[@]}"; do
  IFS='|' read -r icon what detail <<< "$row"
  printf '  %s  %-24s %s%s%s\n' "$icon" "$what" "$DIM" "$detail" "$R"
done

# This script checks everything it can, including the AWS entitlement and whether
# each program really starts. One thing is left, and it is the one with a lead
# time: an endpoint policy nobody in the room can change. Print it in both the
# pass and the fail path, because the pass path is the one people actually read.
only_you() {
  cat <<ONLYYOU

  ${YEL}${B}──────────  One thing that needs days, not minutes  ──────────${R}

  ${B}Did this script say a program is blocked rather than missing?${R}
  A message about a policy, an administrator, 'this application is blocked',
  or ${B}Idira EPM${R} is endpoint application control. It is not a setup problem.
  This script cannot fix it and neither can a helper on the day: it needs an
  endpoint policy change, and that takes days.

  💬 ${B}Ask in the #cybr-japac-ts-all Slack channel TODAY.${R} If a
  ${B}Request for authorization${R} prompt appears, use it too.
ONLYYOU
}

if [ ${#TODO[@]} -eq 0 ]; then
  printf '\n  %s%s🎉 Every check this script can make has passed.%s\n' "$GRN" "$B" "$R"
  only_you
  cat <<DONE

  Bring: this laptop and a charger. Questions go to #cybr-japac-ts-all.
  See you there! 👋
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

  Stuck on any of them? 💬 Ask in #cybr-japac-ts-all this week — we would
  much rather fix it now than on the day.
NEXT
only_you
exit 1
