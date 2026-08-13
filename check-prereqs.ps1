<#
    SKO27 TechSummit - AI Workshop for Idira DC
    Prework checker for Windows PowerShell.  (macOS/Linux: use check-prereqs.sh)

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

Write-Host ''
Write-Host '🚀 SKO27 TechSummit - AI Workshop for Idira DC' -ForegroundColor White
Write-Host '   Prework checker · Windows · nothing here needs admin rights' -ForegroundColor DarkGray
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
    Write-Info 'Run this script from inside the workshop folder — the one your'
    Write-Info 'workshop email pointed you at. Nothing else here will work without it.'
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
    Write-Info 'exactly the step that asks for admin rights. 📧 Reply to your workshop'
    Write-Info 'email instead and we will sort it out with you before the day.'
    Add-Fail 'Python' 'not found' 'Reply to the workshop email about Python — do not install it yourself'
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
            Add-Fail 'Virtual environment' 'creation failed' 'Raise this in a reply to the workshop email'
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
        Add-Pass 'Libraries' 'boto3 + anthropic + rich'
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
                Add-Fixed 'Libraries' 'installed'
            } else {
                Write-Bad 'the install did not finish cleanly'
                Add-Fail 'Libraries' 'install failed' 'Re-run: .venv\Scripts\python.exe -m pip install -r sandbox-app\requirements.txt'
            }
        } else {
            Add-Fail 'Libraries' 'not installed' "Run: .venv\Scripts\python.exe -m pip install -r $($need[0])"
        }
    }
}

# --------------------------------------------------------- 5 · claude code

Write-Step '5️⃣ ' 'Claude Code 🤖'

if (Have-Command 'claude') {
    $cv = (& claude --version 2>$null | Select-Object -First 1)
    Write-Good "claude $cv"
    Add-Pass 'Claude Code' 'installed'
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
            Add-Fail 'Claude Code' 'install failed' 'Try again on a network without a proxy, or reply to the workshop email'
        }
    } else {
        Add-Fail 'Claude Code' 'not installed' 'Run: irm https://claude.ai/install.ps1 | iex'
    }
}

# --------------------------------------------------------------- 6 · idsec

Write-Step '6️⃣ ' 'The idsec CLI ⌨️'

function Get-IdsecUrl {
    # Newest release, the asset for 64-bit Windows.
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/cyberark/idsec-cli-golang/releases/latest' `
                                 -Headers @{ 'User-Agent' = 'idira-workshop-prework' }
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

if (Have-Command 'idsec') {
    $iv = (& idsec version 2>$null | Select-Object -First 1)
    Write-Good "idsec $iv"
    Add-Pass 'idsec CLI' 'installed'
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
            Add-Fail 'idsec CLI' 'auto-download failed' 'Install idsec by hand — see prework step 5 in the lab guide'
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
                    Add-Fail 'idsec CLI' 'unexpected archive' 'Install idsec by hand — see prework step 5 in the lab guide'
                }
            } catch {
                Write-Bad "the download failed: $($_.Exception.Message)"
                Add-Fail 'idsec CLI' 'download failed' 'Install idsec by hand — see prework step 5 in the lab guide'
            } finally {
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Add-Fail 'idsec CLI' 'not installed' 'Install idsec — see prework step 5 in the lab guide'
    }
}

# ------------------------------------------------------- 7 · idsec profile

Write-Step '7️⃣ ' 'An idsec profile you can log in with 🔐'

$profilePath = @('.idsec', '.idsec_profiles', '.ark_profiles', '.cyberark') |
    ForEach-Object { Join-Path $HOME $_ } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if ($profilePath) {
    Write-Good "found idsec settings at $profilePath"
    Write-Dim 'Confirm it works before the day by running: idsec login'
    Add-Pass 'idsec profile' 'configured'
} elseif (-not (Have-Command 'idsec') -and -not (Test-Path $idsecExe)) {
    Write-Bad 'skipped — idsec is not installed yet'
    Add-Fail 'idsec profile' 'blocked by idsec' 'Install idsec, then run: idsec configure'
} else {
    Write-Bad 'no idsec settings found'
    Write-Info "'idsec configure' asks a few questions. Answer them with the tenant"
    Write-Info 'subdomain and username from your workshop email. 📧'
    if (Confirm-Action "Run 'idsec configure' now? (it will ask you questions)") {
        $exe = if (Have-Command 'idsec') { 'idsec' } else { $idsecExe }
        & $exe configure
        if ($LASTEXITCODE -eq 0) {
            Write-Good 'configured — now prove it works with: idsec login'
            Add-Fixed 'idsec profile' 'configured (run idsec login next)'
        } else {
            Write-Bad 'configure did not complete'
            Add-Fail 'idsec profile' 'not configured' 'Run: idsec configure'
        }
    } else {
        Add-Fail 'idsec profile' 'not configured' 'Run: idsec configure (once — a second run overwrites it)'
    }
}

# ------------------------------------------------------------ 8 · AWS access

Write-Step '8️⃣ ' 'AWS access through the portal ☁️'

Write-Warn 'no script can check this one for you — please click through it 🙏'
Write-Info '1. Open https://ngid.cyberark.cloud/ and sign in'
Write-Info '2. Open CYBR User Portal, then click the AWS tile'
Write-Info '3. You should land on a page ending in awsapps.com/start/#'
Write-Info "4. Next to your account, click 'Access keys' (or 'Get credentials')"
Write-Info "5. Confirm you see 'Option 1: Set AWS environment variables'"
Write-Dim 'Nothing to copy yet. You just need to know the link is there.'
Write-Dim 'No AWS tile, no accounts, or no Access keys link? 📧 Reply to the workshop'
Write-Dim 'email TODAY — it is an entitlement, and it cannot be fixed from your seat.'
Add-Manual 'AWS portal access' 'check it by hand — step 8 above'

# --------------------------------------------------------------- summary

Write-Host ''
Write-Host '────────────────────────  Summary  ────────────────────────' -ForegroundColor White
Write-Host ''
foreach ($row in $Summary) {
    Write-Host ("  {0}  {1,-24} " -f $row.Icon, $row.What) -NoNewline
    Write-Host $row.Detail -ForegroundColor DarkGray
}

# Two things no script can settle, and both need a reply days ahead rather than a
# raised hand on the day: an entitlement nobody in the room can grant, and an
# endpoint policy nobody in the room can change. Printed in both the pass and the
# fail path, because the pass path is the one people actually read.
function Show-OnlyYou {
    Write-Host ''
    Write-Host '  ──────────  Two things only you can confirm  ──────────' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  1. The AWS portal (8️⃣  above).' -NoNewline -ForegroundColor White
    Write-Host ' Click through it now if you have not.'
    Write-Host "     No AWS tile, no accounts, or no 'Access keys' link means you are missing an"
    Write-Host '     entitlement. Nobody can grant it from a seat on the day.'
    Write-Host ''
    Write-Host '  2. Does this laptop actually let these programs run?' -ForegroundColor White
    Write-Host '     Try both, in a new PowerShell window:'
    Write-Host ''
    Write-Host '         idsec version' -ForegroundColor Cyan
    Write-Host '         claude --version' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '     A version number from each means you are fine. But if either one is found'
    Write-Host '     and still refuses to start — a message about a policy, an administrator,'
    Write-Host "     'this application is blocked', or Idira EPM — that is endpoint application"
    Write-Host '     control, not a setup problem. This script cannot fix it and neither can a'
    Write-Host '     helper: it needs an endpoint policy change with a lead time of days. If a'
    Write-Host '     Request for authorization prompt appears, use it.'
    Write-Host ''
    Write-Host '  Either of those looking wrong? 📧 Reply to the workshop email TODAY.' -ForegroundColor White
    Write-Host '  Not tomorrow, and definitely not on the morning of the workshop. Both take'
    Write-Host '  days to sort out, and both stop you doing the hands-on work entirely.'
}

if ($Todo.Count -eq 0) {
    Write-Host ''
    Write-Host '  🎉 Every check this script can make has passed.' -ForegroundColor Green
    Show-OnlyYou
    Write-Host ''
    Write-Host '  Bring: this laptop, a charger, and your workshop email. See you there! 👋'
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
Write-Host '  Stuck on any of them? 📧 Reply to the workshop email this week — we would'
Write-Host '  much rather fix it now than on the day.'
Show-OnlyYou
exit 1
