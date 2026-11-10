# Symlink dotfiles into place on Windows. Safe to re-run.
# Existing files that aren't already the right link are moved to <name>.bak-<timestamp>.
#   pwsh -File install.ps1            link everything
#   pwsh -File install.ps1 -DryRun    show what would happen
#
# File symlinks need Developer Mode (Settings > System > For developers) or an admin shell.
# Folders fall back to junctions, which need neither.
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Run this from PowerShell 7 (pwsh), otherwise `$PROFILE points at the old Windows PowerShell profile."
}

$Dot   = $PSScriptRoot
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# source (relative to repo) -> target
$Links = [ordered]@{
    'nvim'                                  = "$env:LOCALAPPDATA\nvim"
    'wezterm\.wezterm.lua'                  = "$HOME\.wezterm.lua"
    'zed\settings.json'                     = "$env:APPDATA\Zed\settings.json"
    # Transitional: Windows keeps its own zed keymap until the mac one (cmd-*) is made portable.
    'zed\keymap.windows.json'               = "$env:APPDATA\Zed\keymap.json"
    'zed\themes'                            = "$env:APPDATA\Zed\themes"
    'powershell\Microsoft.PowerShell_profile.ps1' = $PROFILE.CurrentUserCurrentHost
}

foreach ($rel in $Links.Keys) {
    $src    = Join-Path $Dot $rel
    $target = $Links[$rel]
    $item   = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue

    if ($item -and $item.LinkType -and ($item.Target -eq $src -or @($item.Target)[0] -eq $src)) {
        Write-Host "ok      $target"
        continue
    }
    if ($DryRun) {
        if ($item) { Write-Host "would backup $target" }
        Write-Host "would link    $target -> $src"
        continue
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    if ($item) {
        Write-Host "backup  $target -> $target.bak-$Stamp"
        Move-Item -LiteralPath $target -Destination "$target.bak-$Stamp"
    }

    $isDir = Test-Path -LiteralPath $src -PathType Container
    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $src | Out-Null
        Write-Host "link    $target -> $src"
    } catch {
        if ($isDir) {
            New-Item -ItemType Junction -Path $target -Target $src | Out-Null
            Write-Host "junction $target -> $src"
        } else {
            Write-Error "Can't create file symlink $target. Enable Developer Mode or run as admin, then re-run."
        }
    }
}
