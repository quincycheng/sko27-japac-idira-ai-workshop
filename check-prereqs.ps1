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
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Continue'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# ---------------------------------------------------------------- appearance

$Project = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Venv    = Join-Path $Project '.venv'
$VPy     = Join-Path $Venv 'Scripts\python.exe'
$BinDir  = Join-Path $HOME 'bin'

$Summary = [System.Collections.Generic.List[object]]::new()
$Todo    = [System.Collections.Generic.List[string]]::new()

function Add-Pass  ($What, $Detail) { $Summary.Add([pscustomobject]@{ Icon='✅'; What=$What; Detail=$Detail }) }
function Add-Fixed ($What, $Detail) { $Summary.Add([pscustomobject]@{ Icon='🛠️ '; What=$What; Detail=$Detail }) }
function Add-Manual($What, $Detail) { $Summary.Add([pscustomobject]@{ Icon='👀'; What=$What; Detail=$Detail }) }
function Add-Fail  ($What, $Detail, $Next) {
    $Summary.Add([pscustomobject]@{ Icon='❌'; What=$What; Detail=$Detail })
    $Script:Todo.Add($Next)
}

function Write-Step ($Num, $Text) { Write-Host ''; Write-Host "$Num $Text" -ForegroundColor White }
function Write-Info ($Text) { Write-Host "   $Text" }
function Write-Dim  ($Text) { Write-Host "   $Text" -ForegroundColor DarkGray }
function Write-Good ($Text) { Write-Host "   ✅ $Text" -ForegroundColor Green }
function Write-Bad  ($Text) { Write-Host "   ❌ $Text" -ForegroundColor Red }
function Write-Warn ($Text) { Write-Host "   ⚠️  $Text" -ForegroundColor Yellow }
function Write-Cmd  ($Text) { Write-Host "   > $Text" -ForegroundColor Cyan }

# Confirm-Action "question" -> $true for yes. Honours -Yes and -CheckOnly.
function Confirm-Action ($Question) {
    if ($CheckOnly) {
        Write-Host "   (-CheckOnly, so not offering to fix this)" -ForegroundColor DarkGray
        return $false
    }
    if ($Yes) {
        Write-Host "   🤖 $Question -> yes (-Yes)" -ForegroundColor DarkGray
        return $true
    }
    $reply = Read-Host "   🤔 $Question [y/N]"
    return ($reply -match '^(y|yes)$')
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
function Write-Blocked ($Name) {
    Write-Bad "'$Name' is on your PATH but will not run"
    Write-Info 'That is endpoint application control, not a PATH problem. It decides'
    Write-Info 'which programs may run on a managed laptop. Please do not work around it.'
    Write-Info "Offered a 'Request for authorization' button? Use it. Otherwise ask in"
    Write-Info 'the 💬 #cybr-japac-ts-all Slack channel TODAY.'
}

Write-Host ''
Write-Host '🚀 SKO27 TechSummit - AI Workshop for Idira DC' -ForegroundColor White
Write-Host '   Setup checker · Windows · nothing here needs admin rights' -ForegroundColor DarkGray
Write-Host ''
Write-Host "   Project folder : $Project"

# ------------------------------------------------------- 1 · workshop folder

Write-Step '1️⃣ ' 'The workshop folder'

$missing = @('lab', 'sandbox-app', 'ai-harness-app', 'skills') |
    Where-Object { -not (Test-Path (Join-Path $Project $_)) }

if ($missing.Count -eq 0) {
    Write-Good 'lab, sandbox-app, ai-harness-app and skills are all here'
    Add-Pass 'Workshop folder' 'complete'
} else {
    Write-Bad ("missing: " + ($missing -join ', '))
    Write-Info 'Run this script from inside the workshop folder — the one linked in'
    Write-Info '#cybr-japac-ts-all. Nothing else here will work without it.'
    Add-Fail 'Workshop folder' ("missing " + ($missing -join ', ')) `
             'Re-download the workshop folder and run this script from inside it'
}

# --------------------------------------------------------------- 2 · python

Write-Step '2️⃣ ' 'Python 3.9 or newer 🐍'

$Py = $null
foreach ($cand in @('python', 'py', 'python3')) {
    if (-not (Have-Command $cand)) { continue }
    # A bare `python` on Windows is often the Microsoft Store stub, which exits
    # non-zero and prints nothing useful. Checking the version filters it out.
    $ver = & $cand -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>$null
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
    Write-Info 'Please do NOT install Python yourself — on a managed laptop that is'
    Write-Info 'exactly the step that asks for admin rights. 💬 Ask in the'
    Write-Info '#cybr-japac-ts-all Slack channel and we will sort it out before the day.'
    Add-Fail 'Python' 'not found' 'Ask in #cybr-japac-ts-all about Python — do not install it yourself'
}

# ------------------------------------------------- 3 · virtual environment

Write-Step '3️⃣ ' 'A virtual environment in this folder'

if (Test-Path $VPy) {
    $v = & $VPy -c 'import sys; print("Python %d.%d.%d" % sys.version_info[:3])' 2>$null
    Write-Good ".venv exists ($v)"
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

# --------------------------------------------------------- 4 · dependencies

Write-Step '4️⃣ ' 'The libraries the workshop needs 📦'

function Test-Import ($Module) {
    if (-not (Test-Path $VPy)) { return $false }
    & $VPy -c "import $Module" 2>$null
    return ($LASTEXITCODE -eq 0)
}

# Every library can be installed and Part 1 still not start. The lesson modules
# are Python source too, and an interpreter that is too old for their syntax
# parses them and then refuses to run them. That shows up as one error message
# on the first lesson, in the room. So import what the lessons import.
# Library modules only: importing 01_bare_call.py would fire a real model call.
function Test-Part1 {  # -> $true if Part 1 will start.  Records its own ❌ row if not.
    Push-Location (Join-Path $Project 'ai-harness-app')
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
    Write-Bad 'skipped — no virtual environment yet'
    Add-Fail 'Libraries' 'blocked by .venv' 'Create the virtual environment, then re-run this script'
} else {
    $need = @()
    if (-not (Test-Import 'boto3')) { $need += 'sandbox-app\requirements.txt' }
    # rich powers ui.py, which every lesson imports. Without checking it, a failed
    # rich install reports PASS here and then crashes on import in the room. Both
    # live in the same requirements file, so test them together and list it once.
    if (-not (Test-Import 'anthropic') -or -not (Test-Import 'rich')) {
        $need += 'ai-harness-app\requirements.txt'
    }

    if ($need.Count -eq 0) {
        Write-Good 'boto3 is ready (the sandbox app)'
        Write-Good 'anthropic is ready (the harness lessons in Part 1)'
        Write-Good 'rich is ready (the terminal UI)'
        if (Test-Part1) {
            Add-Pass 'Libraries' 'boto3 + anthropic + rich'
        }
    } else {
        Write-Bad ("missing libraries from: " + ($need -join ', '))
        if (Confirm-Action 'Install them into .venv now? (needs internet, ~1 minute)') {
            & $VPy -m pip install --quiet --upgrade pip 2>$null | Out-Null
            foreach ($req in $need) {
                Write-Cmd "python -m pip install -r $req"
                & $VPy -m pip install --quiet -r (Join-Path $Project $req)
            }
            if ((Test-Import 'boto3') -and (Test-Import 'anthropic') -and (Test-Import 'rich')) {
                Write-Good 'boto3, anthropic and rich all import cleanly'
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

# --------------------------------------------------------- 5 · claude code

Write-Step '5️⃣ ' 'Claude Code 🤖'

if ((Have-Command 'claude') -and (Test-Runs 'claude' @('--version'))) {
    $cv = (& claude --version 2>$null | Select-Object -First 1)
    Write-Good "claude $cv"
    Add-Pass 'Claude Code' 'runs'
} elseif (Have-Command 'claude') {
    Write-Blocked 'claude'
    Add-Fail 'Claude Code' 'found but will not run' `
             'Get Claude Code allowed by your endpoint policy — ask in #cybr-japac-ts-all'
} else {
    Write-Bad "the 'claude' command was not found"
    Write-Dim 'It installs into your home folder. No admin rights, no Node.js.'
    if (Confirm-Action 'Install Claude Code now? (runs the official installer)') {
        Write-Cmd 'irm https://claude.ai/install.ps1 | iex'
        try {
            Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
            Write-Good 'installed — open a NEW PowerShell window, then run: claude --version'
            Add-Fixed 'Claude Code' 'installed (new window needed)'
        } catch {
            Write-Bad "the installer failed: $($_.Exception.Message)"
            Add-Fail 'Claude Code' 'install failed' 'Try again on a network without a proxy, or ask in #cybr-japac-ts-all'
        }
    } else {
        Add-Fail 'Claude Code' 'not installed' 'Run: irm https://claude.ai/install.ps1 | iex'
    }
}

# ---------------------------------------------------------- 6 · idsec and jq

Write-Step '6️⃣ ' 'The idsec CLI and jq ⌨️'

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

function Add-UserPath ($Dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -split ';' -contains $Dir) { return $false }
    # 'User' scope, not 'Machine' — this is why no admin prompt appears.
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$Dir", 'User')
    $env:Path = "$env:Path;$Dir"
    return $true
}

$idsecExe = Join-Path $BinDir 'idsec.exe'

if ((Have-Command 'idsec') -and (Test-Runs 'idsec' @('version'))) {
    $iv = (& idsec version 2>$null | Select-Object -First 1)
    Write-Good "idsec $iv"
    Add-Pass 'idsec CLI' 'runs'
} elseif (Have-Command 'idsec') {
    Write-Blocked 'idsec'
    Add-Fail 'idsec CLI' 'found but will not run' `
             'Get idsec allowed by your endpoint policy — ask in #cybr-japac-ts-all'
} elseif (Test-Path $idsecExe) {
    Write-Warn "idsec is at $idsecExe but not on your PATH in this window"
    if (Confirm-Action "Add $BinDir to your user PATH?") {
        Add-UserPath $BinDir | Out-Null
        Write-Good 'added — open a new PowerShell window, then run: idsec version'
        Add-Fixed 'idsec CLI' 'PATH fixed (new window needed)'
    } else {
        Add-Fail 'idsec CLI' 'not on PATH' "Add $BinDir to your user PATH"
    }
} else {
    Write-Bad "the 'idsec' command was not found"
    Write-Dim 'It is a single file — no installer, nothing registered with Windows.'
    if (Confirm-Action "Download the latest idsec into $BinDir and set it up?") {
        $url = Get-IdsecUrl
        if (-not $url) {
            Write-Bad 'could not work out which release file to download'
            Write-Info 'Do it by hand — the lab page walks you through it:'
            Write-Info '🔗 https://github.com/cyberark/idsec-cli-golang/releases'
            Add-Fail 'idsec CLI' 'auto-download failed' 'Install idsec by hand — see setup step 5 in the lab guide'
        } else {
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("idsec-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Force -Path $tmp, $BinDir | Out-Null
            $file = Join-Path $tmp (Split-Path $url -Leaf)
            Write-Cmd "download $url"
            try {
                Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
                if ($file -match '\.zip$') {
                    Expand-Archive -Path $file -DestinationPath $tmp -Force
                } else {
                    & tar -xzf $file -C $tmp
                }
                # The archive names the binary after its platform — on Windows
                # that is idsec-windows.exe — and ships a LICENSE.txt and a
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
                    if (Confirm-Action "Add $BinDir to your user PATH?") {
                        Add-UserPath $BinDir | Out-Null
                        Write-Good 'added — open a new PowerShell window afterwards'
                    }
                    Add-Fixed 'idsec CLI' 'installed (new window needed)'
                } else {
                    Write-Bad 'downloaded the archive, but found no idsec binary inside it'
                    Add-Fail 'idsec CLI' 'unexpected archive' 'Install idsec by hand — see setup step 5 in the lab guide'
                }
            } catch {
                Write-Bad "the download failed: $($_.Exception.Message)"
                Add-Fail 'idsec CLI' 'download failed' 'Install idsec by hand — see setup step 5 in the lab guide'
            } finally {
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Add-Fail 'idsec CLI' 'not installed' 'Install idsec — see setup step 5 in the lab guide'
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
             'Get jq allowed by your endpoint policy — ask in #cybr-japac-ts-all'
} elseif (Test-Path $jqExe) {
    Write-Warn "jq is at $jqExe but not on your PATH in this window"
    if (Confirm-Action "Add $BinDir to your user PATH?") {
        Add-UserPath $BinDir | Out-Null
        Write-Good 'added — open a new PowerShell window, then run: jq --version'
        Add-Fixed 'jq' 'PATH fixed (new window needed)'
    } else {
        Add-Fail 'jq' 'not on PATH' "Add $BinDir to your user PATH"
    }
} else {
    Write-Bad "the 'jq' command was not found"
    Write-Dim "Also a single file. It reads your AWS credentials out of Idira's answer."
    if (Confirm-Action "Download jq into $BinDir and set it up?") {
        New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
        Write-Cmd "download $jqUrl"
        try {
            Invoke-WebRequest -Uri $jqUrl -OutFile $jqExe -UseBasicParsing
            Unblock-File $jqExe -ErrorAction SilentlyContinue
            Write-Good "installed to $jqExe"
            if (Confirm-Action "Add $BinDir to your user PATH?") {
                Add-UserPath $BinDir | Out-Null
                Write-Good 'added — open a new PowerShell window afterwards'
            }
            Add-Fixed 'jq' 'installed (new window needed)'
        } catch {
            Remove-Item $jqExe -Force -ErrorAction SilentlyContinue
            Write-Bad "the download failed: $($_.Exception.Message)"
            Add-Fail 'jq' 'download failed' 'Install jq by hand — see setup step 5 in the lab guide'
        }
    } else {
        Add-Fail 'jq' 'not installed' 'Install jq — see setup step 5 in the lab guide'
    }
}

# ------------------------------------------------------- 7 · idsec profile

Write-Step '7️⃣ ' 'An idsec profile, and a login that works 🔐'

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
# The fallback is $HOME\.idsec\profiles, a DIRECTORY holding one file per profile,
# named after the profile. Its dotfiles are bookkeeping, not profiles.
function Get-IdsecProfileNames {
    if (-not $Idsec) { return @() }
    $out = & $Idsec profiles list 2>$null
    if ($LASTEXITCODE -eq 0 -and ($out -join '').Trim()) {
        return @($out |
            ForEach-Object { ($_ -replace '[\[\]",]', '').Trim() } |
            Where-Object { $_ })
    }
    $dir = Join-Path $HOME '.idsec\profiles'
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
    Write-Info 'Still failing? Ask in the 💬 #cybr-japac-ts-all Slack channel.'
    Write-Info 'Do it this week, not on the day.'
    return $false
}

# The check that matters. Not "is anything configured?" but "is CYBRWorld on the
# profile the lab commands will actually use?" The old version accepted any
# profile, so an attendee with one named profile for another tenant was told
# everything was fine and then watched the login fail for no stated reason.
$Profiles = @()
$HasDefaultProfile = $false
if ($Idsec) {
    $Profiles = Get-IdsecProfileNames
    $HasDefaultProfile = [bool]($Profiles -contains 'idsec')
}

if (-not $Idsec) {
    Write-Bad 'skipped — idsec does not run in this window yet'
    Add-Fail 'idsec login' 'blocked by idsec' 'Finish step 6, open a new PowerShell window, then re-run this script'
} elseif ($HasDefaultProfile) {
    Write-Good "the default profile, 'idsec', exists"
    if (Confirm-Action 'Log in now, to prove the profile actually works?') {
        if (Invoke-IdsecLogin) {
            Add-Pass 'idsec login' 'signed in to CYBRWorld'
        } else {
            Add-Fail 'idsec login' 'login failed' 'Fix your idsec profile: idsec configure — then: idsec login'
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
                Add-Fail 'idsec login' 'configured, login failed' 'Fix the values: idsec configure — then: idsec login'
            }
        } else {
            Write-Bad 'configure did not complete'
            Add-Fail 'idsec login' 'no default profile' 'Run: idsec configure (CYBRWorld, as the default profile)'
        }
    } else {
        Add-Fail 'idsec login' 'no default profile' "Run: idsec configure — CYBRWorld must be the default profile, 'idsec'"
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
                Add-Fail 'idsec login' 'configured, login failed' 'Fix the values: idsec configure — then: idsec login'
            }
        } else {
            Write-Bad 'configure did not complete'
            Add-Fail 'idsec login' 'not configured' 'Run: idsec configure'
        }
    } else {
        Add-Fail 'idsec login' 'not configured' 'Run: idsec configure (once — a second run overwrites it)'
    }
}

# ------------------------------------------------------------ 8 · AWS access

Write-Step '8️⃣ ' 'Short-lived AWS credentials from idsec ☁️'

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
    $stdout = $proc.StandardOutput.ReadToEndAsync()
    if (-not $proc.WaitForExit($Seconds * 1000)) {
        try { $proc.Kill() } catch { }
        return $null
    }
    return $stdout.Result
}

# The whole path, run for real: ask Idira to elevate, then ask AWS who you are.
# The credentials live in this window's environment for a few seconds. Nothing is
# printed and nothing is written to a file, and they are cleared at the end.
function Invoke-AwsRehearsal {
    Write-Info 'asking Idira for credentials — this can take a moment'
    $raw = Invoke-WithTimeout $Idsec @(
        'exec', 'sca', 'cloud-access', 'elevate', '--csp', 'aws',
        '--workspace-id', $AwsWorkspace, '--roleIds', $AwsRole, '--raw'
    ) 120
    if ($null -eq $raw) {
        Write-Bad 'the elevate call did not finish in two minutes'
        Write-Info 'It may be waiting on an approval. Run it by hand — setup step 7.'
        Add-Manual 'AWS credentials' 'elevate timed out — run it by hand, setup step 7'
        return
    }
    $filter = '.response.results[0].accessCredentials | fromjson | "$env:AWS_ACCESS_KEY_ID=\"\(.aws_access_key)\"\n$env:AWS_SECRET_ACCESS_KEY=\"\(.aws_secret_access_key)\"\n$env:AWS_SESSION_TOKEN=\"\(.aws_session_token)\""'
    $creds = ($raw | & $Jq -r $filter 2>$null) -join "`n"
    $raw = $null
    if (-not $creds.Trim()) {
        Write-Bad 'no credentials came back'
        Write-Info 'The role exists, so this is usually a policy on the role itself.'
        Write-Info '💬 Ask in #cybr-japac-ts-all today and paste in what you ran.'
        Add-Fail 'AWS credentials' 'elevate returned nothing' '💬 Ask in #cybr-japac-ts-all — elevate gave no credentials'
        return
    }
    Write-Good 'credentials received'
    try {
        $creds | Invoke-Expression
        # verify=False for the same reason ai-harness-app/config.py sets it: a TLS-inspecting
        # proxy would otherwise fail this call and be reported as "AWS rejected them", which
        # sends the attendee after the wrong problem. Step 9 below is where TLS gets judged.
        $arn = & $VPy -c 'import boto3, urllib3
urllib3.disable_warnings()
print(boto3.client("sts", verify=False).get_caller_identity()["Arn"])' 2>$null
        if ($arn) {
            Write-Good "AWS accepted them: $arn"
            Write-Dim 'They are gone now. This script never saved them anywhere.'
            Add-Pass 'AWS credentials' 'elevate and AWS both worked'
        } else {
            Write-Bad 'the credentials came back, but AWS did not accept them'
            Write-Info 'Do the two commands by hand — setup step 7 explains every error.'
            Add-Fail 'AWS credentials' 'AWS rejected them' 'Run setup step 7 by hand, then 💬 ask in #cybr-japac-ts-all'
        }
    } finally {
        Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY, Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
    }
}

if (-not $Idsec) {
    Write-Bad 'skipped — idsec does not run in this window yet'
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
            Add-Fail 'AWS credentials' 'wrong tenant' 'Put CYBRWorld on the default profile: idsec configure — then re-run this script'
        } else {
            Write-Dim 'This is an access entitlement. It cannot be fixed from your seat, and'
            Write-Dim 'it takes days. 💬 Ask in #cybr-japac-ts-all TODAY.'
            Write-Dim 'Logged in to a tenant other than CYBRWorld? Check with: idsec profiles show'
            Add-Fail 'AWS credentials' 'no entitlement' '💬 Ask in #cybr-japac-ts-all today — you have no AWS role yet'
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
            Add-Manual 'AWS credentials' 'run the elevate one-liner by hand — setup step 7'
        }
    }
}

# ------------------------------------------------------- 9 · TLS to Bedrock

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
Write-Step '9️⃣ ' 'How this network treats HTTPS 🔐 (information only)'

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
    Add-Manual 'HTTPS to Bedrock' "$staleBundle is stale — harmless here, worth tidying"
} elseif (-not $TlsPy) {
    Write-Dim 'skipped — no Python to test with yet, and nothing depends on the answer'
    Add-Manual 'HTTPS to Bedrock' 'not checked — needs Python, but the lessons do not need this'
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
                Write-Good 'reached AWS, certificate issued by Amazon — a clean path'
                Add-Pass 'HTTPS to Bedrock' 'clean path (Amazon)'
            } else {
                Write-Good "reached AWS — but the certificate was issued by: $detail"
                Write-Dim  'Not Amazon, so something on this network is inspecting HTTPS. Part 1'
                Write-Dim  'does not care: it does not verify certificates. Claude Code in Part 2'
                Write-Dim  'does, so mention it in #cybr-japac-ts-all. Useful for us to know. 💬'
                Add-Manual 'HTTPS to Bedrock' "inspected by $detail — fine for Part 1"
            }
        }
        { $_ -in 'BUNDLE', 'INTERCEPT' } {
            Write-Good 'reached AWS — the certificate did not verify on this machine'
            Write-Dim $detail
            Write-Dim 'Either a proxy is re-signing certificates, or a CA bundle variable here'
            Write-Dim 'does not cover AWS. Part 1 runs anyway — it does not verify at all, on'
            Write-Dim 'purpose (ai-harness-app/config.py explains why, and why you should not'
            Write-Dim 'copy that choice). Claude Code in Part 2 DOES verify, so a reply telling'
            Write-Dim 'us this is genuinely useful, and a corporate root CA path even more so:'
            Write-Cmd  '$env:NODE_EXTRA_CA_CERTS="C:\path\to\corp-root.pem"'
            Add-Manual 'HTTPS to Bedrock' 'inspected — fine for Part 1, may affect Part 2'
        }
        'NET' {
            Write-Warn 'could not reach Bedrock at all'
            Write-Dim $detail
            Write-Dim 'Offline, a VPN, or egress filtering. This one WOULD stop the workshop, so'
            Write-Dim 're-run it on the network you will actually use on the day.'
            Add-Manual 'HTTPS to Bedrock' "no route from here — re-test on the day's network"
        }
        default {
            Write-Dim 'the check did not produce a usable answer, and nothing depends on it'
            Add-Manual 'HTTPS to Bedrock' 'inconclusive — mention it if the day goes wrong'
        }
    }
}

# ------------------------------------------------- 10 · console sign-in

# Lessons 09 and 10 read the console in a browser: the same CYBRWorld tenant idsec
# uses, reached the other way. Nothing to install, and this script cannot test it,
# because it needs a real sign-in with a real MFA prompt. It is printed as a
# reminder and never as a gate, the same treatment as the HTTPS step above.
Write-Step '🔟 ' 'A browser sign-in to the console 🪪 (information only)'

Write-Info 'Lesson 10 opens https://demo.cyberark.cloud/ in a browser. That is the same'
Write-Info 'tenant idsec uses, and this script cannot test the browser half.'
Write-Info 'Open it now and sign in with your own account. If the console loads, you are'
Write-Info 'done. Note which browser you used: lesson 10 opens a sign-in page from the'
Write-Info 'terminal, and it uses whichever browser is your default.'
Add-Manual 'console sign-in' 'check it in a browser — setup step 9'

# --------------------------------------------------------------- summary

Write-Host ''
Write-Host '────────────────────────  Summary  ────────────────────────' -ForegroundColor White
Write-Host ''
foreach ($row in $Summary) {
    Write-Host ("  {0}  {1,-24} " -f $row.Icon, $row.What) -NoNewline
    Write-Host $row.Detail -ForegroundColor DarkGray
}

# This script checks everything it can, including the AWS entitlement and whether
# each program really starts. One thing is left, and it is the one with a lead
# time: an endpoint policy nobody in the room can change. Printed in both the pass
# and the fail path, because the pass path is the one people actually read.
function Show-OnlyYou {
    Write-Host ''
    Write-Host '  ──────────  One thing that needs days, not minutes  ──────────' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Did this script say a program is blocked rather than missing?' -ForegroundColor White
    Write-Host '  A message about a policy, an administrator, ''this application is blocked'','
    Write-Host '  or Idira EPM is endpoint application control. It is not a setup problem.'
    Write-Host '  This script cannot fix it and neither can a helper on the day: it needs an'
    Write-Host '  endpoint policy change, and that takes days.'
    Write-Host ''
    Write-Host '  💬 Ask in the #cybr-japac-ts-all Slack channel TODAY.' -NoNewline -ForegroundColor White
    Write-Host ' If a Request for'
    Write-Host '  authorization prompt appears, use it too.'
}

if ($Todo.Count -eq 0) {
    Write-Host ''
    Write-Host '  🎉 Every check this script can make has passed.' -ForegroundColor Green
    Show-OnlyYou
    Write-Host ''
    Write-Host '  Bring: this laptop and a charger. Questions go to #cybr-japac-ts-all.'
    Write-Host '  See you there! 👋'
    exit 0
}

Write-Host ''
Write-Host '  ⚠️  Still to do:' -ForegroundColor Yellow
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
Write-Host '  Stuck on any of them? 💬 Ask in #cybr-japac-ts-all this week — we would'
Write-Host '  much rather fix it now than on the day.'
Show-OnlyYou
exit 1
