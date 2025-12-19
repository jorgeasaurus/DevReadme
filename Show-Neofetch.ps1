<#
.SYNOPSIS
    Displays GitHub profile info in neofetch style with ASCII art.
.DESCRIPTION
    Renders ASCII art alongside profile information from config.ps1
    in a terminal-friendly neofetch format with ANSI colors.
.EXAMPLE
    .\Show-Neofetch.ps1
.EXAMPLE
    .\Show-Neofetch.ps1 -NoColor
#>

[CmdletBinding()]
param(
    [switch]$NoColor
)

$ErrorActionPreference = "Stop"

# ANSI color codes
$script:Colors = @{
    Reset   = "`e[0m"
    Bold    = "`e[1m"
    # Foreground
    Orange  = "`e[38;5;214m"
    Blue    = "`e[38;5;117m"
    Green   = "`e[38;5;114m"
    Red     = "`e[38;5;203m"
    Gray    = "`e[38;5;244m"
    White   = "`e[38;5;255m"
    Cyan    = "`e[38;5;81m"
    Yellow  = "`e[38;5;227m"
}

function Get-ColoredText {
    param(
        [string]$Text,
        [string]$Color
    )

    if ($NoColor) {
        return $Text
    }
    return "$($script:Colors[$Color])$Text$($script:Colors.Reset)"
}

function Get-DotJustifiedLine {
    param(
        [string]$Key,
        [string]$Value,
        [int]$TargetWidth = 50
    )

    $keyLen = $Key.Length + 1  # +1 for colon
    $valueLen = $Value.Length
    $dotsNeeded = $TargetWidth - $keyLen - $valueLen - 2

    if ($dotsNeeded -lt 1) { $dotsNeeded = 1 }

    return "." * $dotsNeeded
}

function Get-GitHubStatsFromSvg {
    param([string]$SvgPath)

    $stats = @{
        Repos     = "N/A"
        Contrib   = "N/A"
        Stars     = "N/A"
        Commits   = "N/A"
        Followers = "N/A"
        LOC       = "N/A"
        Additions = "N/A"
        Deletions = "N/A"
    }

    if (-not (Test-Path $SvgPath)) {
        return $stats
    }

    $content = Get-Content $SvgPath -Raw

    # Parse each stat from SVG using regex
    if ($content -match 'id="repo_data">([^<]+)<') {
        $stats.Repos = $Matches[1]
    }
    if ($content -match 'id="contrib_data">([^<]+)<') {
        $stats.Contrib = $Matches[1]
    }
    if ($content -match 'id="star_data">([^<]+)<') {
        $stats.Stars = $Matches[1]
    }
    if ($content -match 'id="commit_data">([^<]+)<') {
        $stats.Commits = $Matches[1]
    }
    if ($content -match 'id="follower_data">([^<]+)<') {
        $stats.Followers = $Matches[1]
    }
    if ($content -match 'id="loc_data">([^<]+)<') {
        $stats.LOC = $Matches[1]
    }
    if ($content -match 'id="loc_add">([^<]+)<') {
        $stats.Additions = $Matches[1]
    }
    if ($content -match 'id="loc_del">([^<]+)<') {
        $stats.Deletions = $Matches[1]
    }

    return $stats
}

function Show-Neofetch {
    [CmdletBinding()]
    param()

    # Load configuration
    $scriptDir = $PSScriptRoot
    $configPath = Join-Path $scriptDir "config.ps1"

    if (-not (Test-Path $configPath)) {
        throw "config.ps1 not found at: $configPath"
    }

    . $configPath

    # Load ASCII art
    $asciiPath = Join-Path $scriptDir $Config.AsciiArtFile
    if (-not (Test-Path $asciiPath)) {
        throw "ASCII art file not found at: $asciiPath"
    }

    $asciiLines = Get-Content $asciiPath

    # Load GitHub stats from SVG
    $svgPath = Join-Path $scriptDir $Config.OutputFiles.Dark
    $ghStats = Get-GitHubStatsFromSvg -SvgPath $svgPath

    # Calculate age
    $years = (Get-Date).Year - $Config.BirthYear
    $yearPlural = if ($years -ne 1) { "s" } else { "" }
    $ageValue = "$years year$yearPlural"

    # Build info lines
    $infoLines = @()

    # Header with username
    $separator = "-" * 50
    $infoLines += "$(Get-ColoredText $Config.Username 'Cyan')"
    $infoLines += Get-ColoredText $separator 'Gray'

    # Profile section
    foreach ($key in $Config.Profile.Keys) {
        if ($key -eq "Uptime" -or $null -eq $Config.Profile[$key]) {
            $displayKey = "Uptime"
            $value = $ageValue
        }
        else {
            $displayKey = $key
            $value = $Config.Profile[$key]
        }

        $dots = Get-DotJustifiedLine -Key $displayKey -Value $value
        $coloredKey = Get-ColoredText $displayKey 'Orange'
        $coloredDots = Get-ColoredText " $dots " 'Gray'
        $coloredValue = Get-ColoredText $value 'Blue'

        $infoLines += "$coloredKey`:$coloredDots$coloredValue"
    }

    # Blank line before contact
    $infoLines += ""
    $infoLines += Get-ColoredText "- Contact $('-' * 40)" 'White'

    # Contact section
    foreach ($key in $Config.Contact.Keys) {
        $value = $Config.Contact[$key]
        $dots = Get-DotJustifiedLine -Key $key -Value $value
        $coloredKey = Get-ColoredText $key 'Orange'
        $coloredDots = Get-ColoredText " $dots " 'Gray'
        $coloredValue = Get-ColoredText $value 'Blue'

        $infoLines += "$coloredKey`:$coloredDots$coloredValue"
    }

    # Blank line before GitHub stats
    $infoLines += ""
    $infoLines += Get-ColoredText "- GitHub Stats $('-' * 35)" 'White'

    # GitHub stats from SVG data
    $stats = @(
        @{ Key = "Repos"; Value = $ghStats.Repos }
        @{ Key = "Contributed"; Value = $ghStats.Contrib }
        @{ Key = "Stars"; Value = $ghStats.Stars }
        @{ Key = "Commits"; Value = $ghStats.Commits }
        @{ Key = "Followers"; Value = $ghStats.Followers }
    )

    foreach ($stat in $stats) {
        $dots = Get-DotJustifiedLine -Key $stat.Key -Value $stat.Value
        $coloredKey = Get-ColoredText $stat.Key 'Orange'
        $coloredDots = Get-ColoredText " $dots " 'Gray'
        $coloredValue = Get-ColoredText $stat.Value 'Blue'

        $infoLines += "$coloredKey`:$coloredDots$coloredValue"
    }

    # Lines of code with additions/deletions on separate line
    $locLabel = "Lines of Code"
    $locValue = $ghStats.LOC
    $dots = Get-DotJustifiedLine -Key $locLabel -Value $locValue
    $coloredKey = Get-ColoredText $locLabel 'Orange'
    $coloredDots = Get-ColoredText " $dots " 'Gray'
    $coloredValue = Get-ColoredText $locValue 'Blue'

    $infoLines += "$coloredKey`:$coloredDots$coloredValue"

    # Additions/deletions on their own line, indented
    $addDelLabel = "  (+/-)"
    $addDelValue = "$($ghStats.Additions)++, $($ghStats.Deletions)--"
    $addDelDots = Get-DotJustifiedLine -Key $addDelLabel -Value $addDelValue
    $coloredAddDelKey = Get-ColoredText $addDelLabel 'Gray'
    $coloredAddDelDots = Get-ColoredText " $addDelDots " 'Gray'
    $coloredAdd = Get-ColoredText "$($ghStats.Additions)++" 'Green'
    $coloredDel = Get-ColoredText "$($ghStats.Deletions)--" 'Red'

    $infoLines += "$coloredAddDelKey`:$coloredAddDelDots$coloredAdd, $coloredDel"

    # Color palette line
    $infoLines += ""
    $palette = ""
    foreach ($i in 0..7) {
        $palette += "`e[48;5;${i}m   "
    }
    $palette += "`e[0m"
    $infoLines += $palette

    # Combine ASCII art with info
    $maxAsciiWidth = ($asciiLines | Measure-Object -Property Length -Maximum).Maximum
    $padding = 4  # Space between ASCII and info

    $totalLines = [Math]::Max($asciiLines.Count, $infoLines.Count)

    Write-Host ""
    for ($i = 0; $i -lt $totalLines; $i++) {
        $asciiLine = if ($i -lt $asciiLines.Count) { $asciiLines[$i] } else { "" }
        $infoLine = if ($i -lt $infoLines.Count) { $infoLines[$i] } else { "" }

        # Colorize ASCII art (using cyan for the art)
        $coloredAscii = if ($NoColor) {
            $asciiLine.PadRight($maxAsciiWidth)
        }
        else {
            $asciiLine = $asciiLine -replace '#', "$(Get-ColoredText '#' 'Cyan')"
            $asciiLine = $asciiLine -replace '\+', "$(Get-ColoredText '+' 'Blue')"
            $asciiLine = $asciiLine -replace '\.', "$(Get-ColoredText '.' 'Gray')"
            $asciiLine = $asciiLine -replace '-', "$(Get-ColoredText '-' 'Gray')"
            # Pad to align
            $rawLen = ($asciiLines[$i] ?? "").Length
            $padNeeded = $maxAsciiWidth - $rawLen
            $asciiLine + (" " * [Math]::Max(0, $padNeeded))
        }

        Write-Host "$coloredAscii$(' ' * $padding)$infoLine"
    }
    Write-Host ""
}

# Run if executed directly
Show-Neofetch
