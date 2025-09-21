<#
Install Visual Studio 2022 Build Tools (C++ toolset) for Windows.

Usage (PowerShell as Administrator):
  cd <repo-root>
  .\tools\install_build_tools.ps1

The script will try `winget` first. If winget is not available it will download
the official `vs_BuildTools.exe` and run a quiet install with the C++ workload,
MSVC toolset and Windows SDK. After install it sets `npm config msvs_version 2022`.

You still must run `npm install` in your project afterwards.
#>

function Assert-Administrator {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Ovo skript treba da se pokrene kao Administrator. Otvori PowerShell kao Administrator i ponovo pokreni skript." -ForegroundColor Yellow
        Exit 1
    }
}

Assert-Administrator

$ErrorActionPreference = 'Stop'

Write-Host 'Starting Visual Studio Build Tools (C++) installation.' -ForegroundColor Cyan

function Install-WithWinget {
    param($packageId)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'winget found - attempting install via winget...' -ForegroundColor Green
        $wingetArgs = @('install', '--id', $packageId, '-e', '--accept-source-agreements', '--accept-package-agreements')
        $proc = Start-Process -FilePath 'winget' -ArgumentList $wingetArgs -NoNewWindow -Wait -PassThru
        return $proc.ExitCode
    }
    return 2
}

function Install-ExeFromUrl {
    param($url)
    $out = "$env:USERPROFILE\Downloads\vs_BuildTools.exe"
    Write-Host "Downloading installer to: $out" -ForegroundColor Green
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing

    $installArgs = @(
        '--quiet',
        '--wait',
        '--norestart',
        '--nocache',
        '--installPath', 'C:\BuildTools',
        '--add', 'Microsoft.VisualStudio.Workload.VCTools',
        '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
        '--add', 'Microsoft.VisualStudio.Component.Windows10SDK.19041'
    )

    Write-Host 'Starting silent install (this may take a while)...' -ForegroundColor Cyan
    $p = Start-Process -FilePath $out -ArgumentList $installArgs -Wait -PassThru
    return $p.ExitCode
}

$packageId = 'Microsoft.VisualStudio.2022.BuildTools'
$wingetExit = Install-WithWinget -packageId $packageId
if ($wingetExit -eq 0) {
    Write-Host 'winget install succeeded.' -ForegroundColor Green
} else {
    Write-Host "winget not available or install failed (code: $wingetExit). Falling back to download and silent install." -ForegroundColor Yellow
    $vsUrl = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    $exeExit = Install-ExeFromUrl -url $vsUrl
    if ($exeExit -ne 0) {
        Write-Host "Installer je završio sa kodom: $exeExit" -ForegroundColor Red
        Write-Host "Proveri logove ili pokreni installer interaktivno: $env:USERPROFILE\Downloads\vs_BuildTools.exe" -ForegroundColor Yellow
        Exit $exeExit
    }
}

Write-Host 'Install finished (or started). Setting npm configuration...' -ForegroundColor Cyan
npm config set msvs_version 2022 | Out-Null

Write-Host 'Next steps (open a NEW PowerShell window):' -ForegroundColor Green
Write-Host '1) cd to your project folder' -ForegroundColor Green
Write-Host '2) Run: npm install --no-audit --no-fund (or: npm install pg-native --no-audit --no-fund)' -ForegroundColor Green
Write-Host '3) If build still fails, reboot and check that cl.exe is available (run: where cl.exe).' -ForegroundColor Yellow

Write-Host 'Done - installer script completed.' -ForegroundColor Cyan

Exit 0
