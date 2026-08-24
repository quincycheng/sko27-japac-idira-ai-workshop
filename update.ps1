<#
    SKO27 TechSummit - AI Workshop for Idira DC
    Day-of updater for Windows PowerShell.  (macOS/Linux: use update.sh)

        .\update.ps1              check for a newer guide, and offer to apply it
        .\update.ps1 -CheckOnly   say what is out of date, change nothing
        .\update.ps1 -Yes         say yes to every offer (unattended)

    Why this exists: the lab guide and the lesson code can change after you
    downloaded this folder.  This says whether your copy is current, and brings
    it up to date in place if it is not.

    Two rules this script keeps, the same two check-prereqs.ps1 keeps:
      1. Nothing is installed outside your home folder and this project folder.
      2. Nothing is changed without asking you first.

    Your virtual environment is not tracked by git, so updating never touches
    it.  That is the whole reason this updates in place rather than telling you
    to download the folder again.

    If Windows refuses to run this ("running scripts is disabled on this
    system"), allow it for THIS WINDOW ONLY -- no admin rights needed:

        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    If Windows asks you to approve this script every time ("Security warning:
    run only scripts that you trust"), clear the downloaded-file mark once:

        Get-ChildItem -Recurse | Unblock-File

    This file is deliberately plain ASCII, and saved with a UTF-8 byte order
    mark.  Windows PowerShell 5.1 reads a .ps1 with no BOM using the machine's
    ANSI code page, not UTF-8, so a single non-ASCII character in here becomes
    mojibake and the script fails to parse before line 1 ever runs.  Keep both
    properties: no emoji, no em dashes, no box-drawing characters.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Continue'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$PagesUrl = 'https://quincycheng.github.io/sko27-japac-idira-ai-workshop/'
$RepoUrl  = 'https://github.com/quincycheng/sko27-japac-idira-ai-workshop.git'
$Branch   = 'main'

# ---------------------------------------------------------------- appearance

$Project = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

function Write-Step ($Num, $Text) { Write-Host ''; Write-Host "$Num $Text" -ForegroundColor White }
function Write-Info ($Text) { Write-Host "   $Text" }
function Write-Dim  ($Text) { Write-Host "   $Text" -ForegroundColor DarkGray }
function Write-Good ($Text) { Write-Host "   [ OK ] $Text" -ForegroundColor Green }
function Write-Bad  ($Text) { Write-Host "   [FAIL] $Text" -ForegroundColor Red }
function Write-Warn ($Text) { Write-Host "   [WARN] $Text" -ForegroundColor Yellow }
function Write-Cmd  ($Text) { Write-Host "   > $Text" -ForegroundColor Cyan }

function Confirm-Action ($Question) {
    if ($CheckOnly) {
        Write-Host '   (-CheckOnly, so not offering to change anything)' -ForegroundColor DarkGray
        return $false
    }
    if ($Yes) {
        Write-Host "   [auto] $Question -> yes (-Yes)" -ForegroundColor DarkGray
        return $true
    }
    $reply = Read-Host "   $Question [y/N]"
    return ($reply -match '^(y|yes)$')
}

function Have-Command ($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# The workshop repo is public, so every git call in this script is anonymous and a
# credential cannot make a fetch succeed that would otherwise fail.  Git for
# Windows disagrees by default.  Its credential manager opens a "Sign in to
# GitHub" window on any 401, and git asks for a username and a password as two
# separate questions, so one fetch produces two windows.  On a managed laptop a
# 401 often comes from the proxy rather than from GitHub, so the attendee is being
# asked to log in to fix something a login cannot fix.  This script fetches twice
# on the repair path, which is four windows.
#   credential.helper=            an empty value resets the helper list: no window
#   credential.interactive=false  the same instruction, for GCM 2.x
#   core.askPass=                 and no askpass GUI either
# With no helper left, git falls back to asking in the console, which would stop
# this script dead waiting for an answer.  GIT_TERMINAL_PROMPT=0 makes it fail
# fast instead, and every caller below already handles a failed git call.
# Everything is per call.  Nothing is written to the attendee's own git config.
$GitAnon = @('-c', 'credential.helper=', '-c', 'credential.interactive=false', '-c', 'core.askPass=')

# Both wrappers set the two variables and put them back, because $env: here is
# the window the attendee is sitting in.
function Set-GitNoPrompt {
    $saved = @{ Prompt = $env:GIT_TERMINAL_PROMPT; AskPass = $env:GIT_ASKPASS }
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GIT_ASKPASS         = ''
    return $saved
}

function Reset-GitNoPrompt ($Saved) {
    $env:GIT_TERMINAL_PROMPT = $Saved.Prompt
    $env:GIT_ASKPASS         = $Saved.AskPass
}

# Output of a git command, or nothing when it fails.  Errors are swallowed on
# purpose: every caller below decides for itself what a failure means.
function Get-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $saved = Set-GitNoPrompt
    try {
        $out = & git @GitAnon -C $Project @Arguments 2>$null
        return $out
    } finally { Reset-GitNoPrompt $saved }
}

# Ran a git command for its effect rather than its output.  $true when it worked.
function Test-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $saved = Set-GitNoPrompt
    try {
        & git @GitAnon -C $Project @Arguments *> $null
        return ($LASTEXITCODE -eq 0)
    } finally { Reset-GitNoPrompt $saved }
}

function Test-Changed ($Changed, $Pattern) {
    return [bool]($Changed | Where-Object { $_ -match $Pattern })
}

# Printed for every way this can fail: no git, no history, no network, a copy
# with local commits in it.  The attendee loses updated lesson *code*, but the
# lesson *pages* on the hosted mirror are always current, and most changes are
# to the pages.  So there is always somewhere to send them.
function Write-Fallback ($Reason) {
    Write-Warn $Reason
    Write-Info 'Use the hosted guide instead. Its lesson pages are always the current ones:'
    Write-Info ''
    Write-Info "   $PagesUrl"
    Write-Info ''
    Write-Info 'Everything you type still runs in this folder. Only the pages come from there.'
    Write-Info 'Tell a helper, or post in #cybr-japac-ts-all, so we know.'
}

# What to say once an update has landed.  Takes the list of changed paths, so it
# only mentions the parts of the folder that actually moved.
function Write-Notes ($Changed) {
    $hit = $false
    Write-Step '*' 'What changed on your laptop'

    if (Test-Changed $Changed '^lab/') {
        Write-Good 'the guide pages'
        Write-Info 'Reload the lab page in your browser. A browser will happily show you the'
        Write-Info 'old one from its cache.'
        $hit = $true
    }
    if (Test-Changed $Changed '^(ai-harness-app|sandbox-app)/') {
        Write-Good 'the lesson code'
        Write-Info 'If a lesson script is running right now, stop it with Ctrl-C and start it'
        Write-Info 'again. The file on disk changed under it.'
        $hit = $true
    }
    if (Test-Changed $Changed '^skills/') {
        Write-Good 'the skills'
        Write-Info 'Nothing to do. Claude Code reads them fresh each time it starts.'
        $hit = $true
    }
    if (Test-Changed $Changed '^check-prereqs\.') {
        Write-Good 'the setup checker'
        Write-Warn 'Run it again. Something it checks has changed:'
        Write-Cmd '.\check-prereqs.ps1'
        $hit = $true
    }
    if (-not $hit) { Write-Dim 'nothing that changes what you do next' }

    Write-Host ''
}

# ------------------------------------------------------------------- stage 2
#
# The updater can update itself.  When update.ps1 is one of the changed files,
# stage 1 fast-forwards and then re-runs the new copy with LAB_UPDATE_STAGE=2,
# so the notes an attendee reads come from the version they just pulled rather
# than the version they happened to download last week.  The stage guard is what
# stops that from looping.

if ($env:LAB_UPDATE_STAGE -eq '2') {
    $carried = @()
    if ($env:LAB_UPDATE_CHANGED) { $carried = $env:LAB_UPDATE_CHANGED -split "`n" }
    Write-Notes $carried
    exit 0
}

# --------------------------------------------------------------------- banner

Write-Host ''
Write-Host 'SKO27 TechSummit - AI Workshop for Idira DC' -ForegroundColor White
Write-Host '   Guide updater | Windows | your virtual environment is not touched' -ForegroundColor DarkGray
Write-Host ''
Write-Host "   Project folder : $Project"

# ------------------------------------------------------------------- 1 - git

Write-Step '1.' 'Can we check for updates?'

if (-not (Have-Command 'git')) {
    Write-Bad 'git is not installed'
    Write-Fallback 'Without git this folder cannot update itself.'
    exit 1
}

if (-not (Test-Git 'rev-parse' '--git-dir')) {
    Write-Bad 'this folder has no version history in it'
    Write-Info "You most likely downloaded GitHub's 'Source code (zip)' rather than the"
    Write-Info 'workshop package, or copied the folder somewhere. Lesson 08 needs the'
    Write-Info 'history too, so this is worth repairing.'
    Write-Info ''
    Write-Warn 'The repair replaces every file here with the current version.'
    Write-Warn 'Anything you have edited yourself is lost. Your virtual environment stays.'
    if (Confirm-Action 'Repair this folder now?') {
        $ok = (Test-Git 'init' '-q') `
            -and (Test-Git 'remote' 'add' 'origin' $RepoUrl) `
            -and (Test-Git 'fetch' '-q' '--tags' 'origin' "+refs/heads/$Branch`:refs/remotes/origin/$Branch") `
            -and (Test-Git 'reset' '-q' '--hard' "origin/$Branch") `
            -and (Test-Git 'checkout' '-q' '-B' $Branch)
        if ($ok) {
            Write-Good 'repaired -- you are on the current version'
            exit 0
        }
        Write-Bad 'the repair did not finish'
        Write-Fallback 'Something stopped git from rebuilding the history.'
        exit 1
    }
    Write-Fallback 'Not repaired, so this folder still cannot update itself.'
    exit 1
}

$localVer = (Get-Git 'describe' '--tags' '--always' | Select-Object -First 1)
if (-not $localVer) { $localVer = 'unknown' }
Write-Good "yes -- your copy is version $localVer"

# ----------------------------------------------------------------- 2 - fetch

Write-Step '2.' 'Asking GitHub what the current version is'

# Two repairs first, both silent, both about the packaged .git rather than anything
# the attendee did.  A build of the workshop zip can leave a dead access token in
# .git/config, which turns a fetch into a 401; and a folder that was copied about
# can lose its remote.
if (Get-Git 'config' '--get-all' 'http.https://github.com/.extraheader') {
    if (Test-Git 'config' '--unset-all' 'http.https://github.com/.extraheader') {
        Write-Dim "removed a stale credential from this folder's git settings"
    }
}
if (-not (Get-Git 'remote' 'get-url' 'origin')) {
    if (Test-Git 'remote' 'add' 'origin' $RepoUrl) {
        Write-Dim 'pointed this folder back at GitHub'
    }
}

# An explicit refspec, not a bare "main": it guarantees origin/main exists
# afterwards, whatever fetch settings the packaged .git happens to carry.
if (-not (Test-Git 'fetch' '--tags' '--quiet' 'origin' "+refs/heads/$Branch`:refs/remotes/origin/$Branch")) {
    Write-Bad 'could not reach GitHub'
    Write-Fallback 'That is usually the network at the venue, not your laptop.'
    exit 1
}
Write-Good 'asked'

# --------------------------------------------------------------- 3 - compare

Write-Step '3.' 'Comparing'

$behind = [int]((Get-Git 'rev-list' '--count' "HEAD..origin/$Branch" | Select-Object -First 1))
$ahead  = [int]((Get-Git 'rev-list' '--count' "origin/$Branch..HEAD" | Select-Object -First 1))

$remoteVer = (Get-Git 'describe' '--tags' "origin/$Branch" | Select-Object -First 1)
if (-not $remoteVer) {
    $remoteVer = (Get-Git 'rev-parse' '--short' "origin/$Branch" | Select-Object -First 1)
}

if ($behind -eq 0) {
    Write-Good "you are on the current version ($localVer). Nothing to do."
    Write-Host ''
    exit 0
}

if ($behind -eq 1) {
    Write-Warn "your copy is 1 change behind -- current is $remoteVer"
} else {
    Write-Warn "your copy is $behind changes behind -- current is $remoteVer"
}

Write-Info ''
Write-Info 'What you are missing:'
Get-Git 'log' '--oneline' '--no-decorate' "HEAD..origin/$Branch" |
    ForEach-Object { Write-Host "     $_" }
Write-Info ''

$changed = @(Get-Git 'diff' '--name-only' "HEAD..origin/$Branch")

if ($ahead -ne 0) {
    Write-Bad "your copy also has $ahead change of its own, so it cannot fast-forward"
    Write-Info 'An agent committed something here, most likely in Lesson 12 or 14.'
    Write-Info 'Save anything you want to keep, then a helper can reset this folder with:'
    Write-Cmd "git fetch origin; git reset --hard origin/$Branch"
    Write-Fallback 'Not updated, because updating would bury your own commits.'
    exit 1
}

# ------------------------------------------------------------- 4 - your edits

Write-Step '4.' 'Your own edits'

$dirty = @(Get-Git 'status' '--porcelain')
$stashed = $false

if ($dirty.Count -gt 0) {
    Write-Warn 'you have edited files here. Lesson 14 does this on purpose:'
    $dirty | ForEach-Object { Write-Host "     $_" }
    Write-Info ''
    Write-Info 'They will be put safely to one side, not deleted.'
} else {
    Write-Good 'none -- nothing of yours is in the way'
}

# ---------------------------------------------------------------- 5 - update

Write-Step '5.' 'Update'

if (-not (Confirm-Action "Update this folder to $remoteVer?")) {
    Write-Info "Left alone. Your copy is still $localVer."
    Write-Info 'The current pages are always readable here, whatever your copy says:'
    Write-Info "   $PagesUrl"
    Write-Host ''
    exit 0
}

if ($dirty.Count -gt 0) {
    if (Test-Git 'stash' 'push' '--include-untracked' '--quiet' '--message' "before update to $remoteVer") {
        $stashed = $true
        Write-Good 'your edits are parked in the stash'
    } else {
        Write-Bad 'could not park your edits'
        Write-Fallback "Nothing was changed. Your copy is still $localVer."
        exit 1
    }
}

if (-not (Test-Git 'merge' '--ff-only' '--quiet' "origin/$Branch")) {
    Write-Bad 'the update did not apply'
    if ($stashed -and (Test-Git 'stash' 'pop' '--quiet')) { Write-Info 'your edits are back' }
    Write-Fallback "Nothing was changed. Your copy is still $localVer."
    exit 1
}

Write-Good "updated to $remoteVer"

if ($stashed) {
    Write-Info ''
    Write-Warn 'Your edits are still in the stash, not in your files. To put them back:'
    Write-Cmd 'git stash pop'
    Write-Info 'Do that only if you were part-way through Lesson 14 and want to carry on.'
}

# ------------------------------------------------------------------ 6 - notes

# If the updater itself moved, hand over to the copy we just pulled.
if (Test-Changed $changed '^update\.ps1$') {
    $env:LAB_UPDATE_STAGE = '2'
    $env:LAB_UPDATE_CHANGED = ($changed -join "`n")
    & $PSCommandPath
    exit $LASTEXITCODE
}

Write-Notes $changed
