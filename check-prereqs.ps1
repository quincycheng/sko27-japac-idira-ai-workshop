<#
    SKO27 TechSummit - AI Workshop for Idira DC
    Setup checker for Windows PowerShell.  (macOS/Linux: use check-prereqs.sh)

        .\check-prereqs.ps1              check, and offer to fix what is missing
        .\check-prereqs.ps1 -CheckOnly   check only, never change anything
        .\check-prereqs.ps1 -Yes         say yes to every offer (unattended)

    Two rules this script keeps, because the audience has no admin rights:
      1. Nothing is installed outside your home folder and this project folder.
      2. Nothing is changed without asking you first.

    If Windows refuses to run this ("running scripts is disabled on this
    system"), allow it for THIS WINDOW ONLY -- no admin rights needed:

        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    If Windows asks you to approve this script every time ("Security warning:
    run only scripts that you trust"), the folder came out of a downloaded zip
    and every file in it is still marked untrusted.  Clear the mark once:

        Get-ChildItem -Recurse | Unblock-File

    This file is deliberately plain ASCII, and saved with a UTF-8 byte order
    mark.  Windows PowerShell 5.1 reads a .ps1 with no BOM using the machine's
    ANSI code page, not UTF-8, so a single non-ASCII character in here becomes
    mojibake and the script fails to parse before line 1 ever runs.  Keep both
    properties: no emoji, no em dashes, no box-drawing characters.

    Two rules about quoting, for the same reason.  Windows PowerShell 5.1 hands
    an argument containing spaces to a native program by wrapping it in double
    quotes, and it does NOT escape any double quote already inside it.  So:

      1. Never put a double quote inside an argument to python, idsec or jq.
         Use Python's single quotes instead.  A snippet like
             -c 'print("hi")'
         reaches python as print(hi), which is a SyntaxError and an exit code of
         1.  Nothing prints, so it reads as "that tool is missing" rather than
         as a bug in this script.
      2. Never put a newline inside one either.  Write the snippet on one line,
         or put it in a temp file the way the TLS probe in step 9 does.

    PowerShell 7 fixed both.  Windows PowerShell 5.1 is what the room has, so
    test any change to a -c argument there, not only in pwsh.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Continue'

# Set-StrictMode is inherited from whatever the attendee's PowerShell profile did,
# and a profile that turns it on turns a harmless read of a missing property into
# an error that stops this script dead.  That already happened once, in step 7.
# This is a diagnostic run on sixty laptops we cannot inspect, so it asks for one
# known mode rather than trusting sixty unknown ones.  Scoped to this script: it
# does not leak back into the window it was run from.
Set-StrictMode -Off

$PSDefaultParameterValues['*:Encoding'] = 'utf8'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# ---------------------------------------------------------------- appearance

$Project = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Venv    = Join-Path $Project '.venv'
$VPy     = Join-Path $Venv 'Scripts\python.exe'
$BinDir  = Join-Path $HOME 'bin'

$Summary = [System.Collections.Generic.List[object]]::new()
$Todo    = [System.Collections.Generic.List[string]]::new()

function Add-Pass  ($What, $Detail) { $Summary.Add([pscustomobject]@{ Icon='[ OK ]'; What=$What; Detail=$Detail }) }
function Add-Fixed ($What, $Detail) { $Summary.Add([pscustomobject]@{ Icon='[FIXED]'; What=$What; Detail=$Detail }) }
function Add-Manual($What, $Detail) { $Summary.Add([pscustomobject]@{ Icon='[CHECK]'; What=$What; Detail=$Detail }) }
function Add-Fail  ($What, $Detail, $Next) {
    $Summary.Add([pscustomobject]@{ Icon='[FAIL]'; What=$What; Detail=$Detail })
    $Script:Todo.Add($Next)
}

function Write-Step ($Num, $Text) { Write-Host ''; Write-Host "$Num $Text" -ForegroundColor White }
function Write-Info ($Text) { Write-Host "   $Text" }
function Write-Dim  ($Text) { Write-Host "   $Text" -ForegroundColor DarkGray }
function Write-Good ($Text) { Write-Host "   [ OK ] $Text" -ForegroundColor Green }
function Write-Bad  ($Text) { Write-Host "   [FAIL] $Text" -ForegroundColor Red }
function Write-Warn ($Text) { Write-Host "   [WARN] $Text" -ForegroundColor Yellow }
function Write-Cmd  ($Text) { Write-Host "   > $Text" -ForegroundColor Cyan }

# Confirm-Action "question" -> $true for yes. Honours -Yes and -CheckOnly.
function Confirm-Action ($Question) {
    if ($CheckOnly) {
        Write-Host "   (-CheckOnly, so not offering to fix this)" -ForegroundColor DarkGray
        return $false
    }
    if ($Yes) {
        Write-Host "   [auto] $Question -> yes (-Yes)" -ForegroundColor DarkGray
        return $true
    }
    $reply = Read-Host "   $Question [y/N]"
    return ($reply -match '^(y|yes)$')
}

# The workshop repo is public, so every git call in this script is anonymous and
# read-only.  A credential cannot make a fetch succeed that would otherwise fail.
# Git for Windows disagrees by default.  Its credential manager opens a "Sign in
# to GitHub" window on any 401, and git asks for a username and a password as two
# separate questions, so one fetch produces two windows.  On a managed laptop a
# 401 often comes from the proxy rather than from GitHub, so the attendee is being
# asked to log in to fix something a login cannot fix.
#   credential.helper=            an empty value resets the helper list: no window
#   credential.interactive=false  the same instruction, for GCM 2.x
#   core.askPass=                 and no askpass GUI either
# With no helper left, git falls back to asking in the console, which would stop
# this script dead waiting for an answer.  GIT_TERMINAL_PROMPT=0 makes it fail
# fast instead, and a failed fetch is already handled: the version line just says
# it could not reach GitHub.  Everything is per call.  Nothing is written to the
# attendee's own git config.
#
# These flags stop the window opening.  They do not stop a 401 happening, because
# a stale extraheader is sent whatever the helper list says.  Repair-PackagedGit
# below deals with that, and the two are needed together.
$GitAnon = @('-c', 'credential.helper=', '-c', 'credential.interactive=false', '-c', 'core.askPass=')

function Invoke-GitAnon {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    # $env: here is the window the attendee is sitting in, so both are put back.
    $oldPrompt  = $env:GIT_TERMINAL_PROMPT
    $oldAskPass = $env:GIT_ASKPASS
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GIT_ASKPASS         = ''
    try {
        & git @GitAnon -C $Project @Arguments *> $null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $env:GIT_TERMINAL_PROMPT = $oldPrompt
        $env:GIT_ASKPASS         = $oldAskPass
    }
}

# Repairs two things the workshop download itself got wrong.  Both are ours, not
# the attendee's, and both are inside this project folder only.
#
# 1. A dead access token.  The zip is built by a GitHub Actions job, and
#    actions/checkout writes a one-hour token into .git/config as an
#    http.<host>.extraheader.  The zip then ships it to sixty laptops, where it
#    expired long ago.  It is an HTTP header, not a credential, so the anonymous
#    flags above do not stop git sending it: GitHub answers 401, and Git for
#    Windows opens "Sign in to GitHub" twice for one fetch.  Nobody in the room
#    needs an account.  The repo is public, and an anonymous fetch works as soon
#    as the dead header is gone.  So it goes.
#
# 2. No credential helper for this folder.  Belt and braces for a 401 we do not
#    control, such as an inspecting proxy.  With the helper list reset there is no
#    GUI sign-in window for this folder, whatever anyone types in it.  git can
#    still ask on the console, which this script's own calls avoid with
#    GIT_TERMINAL_PROMPT=0, and which a hand-typed command can answer with
#    Ctrl-C.  Nothing outside this folder is touched.
#
# release.yml now passes persist-credentials: false, so a package built after that
# carries no token and part 1 finds nothing to do.  This stays for every folder
# downloaded before then.
function Repair-PackagedGit {
    $header = 'http.https://github.com/.extraheader'
    if (& git -C $Project config --get-all $header 2>$null) {
        if (Invoke-GitAnon 'config' '--unset-all' $header) {
            Write-Dim 'removed a dead access token that the download left in this folder'
        }
    }
    # Only when this folder has no helper of its own.  Someone who set one
    # deliberately keeps it.
    & git -C $Project config --local --get-all credential.helper *> $null
    if ($LASTEXITCODE -ne 0) {
        Invoke-GitAnon 'config' '--local' '--replace-all' 'credential.helper' '' | Out-Null
    }
    # 3. The packaged repo is checked out at a tag, so main has no upstream and a
    #    hand-typed "git pull" answers "no tracking information" instead of
    #    pulling.  Pure config, no network.  update.ps1 does not need this, it
    #    uses explicit refspecs, but a helper typing git pull does.
    $branch = (& git -C $Project symbolic-ref --short -q HEAD 2>$null | Select-Object -First 1)
    if ($branch) {
        & git -C $Project config --local --get "branch.$branch.remote" *> $null
        if ($LASTEXITCODE -ne 0) {
            Invoke-GitAnon 'config' '--local' "branch.$branch.remote" 'origin' | Out-Null
            Invoke-GitAnon 'config' '--local' "branch.$branch.merge" "refs/heads/$branch" | Out-Null
        }
    }
}

# Tells the rest of Windows that the user environment changed.
#
# Writing the registry is only half of a PATH change. Nothing watches that key.
# A program picks the new value up when someone broadcasts WM_SETTINGCHANGE for
# 'Environment', which is exactly what Microsoft's own guidance says to do after
# the write. Skip it and explorer.exe carries on handing out the environment
# block it captured at sign-in, and since the Start menu, the taskbar and Windows
# Terminal all launch from explorer, a NEW window still gets the OLD PATH. That
# is what made a freshly installed idsec unreachable: the folder was in the
# registry, spelled correctly, and no new window could see it.
#
# The broadcast needs a window message and PowerShell has no cmdlet for one. But
# [Environment]::SetEnvironmentVariable does it internally, for any user
# variable, straight after its own registry write. So a throwaway variable is set
# and removed here purely to trigger it. Path itself must not go through that
# call, for the reason in Add-UserPath below. The direct route, a P/Invoke of
# SendMessageTimeout, needs Add-Type to compile an assembly at runtime, which
# application control on a managed laptop may refuse to load.
function Publish-EnvChange {
    # -CheckOnly promises to change nothing, and the trick below writes a registry
    # value. Callers that fix a PATH are already behind Confirm-Action, which
    # returns false under -CheckOnly. The caller in Resolve-BinDirTool is not: it
    # broadcasts a PATH somebody else wrote, so the guard belongs here.
    if ($CheckOnly) { return }
    try {
        [Environment]::SetEnvironmentVariable('IDIRA_SETUP_REFRESH', '1', 'User')
        [Environment]::SetEnvironmentVariable('IDIRA_SETUP_REFRESH', $null, 'User')
    } catch {
        # The PATH itself is still correct. Worst case a new window does not see
        # it until the attendee signs out and back in.
    }
}

# Makes THIS window see $Dir. A window keeps the environment it started with, so
# a saved PATH that is already correct still leaves the current window unable to
# run the tool. Rebuilding $env:Path from the registry would throw away whatever
# this session added, so the one folder is appended instead.
function Add-SessionPath ($Dir) {
    $want = ([string]$Dir).TrimEnd('\', '/')
    $here = @($env:Path -split ';' | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\', '/') })
    if ($here -notcontains $want) { $env:Path = "$env:Path;$Dir" }
}

# Adds $Dir to the user PATH, and leaves the rest of that PATH exactly as it was.
# $false means it was already there, so nothing was written.
#
# Defined up here with the other helpers rather than next to its first caller,
# because a script runs top to bottom: a function called by step 5 but defined
# inside step 6 does not exist yet at the moment step 5 needs it.
#
# The obvious version of this, [Environment]::GetEnvironmentVariable('Path','User')
# followed by SetEnvironmentVariable, quietly damages a managed laptop: the getter
# expands any %LOCALAPPDATA% style entries to their current values, and the setter
# writes the result back as a plain string. Every variable in the user PATH is then
# frozen to whatever it meant in this window. So the registry is read and written
# directly here, with expansion turned off and the value kind preserved.
function Add-UserPath ($Dir) {
    $want = ([string]$Dir).TrimEnd('\', '/')
    # Opened inside the try, and $null first, so that a registry failure lands in
    # the catch below instead of escaping.  The finally reads $key, and a variable
    # that never got assigned is its own separate error.
    $key = $null
    $wrote = $false
    try {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        $userPath = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        # A PATH holding %VAR% must stay ExpandString, or the %VAR% becomes literal.
        $kind = if ($userPath -match '%') { 'ExpandString' } else { 'String' }
        # Trailing slashes off both sides, the way Test-InUserPath does it.
        # Comparing the raw strings read an entry that ends in a backslash as
        # absent, and appended a second copy of the same folder.
        $have = @($userPath -split ';' | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\', '/') })
        if ($have -notcontains $want) {
            $joined = if ($userPath) { "$userPath;$Dir" } else { $Dir }
            # 'User' scope, not 'Machine' -- this is why no admin prompt appears.
            $key.SetValue('Path', $joined, $kind)
            $wrote = $true
        }
    } catch {
        # No registry for some reason. Fall back rather than leave PATH untouched.
        # This call broadcasts by itself, so the Publish-EnvChange below is a
        # second one. Harmless: it only makes listeners re-read a key twice.
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$Dir".TrimStart(';'), 'User')
        $wrote = $true
    } finally {
        if ($key) { $key.Close() }
    }
    if ($wrote) { Publish-EnvChange }
    # And this window, so the steps after this one can run the tool that was just
    # installed. Done whether or not the saved PATH needed changing: the case
    # this exists for is a saved PATH that is already right and a window that
    # opened before it was.
    Add-SessionPath $Dir
    return $wrote
}

# Is $Dir already in the PATH that new windows will get?  This is the saved user
# PATH, not $env:Path, so it answers "will a new window find this?" rather than
# "does this window find it?"  Those two differ for the whole of the window that
# ran an installer, which is the case this exists for.
function Test-InUserPath ($Dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return $false }
    # An entry may or may not carry a trailing slash, so both sides lose theirs
    # before the comparison.  Without this, a PATH holding the folder with a
    # trailing backslash reads as absent and a second copy gets appended.
    # -contains is case-insensitive, which is what Windows wants.
    $want = ([string]$Dir).TrimEnd('\', '/')
    $have = @($userPath -split ';' | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\', '/') })
    return ($have -contains $want)
}

# Where the idsec profile and the cached token live, and why this script has to
# decide both.
#
# The CLI resolves its profiles folder in the SDK, at
# idsec-sdk-golang/pkg/profiles/idsec_profile_loader.go:126 -- the
# IDSEC_PROFILES_FOLDER environment variable if set, otherwise HOME joined with
# .idsec\profiles. That is the HOME *environment variable*, and PowerShell does not
# have one: $HOME there is a PowerShell variable, so $env:HOME is empty and the
# join produces the RELATIVE path .idsec\profiles.
#
# So on Windows the profile is written to, and looked for in, whatever folder is
# current. This script runs from the workshop folder, so 'idsec configure' put the
# profile there. Lesson 09 works inside sandbox-app, where there is none, and every
# idsec command in that folder answers 'No profile found' -- including the ones the
# agent runs, which then cannot list a single target. The log path is resolved
# differently, from the OS home directory, which is why a .idsec folder holding
# only 'logs' is the signature of this.
#
# The cached login token has the same defect, one folder deeper. On Windows the SDK
# asks Credential Manager first (idsec_keyring.go:117), but Credential Manager
# refuses a blob over about 2.5 KB and an idsec token is a JWT, so the write often
# fails and the SDK falls back to its own encrypted file. The read path falls back
# the same way, and on Windows it does so even when the entry is simply absent --
# the SDK's own comment at idsec_os_provided_keyring.go:145 says the creds may be
# 'too long for windows cred manager'. That file lives in HOME joined with
# .idsec\cache\keyring (idsec_basic_keyring.go:88), so it is relative to the current
# folder too. A login done in one folder then reads as expired in another. That is
# the second half of the lesson 09 failure: profile found, token nowhere.
#
# Both variables win over HOME, so pinning them once ends the whole class of
# problem: the current folder stops mattering, in this window, in a new one, and in
# the Git Bash that Claude Code runs its own commands through.
#
# The values sit under %USERPROFILE%\.idsec for two reasons. It is where idsec
# already writes its logs, so one .idsec folder holds everything. And it is what
# $HOME means in PowerShell and what ~ means on macOS, so '~/.idsec/profiles' in the
# lab guide and in the skills stays a true statement on both platforms.
$IdsecHome           = $(if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME })
$IdsecProfilesVar    = 'IDSEC_PROFILES_FOLDER'
$IdsecProfilesTmpl   = '%USERPROFILE%\.idsec\profiles'
$IdsecProfilesFolder = Join-Path $IdsecHome '.idsec\profiles'
$IdsecKeyringVar     = 'IDSEC_KEYRING_FOLDER'
$IdsecKeyringTmpl    = '%USERPROFILE%\.idsec\cache\keyring'
$IdsecKeyringFolder  = Join-Path $IdsecHome '.idsec\cache\keyring'

# Pins one of those variables for new windows. $false means it was already set to
# something, and an attendee who chose their own value keeps it.
#
# Written straight to the registry with expansion off, for the reason Add-UserPath
# gives: the getter expands %VAR% style entries and writing the result back freezes
# them. Kept as an ExpandString here so a folder that moves with USERPROFILE keeps
# following it.
function Set-IdsecFolderVar ($Name, $Template, $Expanded) {
    $key = $null
    try {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        $existing = [string]$key.GetValue($Name, '', 'DoNotExpandEnvironmentNames')
        if ($existing.Trim()) { return $false }
        $key.SetValue($Name, $Template, 'ExpandString')
    } catch {
        # No registry for some reason. The plain setter cannot write an ExpandString,
        # so the expanded path goes in instead: correct today, and it stops following
        # USERPROFILE if that ever changes.
        $existing = [string][Environment]::GetEnvironmentVariable($Name, 'User')
        if ($existing.Trim()) { return $false }
        [Environment]::SetEnvironmentVariable($Name, $Expanded, 'User')
    } finally {
        if ($key) { $key.Close() }
    }
    Publish-EnvChange
    return $true
}

# Moves profiles written before the variable was pinned. They are in the folder
# 'idsec configure' ran from, which for anyone who used this script is the workshop
# folder. Never overwrites: a file already at the destination stays, and the copy it
# came from is left where it is so nothing disappears silently.
function Get-IdsecProfileFiles ($Dir) {
    return @(Get-ChildItem -File $Dir -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notlike '.*' })
}

function Move-IdsecProfile ($From) {
    $files = Get-IdsecProfileFiles $From
    if (-not $files) { return $false }
    if (-not (Test-Path $IdsecProfilesFolder)) {
        New-Item -ItemType Directory -Force $IdsecProfilesFolder | Out-Null
    }
    $moved = 0
    foreach ($f in $files) {
        $dest = Join-Path $IdsecProfilesFolder $f.Name
        if (Test-Path $dest) {
            Write-Dim "left $($f.Name) alone -- there is already one of those in the pinned folder"
            continue
        }
        Move-Item $f.FullName $dest
        $moved++
    }
    if ($moved -gt 0) { Write-Good "moved $moved profile file(s) to $IdsecProfilesFolder" }
    # Nothing but the CLI's own bookkeeping dotfiles left, so the empty folder goes.
    # Only this one folder: its parent .idsec may hold a cache, and that is not ours
    # to delete.
    if (-not (Get-IdsecProfileFiles $From)) {
        Remove-Item -Recurse -Force $From -ErrorAction SilentlyContinue
    }
    return ($moved -gt 0)
}

# Moves a token cache written before the variable was pinned, so the attendee keeps
# the login they already did.
#
# The two files move together or not at all. 'mac' holds a SHA256 of 'keyring' and
# the SDK rejects the pair if they disagree (idsec_basic_keyring.go:165), so half a
# move is a keyring the CLI refuses to read. Neither file is path-bound otherwise:
# the encryption key is the hostname, so the pair still decrypts in its new folder.
#
# A cache already in the pinned folder is never overwritten. It may hold a working
# token, and one encrypted file cannot be merged into another. The stray one is left
# in place and reported instead.
function Move-IdsecKeyring ($From) {
    $names = @('keyring', 'mac')
    foreach ($n in $names) {
        if (-not (Test-Path (Join-Path $From $n))) {
            Write-Dim "left the token cache in $From alone -- it has no '$n' file, so it is unreadable anyway"
            return $false
        }
        if (Test-Path (Join-Path $IdsecKeyringFolder $n)) {
            Write-Dim "left the token cache in $From alone -- the pinned folder has one already"
            return $false
        }
    }
    if (-not (Test-Path $IdsecKeyringFolder)) {
        New-Item -ItemType Directory -Force $IdsecKeyringFolder | Out-Null
    }
    foreach ($n in $names) {
        Move-Item (Join-Path $From $n) (Join-Path $IdsecKeyringFolder $n)
    }
    Write-Good "moved your cached login to $IdsecKeyringFolder"
    Remove-Item -Recurse -Force $From -ErrorAction SilentlyContinue
    return $true
}

function Have-Command ($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Get-Command only proves a file is on PATH. On a managed laptop the file can be
# there and still refuse to start, because application control decides which
# programs may run. So every tool below is checked by actually running it.
function Test-Runs ($Exe, [string[]]$Arguments) {
    try {
        & $Exe @Arguments *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# Printed when a program is on PATH but will not execute. Deliberately does not
# suggest a workaround: routing around application control is the opposite of
# what this workshop teaches.
# $Where names the file when it was found somewhere other than the PATH, so the
# first line does not claim a PATH the program is not actually on.
function Write-Blocked ($Name, $Where) {
    if ($Where) {
        Write-Bad "'$Name' is at $Where but will not run"
    } else {
        Write-Bad "'$Name' is on your PATH but will not run"
    }
    Write-Info 'That is endpoint application control, not a PATH problem. It decides'
    Write-Info 'which programs may run on a managed laptop. Please do not work around it.'
    Write-Info "Offered a 'Request for authorization' button? Use it. Otherwise ask in"
    Write-Info 'the #cybr-japac-ts-all Slack channel TODAY.'
}

# idsec and jq are both a single .exe in $BinDir, and both arrive here the same
# way: the file exists, the command does not. There are three real answers, and
# the old code gave one message for all of them. It offered to add a folder the
# PATH already had, wrote nothing, said 'added', and recorded the tool as fixed
# even when the attendee answered no. So a tool nobody could reach read as sorted
# in the summary, and a PATH that was never the problem got the blame.
function Resolve-BinDirTool ($Name, $Label, $Exe, [string[]]$VersionArgs) {
    $dir = Split-Path $Exe -Parent
    # Run it before saying anything about the PATH. On a managed laptop the file
    # can be there and refuse to start, and that has no PATH fix.
    if (-not (Test-Runs $Exe $VersionArgs)) {
        Write-Blocked $Name $Exe
        Add-Fail $Label 'found but will not run' `
                 "Get $Name allowed by your endpoint policy -- ask in #cybr-japac-ts-all"
        return
    }
    Write-Good "$Name runs from $Exe"
    if (Test-InUserPath $dir) {
        # The saved PATH is right, so this is only a stale window. Fix the window
        # rather than send the attendee off to open a new one and find out: the
        # old code printed 'OK', left '$Name' still not a command in the window
        # they were looking at, and read as a script that lies.
        Add-SessionPath $dir
        # Whoever wrote $dir into the user PATH may have been an installer that
        # never broadcast the change. Then explorer.exe is still handing out its
        # sign-in copy of the environment, and a NEW window is stale too. One
        # broadcast here rules that out.
        Publish-EnvChange
        if (Have-Command $Name) {
            Write-Good "$Name is on your PATH, in this window and in new ones"
            Add-Pass $Label 'runs'
            return
        }
        Write-Info "$dir is in your user PATH, so only this window is out of date."
        Write-Info 'Open a NEW PowerShell window, then check it:'
        Write-Cmd "$Name $($VersionArgs -join ' ')"
        Add-Manual $Label 'installed -- open a new PowerShell window'
        return
    }
    Write-Warn "$dir is not in your user PATH, so no new window will find $Name"
    if (Confirm-Action "Add $dir to your user PATH?") {
        Add-UserPath $dir | Out-Null
        Write-Good "added $dir to your user PATH"
        # Add-UserPath patched this window too, so the bare command should work
        # here and now. Say so, and only fall back to 'open a new window' when it
        # does not.
        if (Have-Command $Name) {
            Write-Good "$Name is on your PATH, in this window and in new ones"
            Add-Fixed $Label 'PATH fixed'
        } else {
            Write-Info 'Open a NEW PowerShell window, then check it:'
            Write-Cmd "$Name $($VersionArgs -join ' ')"
            Write-Dim 'Not found there either? Close every PowerShell window and open one again.'
            Add-Fixed $Label 'PATH fixed (new window needed)'
        }
    } else {
        Add-Fail $Label 'installed, not on PATH' "Add $dir to your user PATH"
    }
}

Write-Host ''
Write-Host 'SKO27 TechSummit - AI Workshop for Idira DC' -ForegroundColor White
Write-Host '   Setup checker | Windows | nothing here needs admin rights' -ForegroundColor DarkGray
Write-Host ''
Write-Host "   Project folder : $Project"

# ------------------------------------------------------- 1 - workshop folder

Write-Step '1.' 'The workshop folder'

$missing = @('lab', 'sandbox-app', 'ai-harness-app', 'skills') |
    Where-Object { -not (Test-Path (Join-Path $Project $_)) }

if ($missing.Count -eq 0) {
    Write-Good 'lab, sandbox-app, ai-harness-app and skills are all here'
    Add-Pass 'Workshop folder' 'complete'
} else {
    Write-Bad ("missing: " + ($missing -join ', '))
    Write-Info 'Run this script from inside the workshop folder -- the one linked in'
    Write-Info '#cybr-japac-ts-all. Nothing else here will work without it.'
    Add-Fail 'Workshop folder' ("missing " + ($missing -join ', ')) `
             'Re-download the workshop folder and run this script from inside it'
}

# git reports and never gates.  Every lesson in Part 1 and nearly all of Part 2
# runs without it, so a missing git is a [CHECK] rather than a [FAIL].  Two things
# do need it, and both have a lead time: update.ps1 cannot run at all without it,
# and Lesson 08's /security-review reads this folder's history.  Before this
# check existed git was used here silently, so an attendee with no git got no
# version line, no summary row and no explanation of either.
$HasGit = $false
if (-not (Have-Command 'git')) {
    Write-Warn 'git is not installed'
    Write-Info 'Nothing in Part 1 needs it. Two later things do: .\update.ps1, which'
    Write-Info "the trainer asks the room to run on the day, and Lesson 08, which"
    Write-Info 'reads this folder history. Install it from:'
    Write-Info '   https://git-scm.com/download/win'
    Write-Info 'Take every default. It installs for you only and needs no admin rights.'
    Write-Info 'Then open a NEW PowerShell window and run this script again.'
    Add-Manual 'git' 'not installed -- install from https://git-scm.com/download/win, then re-run this script'
} elseif (-not (Test-Runs 'git' @('--version'))) {
    Write-Blocked 'git'
    Add-Manual 'git' 'on PATH but will not run -- ask in #cybr-japac-ts-all TODAY'
} else {
    $HasGit = $true
    $gitVer = (& git --version 2>$null | Select-Object -First 1)
    Write-Good $(if ($gitVer) { $gitVer } else { 'git runs' })
}

# Is the copy current?  The guide changes after people download it, so a version
# that was right last week can be wrong today.  This only reports; update.ps1 is
# what applies an update, and it is the trainer who calls for one on the day.
# Anything unusual here is left to update.ps1 to explain rather than duplicated.
if ($HasGit) {
    & git -C $Project rev-parse --git-dir *> $null
    if ($LASTEXITCODE -eq 0) {
        # Before the fetch, or the fetch is the thing that opens the sign-in window.
        Repair-PackagedGit

        $localVer = (& git -C $Project describe --tags --always 2>$null | Select-Object -First 1)
        if (-not $localVer) { $localVer = 'unknown' }

        if (Invoke-GitAnon 'fetch' '--tags' '--quiet' 'origin' '+refs/heads/main:refs/remotes/origin/main') {
            $behind = [int]((& git -C $Project rev-list --count HEAD..origin/main 2>$null |
                             Select-Object -First 1))
            if ($behind -eq 0) {
                Write-Good "version $localVer, which is the current one"
                Add-Pass 'Workshop version' "$localVer, current"
            } else {
                Write-Warn "version $localVer -- $behind change(s) behind. One command fixes it:"
                Write-Cmd '.\update.ps1'
                Add-Manual 'Workshop version' "$behind behind -- run: .\update.ps1"
            }
        } else {
            Write-Dim "version $localVer -- could not reach GitHub to check for a newer one"
        }
    } else {
        # No .git here.  This is what a plain "Source code (zip)" download gives
        # you, rather than the workshop package.  update.ps1 offers to repair it,
        # so this only names the problem and points there.
        Write-Warn 'this folder has no version history, so its version is unknown'
        Write-Info 'Lesson 08 reads that history, and .\update.ps1 needs it to update you.'
        Write-Info 'One command offers to repair it:'
        Write-Cmd '.\update.ps1'
        Add-Manual 'Workshop version' 'no history in this folder -- run: .\update.ps1'
    }
}

# --------------------------------------------------------------- 2 - python

Write-Step '2.' 'Python 3.9 or newer'

$Py = $null
foreach ($cand in @('python', 'py', 'python3')) {
    if (-not (Have-Command $cand)) { continue }
    # A bare `python` on Windows is often the Microsoft Store stub, which exits
    # non-zero and prints nothing useful. Checking the version filters it out.
    #
    # No double quote anywhere in that -c argument, on purpose. See the note on
    # quoting at the top of this file: a double quote here silently breaks the
    # check on Windows PowerShell 5.1, and this line decides whether the whole
    # script believes Python exists.
    $ver = & $cand -c 'import platform; print(platform.python_version())' 2>$null
    if ($LASTEXITCODE -eq 0 -and $ver -match '^(\d+)\.(\d+)') {
        if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 9)) {
            $Py = $cand
            $PyVer = $ver.Trim()
            break
        }
    }
}

if ($Py) {
    Write-Good "$Py is Python $PyVer"
    Add-Pass 'Python' "$Py $PyVer"
    if ($Py -ne 'python') {
        Write-Warn "'python' is not a working command here, only '$Py'"
        Write-Dim  "That is fine: once the virtual environment is on, plain 'python' works."
    }
} else {
    Write-Bad 'no Python 3.9+ found'
    Write-Info 'Install it from the official page:'
    Write-Info '   https://www.python.org/downloads/windows/'
    Write-Info 'Take the latest "Windows installer (64-bit)". Two choices in it matter:'
    Write-Info '  - tick "Add python.exe to PATH" on the first screen'
    Write-Info '  - leave "Install for all users" unticked, because that one needs admin'
    Write-Info 'Then open a NEW PowerShell window and run this script again.'
    Write-Dim 'Stopped by your endpoint policy? That is not a setup problem and you'
    Write-Dim 'cannot fix it from your seat. Ask in #cybr-japac-ts-all TODAY.'
    Add-Fail 'Python' 'not found' 'Install Python from https://www.python.org/downloads/windows/ (tick "Add python.exe to PATH"), open a new window, then re-run this script'
}

# ------------------------------------------------- 3 - virtual environment

Write-Step '3.' 'A virtual environment in this folder'

if (Test-Path $VPy) {
    $v = & $VPy -c 'import platform; print(platform.python_version())' 2>$null
    Write-Good ".venv exists (Python $v)"
    Add-Pass 'Virtual environment' '.venv ready'
} elseif (-not $Py) {
    Write-Bad 'cannot create one without Python'
    Add-Fail 'Virtual environment' 'blocked by Python' 'Fix Python first, then re-run this script'
} else {
    Write-Bad 'no .venv folder here'
    Write-Dim 'A virtual environment is a private folder of Python libraries for this'
    Write-Dim 'project only. Nothing system-wide, no admin rights, delete-to-clean-up.'
    if (Confirm-Action "Create it now? (writes $Venv)") {
        Write-Cmd "$Py -m venv .venv"
        & $Py -m venv $Venv
        if (Test-Path $VPy) {
            Write-Good 'created'
            Add-Fixed 'Virtual environment' 'created .venv'
        } else {
            Write-Bad 'creating it failed'
            Add-Fail 'Virtual environment' 'creation failed' 'Raise this in #cybr-japac-ts-all'
        }
    } else {
        Add-Fail 'Virtual environment' 'not created' "Run: $Py -m venv .venv"
    }
}

# --------------------------------------------------------- 4 - dependencies

Write-Step '4.' 'The libraries the workshop needs'

function Test-Import ($Module) {
    if (-not (Test-Path $VPy)) { return $false }
    & $VPy -c "import $Module" 2>$null
    return ($LASTEXITCODE -eq 0)
}

# The HTTPS transport, tested by building the real client instead of by importing a
# package name. The name is a moving target: anthropic 0.x imports httpx, anthropic
# 1.x imports httpx2, and each rejects the other's client. config.py is the thing
# that knows which, so ask it. Lessons 01-03 reach Llama through boto3, so a broken
# transport stays invisible until lesson 04 -- which is why it is tested here.
function Test-Transport {  # -> $true if config.py can build an HTTPS client
    if (-not (Test-Path $VPy)) { return $false }
    $harness = Join-Path $Project 'ai-harness-app'
    if (-not (Test-Path $harness)) { return $false }
    Push-Location $harness
    try {
        & $VPy -c 'import config; config.insecure_http_client()' 2>$null
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

# Every library can be installed and Part 1 still not start. The lesson modules
# are Python source too, and an interpreter that is too old for their syntax
# parses them and then refuses to run them. That shows up as one error message
# on the first lesson, in the room. So import what the lessons import.
# Library modules only: importing 01_bare_call.py would fire a real model call.
function Test-Part1 {  # -> $true if Part 1 will start.  Records its own [FAIL] row if not.
    # Guarded: a folder checked out without ai-harness-app would make Push-Location
    # throw, and the Pop-Location in the finally would then unwind the wrong folder.
    $harness = Join-Path $Project 'ai-harness-app'
    if (-not (Test-Path $harness)) {
        Write-Bad 'the ai-harness-app folder is missing, so Part 1 cannot be tested'
        Add-Fail 'Libraries' 'ai-harness-app missing' 'Re-download the workshop folder and run this script from inside it'
        return $false
    }
    Push-Location $harness
    try {
        $out = & $VPy -c 'import ui, tools, session, agent, harness' 2>&1
        $ok = ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
    if ($ok) {
        Write-Good 'the Part 1 lesson code imports cleanly'
        return $true
    }
    $ver = & $VPy -c 'import platform; print(platform.python_version())' 2>$null
    Write-Bad 'the libraries are installed, but the Part 1 lesson code will not import'
    if ($out) { Write-Dim ([string](@($out)[-1])) }
    Write-Dim "this .venv runs Python $ver"
    Add-Fail 'Libraries' 'Part 1 will not import' 'Delete .venv, create it again with a newer Python (see the Setup page), then re-run this script'
    return $false
}

if (-not (Test-Path $VPy)) {
    Write-Bad 'skipped -- no virtual environment yet'
    Add-Fail 'Libraries' 'blocked by .venv' 'Create the virtual environment, then re-run this script'
} else {
    $need = @()
    if (-not (Test-Import 'boto3')) { $need += 'sandbox-app\requirements.txt' }
    # rich powers ui.py, which every lesson imports. Without checking it, a failed
    # rich install reports PASS here and then crashes on import in the room. Both
    # live in the same requirements file, so test them together and list it once.
    if (-not (Test-Import 'anthropic') -or -not (Test-Import 'rich') -or -not (Test-Transport)) {
        $need += 'ai-harness-app\requirements.txt'
    }

    if ($need.Count -eq 0) {
        Write-Good 'boto3 is ready (the sandbox app)'
        Write-Good 'anthropic is ready (the harness lessons in Part 1)'
        Write-Good 'the HTTPS transport builds (needed from lesson 04 on)'
        Write-Good 'rich is ready (the terminal UI)'
        if (Test-Part1) {
            Add-Pass 'Libraries' 'boto3 + anthropic + rich + transport'
        }
    } else {
        Write-Bad ("missing libraries from: " + ($need -join ', '))
        if (Confirm-Action 'Install them into .venv now? (needs internet, ~1 minute)') {
            & $VPy -m pip install --quiet --upgrade pip 2>$null | Out-Null
            foreach ($req in $need) {
                Write-Cmd "python -m pip install -r $req"
                & $VPy -m pip install --quiet -r (Join-Path $Project $req)
            }
            if ((Test-Import 'boto3') -and (Test-Import 'anthropic') -and (Test-Import 'rich') -and (Test-Transport)) {
                Write-Good 'boto3, anthropic and rich import cleanly, and the transport builds'
                if (Test-Part1) {
                    Add-Fixed 'Libraries' 'installed'
                }
            } else {
                Write-Bad 'the install did not finish cleanly'
                Add-Fail 'Libraries' 'install failed' 'Re-run: .venv\Scripts\python.exe -m pip install -r ai-harness-app\requirements.txt -r sandbox-app\requirements.txt'
            }
        } else {
            Add-Fail 'Libraries' 'not installed' "Run: .venv\Scripts\python.exe -m pip install -r $($need[0])"
        }
    }
}

# --------------------------------------------------------- 5 - claude code

Write-Step '5.' 'Claude Code'

# The installer puts claude.exe in $HOME\.local\bin and adds that folder to the
# user PATH.  A PATH change only reaches windows opened after it, so in the window
# that ran the installer 'claude' is still not a command.  Checking the PATH alone
# reads that as "not installed" and offers to install it again, which is a loop:
# the installer succeeds every time and the check fails every time.  So the known
# locations are looked at before giving up.
function Find-ClaudeExe {
    $candidates = @(
        (Join-Path $HOME '.local\bin\claude.exe'),   # the official installer
        (Join-Path $BinDir 'claude.exe')             # next to idsec, if put there by hand
    )
    # npm -g leaves a .cmd shim rather than an .exe.  $env:APPDATA is checked
    # first because Join-Path throws on a null second argument.
    if ($env:APPDATA) { $candidates += (Join-Path $env:APPDATA 'npm\claude.cmd') }
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

# Reports what happened to a claude found outside the PATH, and fixes the PATH
# when that is what is missing.  Called after an install too, so a fresh install
# gets the same accurate message.
function Resolve-ClaudeOffPath ($Exe) {
    $dir = Split-Path $Exe -Parent
    if (Test-InUserPath $dir) {
        # The saved PATH needs nothing: a new window will find it. Saying "not
        # installed" here, or offering to edit a PATH that is already correct, is
        # the bug. This window is still stale though, so patch it, and broadcast
        # in case the installer that wrote the PATH never did.
        Write-Good "Claude Code is installed at $Exe"
        Add-SessionPath $dir
        Publish-EnvChange
        if (Have-Command 'claude') {
            Write-Good 'claude is on your PATH, in this window and in new ones'
            Add-Pass 'Claude Code' 'runs'
            return
        }
        Write-Info "$dir is in your user PATH, so only this window is out of date."
        Write-Info 'Open a NEW PowerShell window, then check it:'
        Write-Cmd 'claude --version'
        Add-Manual 'Claude Code' 'installed -- open a new PowerShell window'
        return
    }
    Write-Warn "Claude Code is at $Exe but $dir is not on your PATH"
    if (Confirm-Action "Add $dir to your user PATH?") {
        Add-UserPath $dir | Out-Null
        Write-Good "added $dir to your user PATH"
        if (Have-Command 'claude') {
            Write-Good 'claude is on your PATH, in this window and in new ones'
            Add-Fixed 'Claude Code' 'PATH fixed'
        } else {
            Write-Info 'Open a NEW PowerShell window, then check it:'
            Write-Cmd 'claude --version'
            Add-Fixed 'Claude Code' 'PATH fixed (new window needed)'
        }
    } else {
        Add-Fail 'Claude Code' 'installed, not on PATH' "Add $dir to your user PATH"
    }
}

$ClaudeExe = Find-ClaudeExe

# Set by every branch below that ends with a Claude Code able to start. The auto
# mode block after this step reads it: a setting for a program that will not run
# is noise on a report that is already failing.
$ClaudeUsable = $false

if ((Have-Command 'claude') -and (Test-Runs 'claude' @('--version'))) {
    $cv = (& claude --version 2>$null | Select-Object -First 1)
    Write-Good "claude $cv"
    Add-Pass 'Claude Code' 'runs'
    $ClaudeUsable = $true
} elseif (Have-Command 'claude') {
    Write-Blocked 'claude'
    Add-Fail 'Claude Code' 'found but will not run' `
             'Get Claude Code allowed by your endpoint policy -- ask in #cybr-japac-ts-all'
} elseif ($ClaudeExe -and (Test-Runs $ClaudeExe @('--version'))) {
    Resolve-ClaudeOffPath $ClaudeExe
    $ClaudeUsable = $true
} elseif ($ClaudeExe) {
    # The file is there and will not start, which is application control rather
    # than a PATH problem. Installing it again cannot help.
    Write-Blocked 'claude' $ClaudeExe
    Add-Fail 'Claude Code' 'found but will not run' `
             'Get Claude Code allowed by your endpoint policy -- ask in #cybr-japac-ts-all'
} else {
    Write-Bad "the 'claude' command was not found"
    Write-Dim 'It installs into your home folder. No admin rights, no Node.js.'
    if (Confirm-Action 'Install Claude Code now? (runs the official installer)') {
        Write-Cmd 'irm https://claude.ai/install.ps1 | iex'
        try {
            Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
            # The installer edits the PATH, which this window will not see, so the
            # file is looked for directly rather than trusted to be a command now.
            $ClaudeExe = Find-ClaudeExe
            if ($ClaudeExe) {
                Resolve-ClaudeOffPath $ClaudeExe
            } else {
                Write-Good 'installed -- open a NEW PowerShell window, then run: claude --version'
                Add-Fixed 'Claude Code' 'installed (new window needed)'
            }
            $ClaudeUsable = $true
        } catch {
            Write-Bad "the installer failed: $($_.Exception.Message)"
            Add-Fail 'Claude Code' 'install failed' 'Try again on a network without a proxy, or ask in #cybr-japac-ts-all'
        }
    } else {
        Add-Fail 'Claude Code' 'not installed' 'Run: irm https://claude.ai/install.ps1 | iex'
    }
}

# ------------------------------------------------ 5 - auto mode, by default
#
# Every lesson from 08 onward opens with "press Shift+Tab until the bottom line
# says auto", and a room that misses those presses is stopped at an approval
# prompt.  Setting it here means the agent starts in auto mode on its own.
#
# It has to be the user settings file.  A defaultMode in a project's
# .claude\settings.json is ignored on purpose, because a repo may not grant itself
# auto mode: only policy, user and CLI-flag sources may.  So a copy of this
# setting shipped inside the workshop folder would do nothing.  The user file is
# also the only scope that covers Lesson 11, which starts the agent in
# $HOME\my-first-app, outside the workshop folder entirely.
$ClaudeSettings = Join-Path $HOME '.claude\settings.json'

# Python does the edit, not PowerShell.  Windows PowerShell 5.1 has two traps
# here and both silently damage a real settings file: ConvertTo-Json defaults to
# -Depth 2, which flattens nested keys such as permissions.allow or env into
# strings, and Set-Content -Encoding utf8 writes a byte order mark that Claude
# Code will not read back.  Python has neither problem, and step 2 already
# checked that it is here.
#
# Written to a temp file rather than passed with -c, for the reason at the top of
# this file: 5.1 mangles quotes and newlines inside an argument to a native
# program.
#
#   check -> auto | bypass | unset | other:<value> | unreadable
#   set   -> set, having merged permissions.defaultMode=auto into the file,
#            keeping every other key, after taking one backup
function Invoke-ClaudeSettings ($PyExe, $Action) {
    $helper = Join-Path ([IO.Path]::GetTempPath()) 'idira-claude-settings.py'
    @'
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
'@ | Set-Content -LiteralPath $helper -Encoding utf8

    $out = (& $PyExe $helper $ClaudeSettings $Action 2>$null | Select-Object -Last 1)
    Remove-Item -LiteralPath $helper -ErrorAction SilentlyContinue
    if ($out) { return "$out".Trim() }
    return ''
}

if ($ClaudeUsable) {
    $SetPy = if ($Py) { $Py } elseif (Test-Path $VPy) { $VPy } else { $null }

    if (-not $SetPy) {
        Write-Warn "cannot read $ClaudeSettings without Python"
        Write-Dim  'Nothing is lost: in the agent, press Shift+Tab until the line says auto.'
        Add-Manual 'Claude auto mode' 'not set -- use Shift+Tab'
    } else {
        $mode = Invoke-ClaudeSettings $SetPy 'check'
        if ($mode -eq 'auto') {
            Write-Good 'auto mode is already the default'
            Add-Pass 'Claude auto mode' 'already on'
        } elseif ($mode -eq 'bypass') {
            Write-Warn 'your settings ask for bypassPermissions, which is wider than auto mode'
            Write-Dim  'Left exactly as it is. Narrowing it here would change how the agent'
            Write-Dim  'behaves in every folder you own, and the lessons run either way.'
            Add-Manual 'Claude auto mode' 'bypassPermissions left alone'
        } elseif ($mode -eq 'unreadable') {
            Write-Warn "$ClaudeSettings is there, but this script cannot read it as JSON"
            Write-Dim  'Left alone rather than risk your file. In the agent, press Shift+Tab'
            Write-Dim  'until the bottom line says auto.'
            Add-Manual 'Claude auto mode' 'settings file not readable'
        } elseif ($mode -eq 'unset' -or $mode -like 'other:*') {
            Write-Info 'The lessons assume auto mode, where the agent runs commands without'
            Write-Info 'asking you first. It can be set once, here, instead of by hand at the'
            Write-Info 'start of every lesson.'
            Write-Warn 'This applies to every folder on this laptop, not only the workshop one.'
            if (Confirm-Action "Set Claude Code to auto mode by default? (edits $ClaudeSettings)") {
                if ((Invoke-ClaudeSettings $SetPy 'set') -eq 'set') {
                    Write-Good 'auto mode is now the default'
                    Write-Info 'It stays that way after the workshop. To undo it, remove the'
                    Write-Info "defaultMode line from $ClaudeSettings"
                    Write-Info "or copy $ClaudeSettings.sko27-backup back over it."
                    Add-Fixed 'Claude auto mode' 'on by default'
                } else {
                    Write-Bad "writing $ClaudeSettings failed"
                    Write-Dim 'In the agent, press Shift+Tab until the bottom line says auto.'
                    Add-Manual 'Claude auto mode' 'not set -- use Shift+Tab'
                }
            } else {
                Write-Info 'Left alone. In the agent, press Shift+Tab until the bottom line'
                Write-Info 'says auto. Every lesson from 08 onward needs it.'
                Add-Manual 'Claude auto mode' 'not set -- use Shift+Tab'
            }
        } else {
            Write-Warn "could not read the permission mode out of $ClaudeSettings"
            Write-Dim  'In the agent, press Shift+Tab until the bottom line says auto.'
            Add-Manual 'Claude auto mode' 'not set -- use Shift+Tab'
        }
    }
}

# ---------------------------------------------------------- 6 - idsec and jq

Write-Step '6.' 'The idsec CLI and jq'

function Get-IdsecUrl {
    # Newest release, the asset for 64-bit Windows.
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/cyberark/idsec-cli-golang/releases/latest' `
                                 -Headers @{ 'User-Agent' = 'idira-workshop-setup' }
    } catch { return $null }
    $asset = $rel.assets |
        Where-Object { $_.name -match 'windows' -and $_.name -match 'amd64|x86_64|x64' } |
        Where-Object { $_.name -match '\.(zip|tar\.gz|tgz)$' } |
        Select-Object -First 1
    if ($asset) { return $asset.browser_download_url }
    return $null
}

$idsecExe = Join-Path $BinDir 'idsec.exe'

if ((Have-Command 'idsec') -and (Test-Runs 'idsec' @('version'))) {
    $iv = (& idsec version 2>$null | Select-Object -First 1)
    Write-Good "idsec $iv"
    Add-Pass 'idsec CLI' 'runs'
} elseif (Have-Command 'idsec') {
    Write-Blocked 'idsec'
    Add-Fail 'idsec CLI' 'found but will not run' `
             'Get idsec allowed by your endpoint policy -- ask in #cybr-japac-ts-all'
} elseif (Test-Path $idsecExe) {
    Resolve-BinDirTool 'idsec' 'idsec CLI' $idsecExe @('version')
} else {
    Write-Bad "the 'idsec' command was not found"
    Write-Dim 'It is a single file -- no installer, nothing registered with Windows.'
    if (Confirm-Action "Download the latest idsec into $BinDir and set it up?") {
        $url = Get-IdsecUrl
        if (-not $url) {
            Write-Bad 'could not work out which release file to download'
            Write-Info 'Do it by hand -- the lab page walks you through it:'
            Write-Info 'https://github.com/cyberark/idsec-cli-golang/releases'
            Add-Fail 'idsec CLI' 'auto-download failed' 'Install idsec by hand -- see setup step 5 in the lab guide'
        } else {
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("idsec-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force -Path $tmp, $BinDir | Out-Null
            $file = Join-Path $tmp (Split-Path $url -Leaf)
            Write-Cmd "download $url"
            $installed = $false
            try {
                Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
                if ($file -match '\.zip$') {
                    Expand-Archive -Path $file -DestinationPath $tmp -Force
                } else {
                    & tar -xzf $file -C $tmp
                }
                # The archive names the binary after its platform -- on Windows
                # that is idsec-windows.exe -- and ships a LICENSE.txt and a
                # README.md beside it. Match the prefix rather than an exact
                # name, so a release that renames again still installs. It
                # becomes plain idsec.exe on the Copy-Item below.
                $found = Get-ChildItem -Path $tmp -Recurse -Filter 'idsec*.exe' |
                         Select-Object -First 1
                if ($found) {
                    Copy-Item $found.FullName $idsecExe -Force
                    # Windows marks anything downloaded as untrusted; clear it so
                    # the binary is not blocked on first run.
                    Unblock-File $idsecExe -ErrorAction SilentlyContinue
                    Write-Good "installed to $idsecExe"
                    $installed = $true
                } else {
                    Write-Bad 'downloaded the archive, but found no idsec binary inside it'
                    Add-Fail 'idsec CLI' 'unexpected archive' 'Install idsec by hand -- see setup step 5 in the lab guide'
                }
            } catch {
                Write-Bad "the download failed: $($_.Exception.Message)"
                Add-Fail 'idsec CLI' 'download failed' 'Install idsec by hand -- see setup step 5 in the lab guide'
            } finally {
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
            # Outside the try on purpose. This asks a question and edits the PATH,
            # and anything going wrong in there is not a failed download.
            # A file arriving is not the same as a command working, so the fresh
            # install gets the same three-way check as one that was already there:
            # it runs and the PATH is fine, it runs and the PATH needs the folder,
            # or it will not start at all.
            if ($installed) {
                Resolve-BinDirTool 'idsec' 'idsec CLI' $idsecExe @('version')
            }
        }
    } else {
        Add-Fail 'idsec CLI' 'not installed' 'Install idsec -- see setup step 5 in the lab guide'
    }
}

# jq comes next, in the same step, because the two are used together: idsec
# returns the AWS credentials as JSON and jq is what lifts them out of it. Also a
# single .exe, published as a plain binary rather than an archive, so there is
# nothing to unpack.

$jqExe = Join-Path $BinDir 'jq.exe'
$jqUrl = 'https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe'

if ((Have-Command 'jq') -and (Test-Runs 'jq' @('--version'))) {
    $jv = (& jq --version 2>$null | Select-Object -First 1)
    Write-Good "jq $jv"
    Add-Pass 'jq' 'runs'
} elseif (Have-Command 'jq') {
    Write-Blocked 'jq'
    Add-Fail 'jq' 'found but will not run' `
             'Get jq allowed by your endpoint policy -- ask in #cybr-japac-ts-all'
} elseif (Test-Path $jqExe) {
    Resolve-BinDirTool 'jq' 'jq' $jqExe @('--version')
} else {
    Write-Bad "the 'jq' command was not found"
    Write-Dim "Also a single file. It reads your AWS credentials out of Idira's answer."
    if (Confirm-Action "Download jq into $BinDir and set it up?") {
        New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
        Write-Cmd "download $jqUrl"
        $installed = $false
        try {
            Invoke-WebRequest -Uri $jqUrl -OutFile $jqExe -UseBasicParsing
            Unblock-File $jqExe -ErrorAction SilentlyContinue
            Write-Good "installed to $jqExe"
            $installed = $true
        } catch {
            Remove-Item $jqExe -Force -ErrorAction SilentlyContinue
            Write-Bad "the download failed: $($_.Exception.Message)"
            Add-Fail 'jq' 'download failed' 'Install jq by hand -- see setup step 5 in the lab guide'
        }
        # Outside the try, or the catch above deletes a jq that downloaded
        # perfectly well the moment anything in the PATH question goes wrong.
        if ($installed) { Resolve-BinDirTool 'jq' 'jq' $jqExe @('--version') }
    } else {
        Add-Fail 'jq' 'not installed' 'Install jq -- see setup step 5 in the lab guide'
    }
}

# ------------------------------------------------------- 7 - idsec profile

Write-Step '7.' 'An idsec profile, and a login that works'

# Pin both folders before anything looks for a profile or a token, because until
# they are pinned the answer depends on which folder the attendee happens to be in.
# The mechanism is in the comment above Set-IdsecFolderVar.
#
# The getter expands %USERPROFILE% for us, so a saved value can go straight into
# this window. A window that opened before the pin is the same stale-window case
# Add-SessionPath exists for.
foreach ($v in @($IdsecProfilesVar, $IdsecKeyringVar)) {
    if (-not [Environment]::GetEnvironmentVariable($v, 'Process')) {
        $saved = [string][Environment]::GetEnvironmentVariable($v, 'User')
        if ($saved.Trim()) { [Environment]::SetEnvironmentVariable($v, $saved, 'Process') }
    }
}

# Checked separately, because an attendee who ran an earlier version of this script
# has the profiles variable pinned and the keyring one still missing. The @() is the
# same load-bearing one as on $Profiles below: a one-element result from
# Where-Object arrives as a bare hashtable, and .Count on it means nothing.
$UnpinnedVars = @(
    @(
        @{ Name = $IdsecProfilesVar; Template = $IdsecProfilesTmpl; Folder = $IdsecProfilesFolder }
        @{ Name = $IdsecKeyringVar;  Template = $IdsecKeyringTmpl;  Folder = $IdsecKeyringFolder  }
    ) | Where-Object { -not [Environment]::GetEnvironmentVariable($_.Name, 'Process') }
)

if (-not $UnpinnedVars) {
    Write-Good "profiles folder is pinned: $env:IDSEC_PROFILES_FOLDER"
    Write-Good "token folder is pinned:    $env:IDSEC_KEYRING_FOLDER"
    Add-Pass 'idsec folders' 'pinned, so the current folder does not matter'
} else {
    Write-Warn 'where idsec keeps its profile and your login depends on where you run it'
    Write-Dim 'PowerShell sets no HOME variable, so idsec falls back to paths relative to'
    Write-Dim 'the current folder. A profile and a login made here are then invisible from'
    Write-Dim 'sandbox-app, which is where lesson 09 works. The agent there sees no profile,'
    Write-Dim 'or sees one and is told your login expired, and can list no targets at all.'
    # Named rather than counted, because the returning attendee has one of the two
    # pinned already and 'pin both' would be a lie to them.
    if (Confirm-Action "Pin $(($UnpinnedVars.Name) -join ' and ') under $(Join-Path $IdsecHome '.idsec')?") {
        foreach ($v in $UnpinnedVars) {
            Set-IdsecFolderVar $v.Name $v.Template $v.Folder | Out-Null
            [Environment]::SetEnvironmentVariable($v.Name, $v.Folder, 'Process')
            Write-Good "$($v.Name) is set, in this window and in new ones"
        }
        Add-Fixed 'idsec folders' 'pinned, so the current folder does not matter'
    } else {
        Add-Fail 'idsec folders' 'not pinned' `
                 "Set $(($UnpinnedVars.Name) -join ' and ') under $(Join-Path $IdsecHome '.idsec') -- without them lesson 09 fails inside sandbox-app"
    }
}

# A profile made before the pin is in the folder configure ran from, which for
# anyone who used this script is this one. Moving it beats asking for the three
# tenant values again, and the lab guide tells attendees never to re-run configure.
if ($env:IDSEC_PROFILES_FOLDER -and
    -not (Test-Path (Join-Path $env:IDSEC_PROFILES_FOLDER 'idsec'))) {
    $StrayProfiles = Join-Path $Project '.idsec\profiles'
    if (Test-Path (Join-Path $StrayProfiles 'idsec')) {
        Write-Warn 'your profile is in the workshop folder, so only commands run from here can see it'
        if (Confirm-Action 'Move it to the pinned folder?') {
            if (Move-IdsecProfile $StrayProfiles) {
                Add-Fixed 'idsec profile location' 'moved out of the workshop folder'
            }
        } else {
            Add-Fail 'idsec profile location' 'in the workshop folder' `
                     "Move $StrayProfiles\idsec into $IdsecProfilesFolder"
        }
    }
}

# Same for the cached login. Moving it keeps a login the attendee already did, and
# it takes a token out of a folder it has no business being in. If it stays there,
# the login below writes a fresh one to the pinned folder anyway, so this is a
# convenience, not a repair.
if ($env:IDSEC_KEYRING_FOLDER -and
    -not (Test-Path (Join-Path $env:IDSEC_KEYRING_FOLDER 'keyring'))) {
    $StrayKeyring = Join-Path $Project '.idsec\cache\keyring'
    if (Test-Path (Join-Path $StrayKeyring 'keyring')) {
        Write-Warn 'your cached login is in the workshop folder, where nothing else can find it'
        if (Confirm-Action 'Move it to the pinned folder, so you do not log in twice?') {
            if (Move-IdsecKeyring $StrayKeyring) {
                Add-Fixed 'idsec token cache' 'moved out of the workshop folder'
            }
        } else {
            Add-Manual 'idsec token cache' "in the workshop folder -- log in again to write one to $IdsecKeyringFolder"
        }
    }
}

$Idsec = $null
if ((Have-Command 'idsec') -and (Test-Runs 'idsec' @('version'))) {
    $Idsec = 'idsec'
} elseif ((Test-Path $idsecExe) -and (Test-Runs $idsecExe @('version'))) {
    $Idsec = $idsecExe
}

function Show-CybrWorldValues {
    Write-Info "'idsec configure' asks a few questions. Three answers matter:"
    Write-Info '  Identity Tenant Subdomain  demo'
    Write-Info '  Identity URL               https://aam4614.my.idaptive.app/'
    Write-Info '  Username                   your own, ending in @cyberarklab.com'
    Write-Dim 'That is your own CYBRWorld account. Nobody issues you a workshop login.'
}

# Every command in the lab guide, on the cheat sheet and in this script is a bare
# 'idsec ...' with no --profile-name, so they all use the default profile, the one
# called 'idsec'. A profile called something else is invisible to all of them.
# Printed whenever the profiles on this laptop do not include 'idsec'.
function Show-DefaultProfileAdvice {
    Write-Info "The lab needs CYBRWorld on the DEFAULT profile, the one called 'idsec'."
    Write-Info 'Every command in the guide leaves --profile-name off, so it uses that one.'
    Write-Info ''
    Write-Info "Using 'idsec' for another tenant already? Keep it, under a name of its own:"
    Write-Cmd 'Copy-Item -Recurse $HOME\.idsec\profiles $HOME\idsec-profiles-backup'
    Write-Cmd 'idsec configure --profile-name <that-tenant>   # re-enter its values'
    Write-Cmd 'idsec configure                                # now CYBRWorld, as default'
    Write-Dim 'Your profiles are files in $HOME\.idsec\profiles. Copy the folder back'
    Write-Dim 'afterwards if you want your old default returned.'
}

# Which profiles exist. 'profiles list' first, because it is what this build
# actually believes: 0.8.0 answers with a JSON array of names, so the brackets,
# commas and quotes come off here rather than through jq, which may not be
# installed yet at this point in the script.
#
# The fallback is the profiles folder, a DIRECTORY holding one file per profile,
# named after the profile. Its dotfiles are bookkeeping, not profiles.
#
# It has to read IDSEC_PROFILES_FOLDER, not just $HOME\.idsec\profiles, or it looks
# somewhere the CLI does not: the pin above is what makes those two the same folder.
function Get-IdsecProfileNames {
    if (-not $Idsec) { return @() }
    $out = & $Idsec profiles list 2>$null
    if ($LASTEXITCODE -eq 0 -and ($out -join '').Trim()) {
        return @($out |
            ForEach-Object { ($_ -replace '[\[\]",]', '').Trim() } |
            Where-Object { $_ })
    }
    $dir = if ($env:IDSEC_PROFILES_FOLDER) { $env:IDSEC_PROFILES_FOLDER }
           else { Join-Path $HOME '.idsec\profiles' }
    if (Test-Path $dir) {
        return @(Get-ChildItem -File $dir |
            Where-Object { $_.Name -notlike '.*' } |
            ForEach-Object { $_.Name })
    }
    return @()
}

# Runs a real login, because a profile with one wrong answer in it looks perfect
# until the day.
function Invoke-IdsecLogin {
    Write-Cmd "$Idsec login"
    & $Idsec login
    if ($LASTEXITCODE -eq 0) {
        Write-Good 'logged in to CYBRWorld'
        return $true
    }
    Write-Bad 'the login did not succeed'
    Write-Info 'Check the three values, then fix whichever one is wrong:'
    Write-Cmd "$Idsec profiles show"
    Write-Cmd "$Idsec configure"
    Show-CybrWorldValues
    Write-Info ''
    Show-DefaultProfileAdvice
    Write-Info 'Still failing? Ask in the #cybr-japac-ts-all Slack channel.'
    Write-Info 'Do it this week, not on the day.'
    return $false
}

# The check that matters. Not "is anything configured?" but "is CYBRWorld on the
# profile the lab commands will actually use?" The old version accepted any
# profile, so an attendee with one named profile for another tenant was told
# everything was fine and then watched the login fail for no stated reason.
# The @() around the call is load-bearing, not decoration. A PowerShell function
# that returns an empty array hands the caller $null, because an empty array
# written to the output stream is nothing at all, and a one-element array arrives
# as a bare string. So without the @() this line produced $null for the attendee
# who had idsec working but no profiles yet, and $Profiles.Count below then died
# with "The property 'Count' cannot be found on this object".
$Profiles = @(Get-IdsecProfileNames)
$HasDefaultProfile = $false
if ($Idsec) {
    $HasDefaultProfile = [bool]($Profiles -contains 'idsec')
}

if (-not $Idsec) {
    Write-Bad 'skipped -- idsec does not run in this window yet'
    Add-Fail 'idsec login' 'blocked by idsec' 'Finish step 6, open a new PowerShell window, then re-run this script'
} elseif ($HasDefaultProfile) {
    Write-Good "the default profile, 'idsec', exists"
    if (Confirm-Action 'Log in now, to prove the profile actually works?') {
        if (Invoke-IdsecLogin) {
            Add-Pass 'idsec login' 'signed in to CYBRWorld'
        } else {
            Add-Fail 'idsec login' 'login failed' 'Fix your idsec profile: idsec configure -- then: idsec login'
        }
    } else {
        Add-Manual 'idsec login' 'run it by hand: idsec login'
    }
} elseif ($Profiles.Count -gt 0) {
    # The case this whole step exists for: profiles are configured, but none of
    # them is the one the lab commands use.
    Write-Bad "you have idsec profiles, but none of them is called 'idsec'"
    Write-Info ("Found: " + ($Profiles -join ' '))
    Write-Info ''
    Show-DefaultProfileAdvice
    Write-Info ''
    Show-CybrWorldValues
    if (Confirm-Action "Run 'idsec configure' now, to add CYBRWorld as the default profile?") {
        & $Idsec configure
        if ($LASTEXITCODE -eq 0) {
            Write-Good 'configured'
            if (Invoke-IdsecLogin) {
                Add-Fixed 'idsec login' 'CYBRWorld on the default profile, signed in'
            } else {
                Add-Fail 'idsec login' 'configured, login failed' 'Fix the values: idsec configure -- then: idsec login'
            }
        } else {
            Write-Bad 'configure did not complete'
            Add-Fail 'idsec login' 'no default profile' 'Run: idsec configure (CYBRWorld, as the default profile)'
        }
    } else {
        Add-Fail 'idsec login' 'no default profile' "Run: idsec configure -- CYBRWorld must be the default profile, 'idsec'"
    }
} else {
    Write-Bad 'no idsec profile found'
    Show-CybrWorldValues
    Write-Dim 'Leave --profile-name off when it asks. CYBRWorld belongs on the default'
    Write-Dim 'profile, because every command in the lab guide leaves it off too.'
    if (Confirm-Action "Run 'idsec configure' now? (it will ask you questions)") {
        & $Idsec configure
        if ($LASTEXITCODE -eq 0) {
            Write-Good 'configured'
            if (Invoke-IdsecLogin) {
                Add-Fixed 'idsec login' 'configured and signed in'
            } else {
                Add-Fail 'idsec login' 'configured, login failed' 'Fix the values: idsec configure -- then: idsec login'
            }
        } else {
            Write-Bad 'configure did not complete'
            Add-Fail 'idsec login' 'not configured' 'Run: idsec configure'
        }
    } else {
        Add-Fail 'idsec login' 'not configured' 'Run: idsec configure (once -- a second run overwrites it)'
    }
}

# ------------------------------------------------------------ 8 - AWS access

Write-Step '8.' 'Short-lived AWS credentials from idsec'

$AwsWorkspace = '409556437035'
$AwsRole      = 'arn:aws:iam::409556437035:role/CW-SCA-AdminAccess'

$Jq = $null
if ((Have-Command 'jq') -and (Test-Runs 'jq' @('--version'))) {
    $Jq = 'jq'
} elseif ((Test-Path $jqExe) -and (Test-Runs $jqExe @('--version'))) {
    $Jq = $jqExe
}

# An elevate call can sit waiting on an approval, so it gets a time limit. Output
# is read in memory rather than redirected to a file, because on this step that
# output holds credentials. Returns $null if the time ran out.
function Invoke-WithTimeout ($Exe, [string[]]$Arguments, [int]$Seconds) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $Exe
    $psi.Arguments              = ($Arguments -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $proc   = [System.Diagnostics.Process]::Start($psi)
    # Both pipes are drained, not just stdout. A redirected pipe nobody reads holds
    # about 4 KB, and the child blocks for good once it is full. idsec writing a
    # progress line or a warning to stderr would then look like a timeout here, and
    # send the attendee off to chase an approval that was never pending.
    $stdout = $proc.StandardOutput.ReadToEndAsync()
    $stderr = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit($Seconds * 1000)) {
        try { $proc.Kill() } catch { }
        return $null
    }
    $stderr.Wait(5000) | Out-Null
    return $stdout.Result
}

# The whole path, run for real: ask Idira to elevate, then ask AWS who you are.
# The credentials live in this window's environment for a few seconds. Nothing is
# printed and nothing is written to a file, and they are cleared at the end.
function Invoke-AwsRehearsal {
    Write-Info 'asking Idira for credentials -- this can take a moment'
    $raw = Invoke-WithTimeout $Idsec @(
        'exec', 'sca', 'cloud-access', 'elevate', '--csp', 'aws',
        '--workspace-id', $AwsWorkspace, '--roleIds', $AwsRole, '--raw'
    ) 120
    if ($null -eq $raw) {
        Write-Bad 'the elevate call did not finish in two minutes'
        Write-Info 'It may be waiting on an approval. Run it by hand -- setup step 7.'
        Add-Manual 'AWS credentials' 'elevate timed out -- run it by hand, setup step 7'
        return
    }
    $filter = '.response.results[0].accessCredentials | fromjson | "$env:AWS_ACCESS_KEY_ID=\"\(.aws_access_key)\"\n$env:AWS_SECRET_ACCESS_KEY=\"\(.aws_secret_access_key)\"\n$env:AWS_SESSION_TOKEN=\"\(.aws_session_token)\""'
    $creds = ($raw | & $Jq -r $filter 2>$null) -join "`n"
    $raw = $null
    if (-not $creds.Trim()) {
        Write-Bad 'no credentials came back'
        Write-Info 'The role exists, so this is usually a policy on the role itself.'
        Write-Info 'Ask in #cybr-japac-ts-all today and paste in what you ran.'
        Add-Fail 'AWS credentials' 'elevate returned nothing' 'Ask in #cybr-japac-ts-all -- elevate gave no credentials'
        return
    }
    Write-Good 'credentials received'
    try {
        $creds | Invoke-Expression
        # verify=False for the same reason ai-harness-app/config.py sets it: a TLS-inspecting
        # proxy would otherwise fail this call and be reported as "AWS rejected them", which
        # sends the attendee after the wrong problem. Step 9 below is where TLS gets judged.
        # One physical line, and Python's single quotes rather than double, both on
        # purpose. See the note on quoting at the top of this file: a newline or a
        # double quote in a -c argument does not survive Windows PowerShell 5.1.
        # The outer PowerShell quotes have to be double here so the inner ones can
        # be single, which is safe only because there is no $ left to interpolate.
        $arn = & $VPy -c "import boto3, urllib3; urllib3.disable_warnings(); print(boto3.client('sts', verify=False).get_caller_identity()['Arn'])" 2>$null
        if ($arn) {
            Write-Good "AWS accepted them: $arn"
            Write-Dim 'They are gone now. This script never saved them anywhere.'
            Add-Pass 'AWS credentials' 'elevate and AWS both worked'
        } else {
            Write-Bad 'the credentials came back, but AWS did not accept them'
            Write-Info 'Do the two commands by hand -- setup step 7 explains every error.'
            Add-Fail 'AWS credentials' 'AWS rejected them' 'Run setup step 7 by hand, then ask in #cybr-japac-ts-all'
        }
    } finally {
        Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY, Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    }
}

if (-not $Idsec) {
    Write-Bad 'skipped -- idsec does not run in this window yet'
    Add-Fail 'AWS credentials' 'idsec unavailable' 'Finish step 6, open a new PowerShell window, then re-run this script'
} else {
    Write-Cmd "$Idsec exec sca cloud-access list-targets --csp aws"
    $targets = (& $Idsec exec sca cloud-access list-targets --csp aws 2>&1 | Out-String)
    # Every AWS role comes back as an ARN, whether this build prints JSON or a
    # table, so counting ARNs works either way.
    $targetCount = ([regex]::Matches($targets, 'arn:aws:iam::')).Count
    if ($targetCount -lt 1) {
        Write-Bad 'no AWS role came back'
        # Two very different causes print the same empty list. Rule the cheap one
        # out first, or an attendee emails about an entitlement they already have.
        if (-not $HasDefaultProfile) {
            Write-Warn 'the default profile is not CYBRWorld, so this asked the wrong tenant'
            Show-DefaultProfileAdvice
            Add-Fail 'AWS credentials' 'wrong tenant' 'Put CYBRWorld on the default profile: idsec configure -- then re-run this script'
        } else {
            Write-Dim 'This is an access entitlement. It cannot be fixed from your seat, and'
            Write-Dim 'it takes days. Ask in #cybr-japac-ts-all TODAY.'
            Write-Dim 'Logged in to a tenant other than CYBRWorld? Check with: idsec profiles show'
            Add-Fail 'AWS credentials' 'no entitlement' 'Ask in #cybr-japac-ts-all today -- you have no AWS role yet'
        }
    } else {
        Write-Good "$targetCount AWS role(s) available to you"
        if (-not $Jq) {
            Write-Warn 'jq does not run in this window, so the rest of this step is skipped'
            Add-Manual 'AWS credentials' 'finish step 6, then re-run this script'
        } elseif (-not (Test-Path $VPy)) {
            Write-Warn 'no virtual environment yet, so the rest of this step is skipped'
            Add-Manual 'AWS credentials' 'finish step 3, then re-run this script'
        } elseif (Confirm-Action 'Run the full rehearsal now? It gets real credentials and throws them away.') {
            Invoke-AwsRehearsal
        } else {
            Add-Manual 'AWS credentials' 'run the elevate one-liner by hand -- setup step 7'
        }
    }
}

# ------------------------------------------------------- 9 - TLS to Bedrock

# Every model call in this workshop is HTTPS to Bedrock, from Python in Part 1 and
# from Claude Code in Part 2. A network that re-signs certificates breaks both, in
# the same way, with an error that reads like a credential problem. It is worth two
# seconds here because it is the one failure a helper cannot fix at the desk.

# INFORMATION ONLY, and deliberately so. Part 1's Python does not verify
# certificates at all (see the TLS note at the top of ai-harness-app/config.py), so
# an inspecting proxy can no longer end somebody's session -- which means nothing
# this step finds is a reason to escalate, and it never calls Add-Fail.
#
# It stays in the script because the ANSWER is still worth having: knowing that the
# venue network re-signs certificates tells the workshop owner what to expect from
# Claude Code in Part 2, which does verify. Kept as a warning, not a gate.
Write-Step '9.' 'How this network treats HTTPS (information only)'

$TlsPy = if (Test-Path $VPy) { $VPy } elseif (Have-Command 'python') { 'python' } elseif (Have-Command 'py') { 'py' } else { $null }

# A CA bundle variable left pointing at a file that no longer exists used to break
# every Python call in the workshop. It no longer does, because nothing here reads
# a bundle any more. Still worth naming: it will bite something else on this laptop.
$staleBundle = $null
foreach ($name in 'AWS_CA_BUNDLE', 'REQUESTS_CA_BUNDLE', 'CURL_CA_BUNDLE', 'SSL_CERT_FILE') {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value -and -not (Test-Path -LiteralPath $value -PathType Leaf)) { $staleBundle = $name }
}

if ($staleBundle) {
    Write-Warn "$staleBundle points at a file that does not exist"
    Write-Dim  'Nothing in this workshop reads it, so the lessons will run regardless.'
    Write-Dim  'It will break other tools on this laptop, though, so worth tidying:'
    Write-Cmd  'Remove-Item Env:AWS_CA_BUNDLE, Env:REQUESTS_CA_BUNDLE, Env:CURL_CA_BUNDLE, Env:SSL_CERT_FILE -ErrorAction SilentlyContinue'
    Add-Manual 'HTTPS to Bedrock' "$staleBundle is stale -- harmless here, worth tidying"
} elseif (-not $TlsPy) {
    Write-Dim 'skipped -- no Python to test with yet, and nothing depends on the answer'
    Add-Manual 'HTTPS to Bedrock' 'not checked -- needs Python, but the lessons do not need this'
} else {
    # Written to a temp file rather than passed with -c: the script contains quotes
    # and newlines, and PowerShell's argument quoting mangles both.
    $probe = Join-Path ([IO.Path]::GetTempPath()) 'idira-tls-probe.py'
    @'
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
'@ | Set-Content -LiteralPath $probe -Encoding utf8

    $result = (& $TlsPy $probe 2>$null | Select-Object -Last 1)
    Remove-Item -LiteralPath $probe -ErrorAction SilentlyContinue

    $kind, $detail = if ($result -match '^(\w+)\|(.*)$') { $Matches[1], $Matches[2] } else { 'UNKNOWN', '' }

    switch ($kind) {
        'OK' {
            if ($detail -eq 'Amazon') {
                Write-Good 'reached AWS, certificate issued by Amazon -- a clean path'
                Add-Pass 'HTTPS to Bedrock' 'clean path (Amazon)'
            } else {
                Write-Good "reached AWS -- but the certificate was issued by: $detail"
                Write-Dim  'Not Amazon, so something on this network is inspecting HTTPS. Part 1'
                Write-Dim  'does not care: it does not verify certificates. Claude Code in Part 2'
                Write-Dim  'does, so mention it in #cybr-japac-ts-all. Useful for us to know.'
                Add-Manual 'HTTPS to Bedrock' "inspected by $detail -- fine for Part 1"
            }
        }
        { $_ -in 'BUNDLE', 'INTERCEPT' } {
            Write-Good 'reached AWS -- the certificate did not verify on this machine'
            Write-Dim $detail
            Write-Dim 'Either a proxy is re-signing certificates, or a CA bundle variable here'
            Write-Dim 'does not cover AWS. Part 1 runs anyway -- it does not verify at all, on'
            Write-Dim 'purpose (ai-harness-app/config.py explains why, and why you should not'
            Write-Dim 'copy that choice). Claude Code in Part 2 DOES verify, so a reply telling'
            Write-Dim 'us this is genuinely useful, and a corporate root CA path even more so:'
            Write-Cmd  '$env:NODE_EXTRA_CA_CERTS="C:\path\to\corp-root.pem"'
            Add-Manual 'HTTPS to Bedrock' 'inspected -- fine for Part 1, may affect Part 2'
        }
        'NET' {
            Write-Warn 'could not reach Bedrock at all'
            Write-Dim $detail
            Write-Dim 'Offline, a VPN, or egress filtering. This one WOULD stop the workshop, so'
            Write-Dim 're-run it on the network you will actually use on the day.'
            Add-Manual 'HTTPS to Bedrock' "no route from here -- re-test on the day's network"
        }
        default {
            Write-Dim 'the check did not produce a usable answer, and nothing depends on it'
            Add-Manual 'HTTPS to Bedrock' 'inconclusive -- mention it if the day goes wrong'
        }
    }
}

# ------------------------------------------------- 10 - console sign-in

# Lessons 09 and 10 read the console in a browser: the same CYBRWorld tenant idsec
# uses, reached the other way. Nothing to install, and this script cannot test it,
# because it needs a real sign-in with a real MFA prompt. It is printed as a
# reminder and never as a gate, the same treatment as the HTTPS step above.
Write-Step '10.' 'A browser sign-in to the console (information only)'

Write-Info 'Lesson 10 opens https://demo.cyberark.cloud/ in a browser. That is the same'
Write-Info 'tenant idsec uses, and this script cannot test the browser half.'
Write-Info 'Open it now and sign in with your own account. If the console loads, you are'
Write-Info 'done. Note which browser you used: lesson 10 opens a sign-in page from the'
Write-Info 'terminal, and it uses whichever browser is your default.'
Add-Manual 'console sign-in' 'check it in a browser -- setup step 9'

# --------------------------------------------------------------- summary

Write-Host ''
Write-Host '------------------------  Summary  ------------------------' -ForegroundColor White
Write-Host ''
foreach ($row in $Summary) {
    Write-Host ("  {0,-7} {1,-24} " -f $row.Icon, $row.What) -NoNewline
    Write-Host $row.Detail -ForegroundColor DarkGray
}

# This script checks everything it can, including the AWS entitlement and whether
# each program really starts. One thing is left, and it is the one with a lead
# time: an endpoint policy nobody in the room can change. Printed in both the pass
# and the fail path, because the pass path is the one people actually read.
function Show-OnlyYou {
    Write-Host ''
    Write-Host '  ----------  One thing that needs days, not minutes  ----------' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Did this script say a program is blocked rather than missing?' -ForegroundColor White
    Write-Host '  A message about a policy, an administrator, ''this application is blocked'','
    Write-Host '  or Idira EPM is endpoint application control. It is not a setup problem.'
    Write-Host '  This script cannot fix it and neither can a helper on the day: it needs an'
    Write-Host '  endpoint policy change, and that takes days.'
    Write-Host ''
    Write-Host '  Ask in the #cybr-japac-ts-all Slack channel TODAY.' -NoNewline -ForegroundColor White
    Write-Host ' If a Request for'
    Write-Host '  authorization prompt appears, use it too.'
}

if ($Todo.Count -eq 0) {
    Write-Host ''
    Write-Host '  Every check this script can make has passed.' -ForegroundColor Green
    Show-OnlyYou
    Write-Host ''
    Write-Host '  Bring: this laptop and a charger. Questions go to #cybr-japac-ts-all.'
    Write-Host '  See you there!'
    exit 0
}

Write-Host ''
Write-Host '  Still to do:' -ForegroundColor Yellow
Write-Host ''
# One failure often cascades into the next check, so the same instruction can be
# queued twice. Print each one once.
$i = 1
foreach ($t in ($Todo | Select-Object -Unique)) {
    Write-Host ("  {0}. {1}" -f $i, $t)
    $i++
}
Write-Host ''
Write-Host '  Re-run this script when you have worked through those:'
Write-Host ''
Write-Host '      .\check-prereqs.ps1' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Stuck on any of them? Ask in #cybr-japac-ts-all this week -- we would'
Write-Host '  much rather fix it now than on the day.'
Show-OnlyYou
exit 1
