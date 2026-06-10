function prompt {
    $host.UI.RawUI.WindowTitle = Split-Path -Leaf (Get-Location)
    $lastDuration = (Get-History -Count 1).Duration
    $durationStr = ""
    if ($lastDuration) {
        $ms = [int]$lastDuration.TotalMilliseconds
        if ($ms -ge 60000) {
            $durationStr = "{0}m{1}s" -f [int]($ms/60000), [int](($ms%60000)/1000)
        } elseif ($ms -ge 1000) {
            $durationStr = "{0}.{1}s" -f [int]($ms/1000), ($ms%1000).ToString().PadLeft(3,'0')
        } else {
            $durationStr = "{0}ms" -f $ms
        }
    }

    $path = $PWD.Path
    $width = $Host.UI.RawUI.WindowSize.Width
    $spacer = " " * ($width - $path.Length - $durationStr.Length)

    Write-Host $path -NoNewLine -ForegroundColor Green
    Write-Host "$spacer$durationStr" -ForegroundColor White
    return "> "
}

function devshell {
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsInstallPath = & $vsWhere -latest -property installationPath
    $devShellDll = Join-Path $vsInstallPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"

    Import-Module $devShellDll
    Enter-VsDevShell -VsInstallPath $vsInstallPath -SkipAutomaticLocation -DevCmdArguments '-arch=x64'
}

Set-PSReadLineOption -Colors @{ Parameter = "`e[33m" }
$PSStyle.FileInfo.Directory = "`e[1;38;2;179;222;239m"
$PSStyle.FileInfo.SymbolicLink = "`e[3;38;255;255;255;100m"

Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Chord "Alt+f" -Function ForwardWord

