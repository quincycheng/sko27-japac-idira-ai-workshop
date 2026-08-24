#!/usr/bin/env bash
# SKO27 TechSummit - AI Workshop for Idira DC
# Day-of updater for macOS and Linux.  (Windows: use update.ps1)
#
#   bash update.sh              check for a newer guide, and offer to apply it
#   bash update.sh --check-only say what is out of date, change nothing
#   bash update.sh --yes        say yes to every offer (unattended)
#
# Why this exists: the lab guide and the lesson code can change after you
# downloaded this folder.  This says whether your copy is current, and brings it
# up to date in place if it is not.
#
# Two rules this script keeps, the same two check-prereqs.sh keeps:
#   1. Nothing is installed outside your home folder and this project folder.
#   2. Nothing is changed without asking you first.
#
# Your virtual environment is not tracked by git, so updating never touches it.
# That is the whole reason this updates in place rather than telling you to
# download the folder again.

set -uo pipefail

PAGES_URL="https://quincycheng.github.io/sko27-japac-idira-ai-workshop/"
REPO_URL="https://github.com/quincycheng/sko27-japac-idira-ai-workshop.git"
BRANCH="main"

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
    -h|--help)       sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg  (try --help)"; exit 2 ;;
  esac
done

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step()  { printf '\n%s%s %s%s\n' "$B" "$1" "$2" "$R"; }
info()  { printf '   %s\n' "$1"; }
dim()   { printf '   %s%s%s\n' "$DIM" "$1" "$R"; }
good()  { printf '   %s✅ %s%s\n' "$GRN" "$1" "$R"; }
bad()   { printf '   %s❌ %s%s\n' "$RED" "$1" "$R"; }
warn()  { printf '   %s⚠️  %s%s\n' "$YEL" "$1" "$R"; }
run()   { printf '   %s$ %s%s\n' "$BLU" "$1" "$R"; }

ask() {
  if [ "$CHECK_ONLY" = 1 ]; then
    printf '   %s(--check-only, so not offering to change anything)%s\n' "$DIM" "$R"
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

# The workshop repo is public, so every git call here is anonymous, and a
# credential cannot make a fetch succeed when it would otherwise fail. Left to
# itself git asks for one whenever it meets a 401, which on a managed laptop
# often comes from the proxy rather than from GitHub. An empty credential.helper
# resets the helper list, so nothing pops up asking to sign in, and
# GIT_TERMINAL_PROMPT=0 stops git asking in the terminal instead, which would
# stall this script. Every caller below already handles a failed git call. Per
# call: the attendee's own git config is not touched.
GIT_ANON=(-c credential.helper= -c credential.interactive=false -c core.askPass=)
git_anon() { GIT_TERMINAL_PROMPT=0 GIT_ASKPASS='' git "${GIT_ANON[@]}" "$@"; }

git_q() { git_anon -C "$PROJECT" "$@" 2>/dev/null; }

# Printed for every way this can fail: no git, no history, no network, a copy
# with local commits in it.  The attendee loses updated lesson *code*, but the
# lesson *pages* on the hosted mirror are always current, and most changes are
# to the pages.  So there is always somewhere to send them.
fallback() {
  warn "$1"
  info "Use the hosted guide instead. Its lesson pages are always the current ones:"
  info ""
  info "   $PAGES_URL"
  info ""
  info "Everything you type still runs in this folder. Only the pages come from there."
  info "Tell a helper, or post in 💬 #cybr-japac-ts-all, so we know."
}

# What to say once an update has landed.  Takes the list of changed paths, so it
# only mentions the parts of the folder that actually moved.
print_notes() {
  local changed="$1" hit=0
  step "✨" "What changed on your laptop"

  if printf '%s\n' "$changed" | grep -q '^lab/'; then
    good "the guide pages"
    info "Reload the lab page in your browser. A browser will happily show you the"
    info "old one from its cache."
    hit=1
  fi
  if printf '%s\n' "$changed" | grep -qE '^(ai-harness-app|sandbox-app)/'; then
    good "the lesson code"
    info "If a lesson script is running right now, stop it with Ctrl-C and start it"
    info "again. The file on disk changed under it."
    hit=1
  fi
  if printf '%s\n' "$changed" | grep -q '^skills/'; then
    good "the skills"
    info "Nothing to do. Claude Code reads them fresh each time it starts."
    hit=1
  fi
  if printf '%s\n' "$changed" | grep -q '^check-prereqs\.'; then
    good "the setup checker"
    warn "Run it again. Something it checks has changed:"
    run "bash check-prereqs.sh"
    hit=1
  fi
  [ "$hit" = 0 ] && dim "nothing that changes what you do next"

  printf '\n'
}

# ------------------------------------------------------------------- stage 2
#
# The updater can update itself.  When update.sh is one of the changed files,
# stage 1 fast-forwards and then re-execs the new copy with LAB_UPDATE_STAGE=2,
# so the notes an attendee reads come from the version they just pulled rather
# than the version they happened to download last week.  The stage guard is what
# stops that from looping.

if [ "${LAB_UPDATE_STAGE:-1}" = 2 ]; then
  print_notes "${LAB_UPDATE_CHANGED:-}"
  exit 0
fi

# --------------------------------------------------------------------- banner

cat <<BANNER

${B}🔄 SKO27 TechSummit - AI Workshop for Idira DC${R}
${DIM}   Guide updater · macOS / Linux · your virtual environment is not touched${R}

   Project folder : $PROJECT
BANNER

# --------------------------------------------------------- claude auto mode
#
# The same offer check-prereqs.sh makes in step 5, repeated here because this is
# the script the room runs on the morning. Anyone who did the prework before this
# offer existed, or who installed Claude Code today, is only reached here.
#
# It runs before the git work on purpose. Every branch below this can exit early,
# including the happy "you are on the current version" one, and auto mode needs
# neither git nor the network.
#
# Why the user settings file and not the workshop folder: a defaultMode in a
# project's .claude/settings.json is ignored, because a repo may not grant itself
# auto mode. check-prereqs.sh carries the long version of that note.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# claude_settings <python> <check|set>
#   check -> prints auto | bypass | unset | other:<value> | unreadable
#   set   -> prints set, and merges permissions.defaultMode=auto into the file,
#            keeping every other key, after taking one backup
claude_settings() {
  "$1" - "$CLAUDE_SETTINGS" "$2" <<'PYEOF'
import json, os, shutil, sys

path, action = sys.argv[1], sys.argv[2]
data = {}

if os.path.exists(path):
    try:
        with open(path, encoding='utf-8') as handle:
            text = handle.read().strip()
        data = json.loads(text) if text else {}
    except Exception:
        print('unreadable')
        sys.exit(0)

if not isinstance(data, dict):
    print('unreadable')
    sys.exit(0)

perms = data.get('permissions')
if perms is not None and not isinstance(perms, dict):
    print('unreadable')
    sys.exit(0)

current = perms.get('defaultMode') if perms else None

if action == 'check':
    if current == 'auto':
        print('auto')
    elif current == 'bypassPermissions':
        print('bypass')
    elif current is None:
        print('unset')
    else:
        print('other:%s' % current)
    sys.exit(0)

folder = os.path.dirname(path)
if folder:
    os.makedirs(folder, exist_ok=True)
if os.path.exists(path):
    backup = path + '.sko27-backup'
    if not os.path.exists(backup):
        shutil.copyfile(path, backup)

data.setdefault('permissions', {})['defaultMode'] = 'auto'

temp = path + '.sko27-tmp'
with open(temp, 'w', encoding='utf-8') as handle:
    json.dump(data, handle, indent=2)
    handle.write('\n')
os.replace(temp, path)
print('set')
PYEOF
}

CLAUDE_OK=0
for c in claude "$HOME/.local/bin/claude" "$HOME/bin/claude"; do
  if have "$c" && "$c" --version >/dev/null 2>&1; then CLAUDE_OK=1; break; fi
done

PYBIN=''
for cand in "$PROJECT/.venv/bin/python" python3 python; do
  if have "$cand" && "$cand" -c 'import json' >/dev/null 2>&1; then PYBIN="$cand"; break; fi
done

if [ "$CLAUDE_OK" = 1 ] && [ -n "$PYBIN" ]; then
  step "🤖" "Claude Code auto mode"
  case "$(claude_settings "$PYBIN" check 2>/dev/null)" in
    auto)
      good "already the default. Nothing to do."
      ;;
    bypass)
      warn "your settings ask for bypassPermissions, which is wider than auto mode"
      dim "Left exactly as it is. The lessons run either way."
      ;;
    unreadable)
      warn "$CLAUDE_SETTINGS is there, but this script cannot read it as JSON"
      dim "Left alone. In the agent, press Shift+Tab until the line says auto."
      ;;
    unset|other:*)
      info "The lessons assume auto mode, where the agent runs commands without"
      info "asking you first. It can be set once, here."
      warn "This applies to every folder on this laptop, not only the workshop one."
      if ask "Set Claude Code to auto mode by default? (edits $CLAUDE_SETTINGS)"; then
        if [ "$(claude_settings "$PYBIN" set 2>/dev/null)" = set ]; then
          good "auto mode is now the default"
          info "It stays that way after the workshop. To undo it, remove the"
          info "\"defaultMode\" line from $CLAUDE_SETTINGS"
          info "or copy $CLAUDE_SETTINGS.sko27-backup back over it."
        else
          bad "writing $CLAUDE_SETTINGS failed"
          dim "In the agent, press Shift+Tab until the bottom line says auto."
        fi
      else
        info "Left alone. In the agent, press Shift+Tab until the bottom line"
        info "says auto. Every lesson from 08 onward needs it."
      fi
      ;;
    *)
      warn "could not read the permission mode out of $CLAUDE_SETTINGS"
      dim "In the agent, press Shift+Tab until the bottom line says auto."
      ;;
  esac
fi

# ------------------------------------------------------------------- 1 · git

step "1️⃣ " "Can we check for updates?"

if ! have git; then
  bad "git is not installed"
  fallback "Without git this folder cannot update itself."
  exit 1
fi

if ! git_q rev-parse --git-dir >/dev/null; then
  bad "this folder has no version history in it"
  info "You most likely downloaded GitHub's 'Source code (zip)' rather than the"
  info "workshop package, or copied the folder somewhere. Lesson 08 needs the"
  info "history too, so this is worth repairing."
  info ""
  warn "The repair replaces every file here with the current version."
  warn "Anything you have edited yourself is lost. Your virtual environment stays."
  if ask "Repair this folder now?"; then
    git_anon -C "$PROJECT" init -q \
      && git_anon -C "$PROJECT" remote add origin "$REPO_URL" \
      && git_anon -C "$PROJECT" fetch -q --tags origin \
           "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" \
      && git_anon -C "$PROJECT" reset -q --hard "origin/$BRANCH" \
      && git_anon -C "$PROJECT" checkout -q -B "$BRANCH" \
      && { good "repaired — you are on the current version"; exit 0; }
    bad "the repair did not finish"
    fallback "Something stopped git from rebuilding the history."
    exit 1
  fi
  fallback "Not repaired, so this folder still cannot update itself."
  exit 1
fi

LOCAL_VER="$(git_q describe --tags --always || echo unknown)"
good "yes — your copy is version ${B}${LOCAL_VER}${R}${GRN}"

# ----------------------------------------------------------------- 2 · fetch

step "2️⃣ " "Asking GitHub what the current version is"

# Two repairs first, both silent, both about the packaged .git rather than anything
# the attendee did.  A build of the workshop zip can leave a dead access token in
# .git/config, which turns a fetch into a 401; and a folder that was copied about
# can lose its remote.
if [ -n "$(git_q config --get-all http.https://github.com/.extraheader)" ]; then
  git_q config --unset-all http.https://github.com/.extraheader
  dim "removed a stale credential from this folder's git settings"
fi
# Belt and braces, so a hand-typed 'git pull' in this folder cannot ask for a
# login either. Only when the folder has no helper of its own.
if ! git -C "$PROJECT" config --local --get-all credential.helper >/dev/null 2>&1; then
  git_q config --local --replace-all credential.helper ''
fi
if [ -z "$(git_q remote get-url origin)" ]; then
  git_q remote add origin "$REPO_URL" && dim "pointed this folder back at GitHub"
fi

# An explicit refspec, not a bare "main": it guarantees origin/main exists
# afterwards, whatever fetch settings the packaged .git happens to carry.
if ! git_q fetch --tags --quiet origin \
       "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"; then
  bad "could not reach GitHub"
  fallback "That is usually the network at the venue, not your laptop."
  exit 1
fi
good "asked"

# --------------------------------------------------------------- 3 · compare

step "3️⃣ " "Comparing"

BEHIND="$(git_q rev-list --count "HEAD..origin/$BRANCH" || echo 0)"
AHEAD="$(git_q rev-list --count "origin/$BRANCH..HEAD" || echo 0)"
REMOTE_VER="$(git_q describe --tags "origin/$BRANCH" 2>/dev/null || git_q rev-parse --short "origin/$BRANCH")"

if [ "$BEHIND" = 0 ]; then
  good "you are on the current version ($LOCAL_VER). Nothing to do."
  printf '\n'
  exit 0
fi

if [ "$BEHIND" = 1 ]; then
  warn "your copy is ${B}1 change behind${R}${YEL} — current is $REMOTE_VER"
else
  warn "your copy is ${B}$BEHIND changes behind${R}${YEL} — current is $REMOTE_VER"
fi

info ""
info "What you are missing:"
git_q log --oneline --no-decorate "HEAD..origin/$BRANCH" | sed 's/^/     /'
info ""

CHANGED="$(git_q diff --name-only "HEAD..origin/$BRANCH")"

if [ "$AHEAD" != 0 ]; then
  bad "your copy also has $AHEAD change of its own, so it cannot fast-forward"
  info "An agent committed something here, most likely in Lesson 12 or 14."
  info "Save anything you want to keep, then a helper can reset this folder with:"
  run "git fetch origin && git reset --hard origin/$BRANCH"
  fallback "Not updated, because updating would bury your own commits."
  exit 1
fi

# ------------------------------------------------------------- 4 · your edits

step "4️⃣ " "Your own edits"

DIRTY="$(git_q status --porcelain)"
STASHED=0

if [ -n "$DIRTY" ]; then
  warn "you have edited files here. Lesson 14 does this on purpose:"
  printf '%s\n' "$DIRTY" | sed 's/^/     /'
  info ""
  info "They will be put safely to one side, not deleted."
else
  good "none — nothing of yours is in the way"
fi

# ---------------------------------------------------------------- 5 · update

step "5️⃣ " "Update"

if ! ask "Update this folder to $REMOTE_VER?"; then
  info "Left alone. Your copy is still $LOCAL_VER."
  info "The current pages are always readable here, whatever your copy says:"
  info "   $PAGES_URL"
  printf '\n'
  exit 0
fi

if [ -n "$DIRTY" ]; then
  if git_q stash push --include-untracked --quiet \
       --message "before update to $REMOTE_VER"; then
    STASHED=1
    good "your edits are parked in the stash"
  else
    bad "could not park your edits"
    fallback "Nothing was changed. Your copy is still $LOCAL_VER."
    exit 1
  fi
fi

if ! git_q merge --ff-only --quiet "origin/$BRANCH"; then
  bad "the update did not apply"
  [ "$STASHED" = 1 ] && git_q stash pop --quiet && info "your edits are back"
  fallback "Nothing was changed. Your copy is still $LOCAL_VER."
  exit 1
fi

good "updated to $REMOTE_VER"

if [ "$STASHED" = 1 ]; then
  info ""
  warn "Your edits are still in the stash, not in your files. To put them back:"
  run "git stash pop"
  info "Do that only if you were part-way through Lesson 14 and want to carry on."
fi

# ------------------------------------------------------------------ 6 · notes

# If the updater itself moved, hand over to the copy we just pulled.
if printf '%s\n' "$CHANGED" | grep -q '^update\.sh$'; then
  export LAB_UPDATE_STAGE=2
  export LAB_UPDATE_CHANGED="$CHANGED"
  exec bash "$PROJECT/update.sh"
fi

print_notes "$CHANGED"
