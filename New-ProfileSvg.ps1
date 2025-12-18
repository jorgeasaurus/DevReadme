# New-ProfileSvg.ps1
# Generates dark_mode.svg and light_mode.svg from config.ps1
# Run this script once to create your SVG templates, then use today.ps1 to update dynamic stats

$ErrorActionPreference = "Stop"

# Load configuration
if (Test-Path ".\config.ps1") {
    . .\config.ps1
}
else {
    throw "config.ps1 not found! Please create it from the template."
}

function Get-DotJustifiedLine {
    param(
        [string]$Key,
        [string]$Value,
        [int]$TargetWidth = 56
    )

    $keyLen = $Key.Length + 1  # +1 for colon
    $valueLen = $Value.Length
    $dotsNeeded = $TargetWidth - $keyLen - $valueLen - 2  # -2 for spaces around dots

    if ($dotsNeeded -lt 1) { $dotsNeeded = 1 }

    return "." * $dotsNeeded
}

function Get-AsciiArtLines {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        Write-Warning "ASCII art file not found: $FilePath"
        return @()
    }

    return Get-Content $FilePath
}

function New-SvgDocument {
    param(
        [hashtable]$Colors,
        [string]$Mode  # "Dark" or "Light"
    )

    $c = $Colors
    $layout = $Config.Layout
    $targetWidth = $layout.TargetWidth

    # Calculate age from birth year
    $years = (Get-Date).Year - $Config.BirthYear
    $yearPlural = if ($years -ne 1) { "s" } else { "" }
    $ageValue = "$years year$yearPlural"

    # Build SVG header and styles
    $svg = @"
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" font-family="ConsolasFallback,Consolas,monospace" width="$($layout.Width)px" height="$($layout.Height)px" font-size="$($layout.FontSize)px">
  <style>
@font-face {
src: local('Consolas'), local('Consolas Bold');
font-family: 'ConsolasFallback';
font-display: swap;
-webkit-size-adjust: 109%;
size-adjust: 109%;
}
.key {fill: $($c.Key);}
.value {fill: $($c.Value);}
.addColor {fill: $($c.AddColor);}
.delColor {fill: $($c.DelColor);}
.cc {fill: $($c.Dots);}
text, tspan {white-space: pre;}
</style>
  <rect width="$($layout.Width)px" height="$($layout.Height)px" fill="$($c.Background)" rx="15" />
"@

    # Add ASCII art section
    $asciiLines = Get-AsciiArtLines -FilePath $Config.AsciiArtFile
    $svg += "`n  <text x=`"$($layout.AsciiX)`" y=`"30`" fill=`"$($c.Text)`" class=`"ascii`">"

    $y = 30
    foreach ($line in $asciiLines) {
        $escapedLine = $line -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
        $svg += "`n    <tspan x=`"$($layout.AsciiX)`" y=`"$y`">$escapedLine</tspan>"
        $y += $layout.LineHeight
    }
    $svg += "`n  </text>"

    # Build content section
    $contentX = $layout.ContentX
    $svg += "`n  <text x=`"$contentX`" y=`"30`" fill=`"$($c.Text)`">"

    # Username header
    $emDash = [char]0x2014
    $svg += "`n    <tspan x=`"$contentX`" y=`"30`">$($Config.Username)</tspan> -"
    $svg += ($emDash.ToString() * 43)  # em-dashes for separator
    $svg += "-"
    $svg += $emDash
    $svg += "-"

    # Profile section
    $y = 50
    foreach ($key in $Config.Profile.Keys) {
        if ($key -eq "Uptime" -or $null -eq $Config.Profile[$key]) {
            # Dynamic field - Uptime/Age
            $dots = Get-DotJustifiedLine -Key "Uptime" -Value $ageValue -TargetWidth $targetWidth
            $svg += "<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
            $svg += "<tspan class=`"key`">Uptime</tspan>:"
            $svg += "<tspan class=`"cc`" id=`"age_data_dots`"> $dots </tspan>"
            $svg += "<tspan class=`"value`" id=`"age_data`">$ageValue</tspan>"
        }
        elseif ($key -eq "Languages.Programming") {
            # Special formatting for Languages.Programming
            $value = $Config.Profile[$key]
            $dots = Get-DotJustifiedLine -Key $key -Value $value -TargetWidth $targetWidth
            $svg += "<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
            $svg += "<tspan class=`"key`">Languages</tspan>.<tspan class=`"key`">Programming</tspan>:"
            $svg += "<tspan class=`"cc`"> $dots </tspan>"
            $svg += "<tspan class=`"value`">$value</tspan>"
        }
        else {
            # Regular profile field
            $value = $Config.Profile[$key]
            $dots = Get-DotJustifiedLine -Key $key -Value $value -TargetWidth $targetWidth
            $svg += "<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
            $svg += "<tspan class=`"key`">$key</tspan>:"
            $svg += "<tspan class=`"cc`"> $dots </tspan>"
            $svg += "<tspan class=`"value`">$value</tspan>"
        }
        $y += $layout.LineHeight
    }

    # Contact section header
    $y += $layout.LineHeight  # Add gap before Contact
    $svg += "<tspan x=`"$contentX`" y=`"$y`">- Contact</tspan> -"
    $svg += ($emDash.ToString() * 46)
    $svg += "-"
    $svg += $emDash
    $svg += "-"
    $y += $layout.LineHeight

    # Contact items
    foreach ($key in $Config.Contact.Keys) {
        $value = $Config.Contact[$key]
        $dots = Get-DotJustifiedLine -Key $key -Value $value -TargetWidth $targetWidth
        $svg += "`n<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
        $svg += "<tspan class=`"key`">$key</tspan>:"
        $svg += "<tspan class=`"cc`"> $dots </tspan>"
        $svg += "<tspan class=`"value`">$value</tspan>"
        $y += $layout.LineHeight
    }

    # GitHub Stats section header
    $y += $layout.LineHeight  # Add gap before GitHub Stats
    $svg += "<tspan x=`"$contentX`" y=`"$y`">- GitHub Stats</tspan> -"
    $svg += ($emDash.ToString() * 41)
    $svg += "-"
    $svg += $emDash
    $svg += "-"
    $y += $layout.LineHeight

    # GitHub Stats - Repos and Stars line
    $svg += "`n<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
    $svg += "<tspan class=`"key`">Repos</tspan>:"
    $svg += "<tspan class=`"cc`" id=`"repo_data_dots`"> .... </tspan>"
    $svg += "<tspan class=`"value`" id=`"repo_data`">0</tspan>"
    $svg += " {<tspan class=`"key`">Contributed</tspan>: <tspan class=`"value`" id=`"contrib_data`">0</tspan>}"
    $svg += " | <tspan class=`"key`">Stars</tspan>:"
    $svg += "<tspan class=`"cc`" id=`"star_data_dots`"> ........... </tspan>"
    $svg += "<tspan class=`"value`" id=`"star_data`">0</tspan>"
    $y += $layout.LineHeight

    # GitHub Stats - Commits and Followers line
    $svg += "<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
    $svg += "<tspan class=`"key`">Commits</tspan>:"
    $svg += "<tspan class=`"cc`" id=`"commit_data_dots`"> ..................... </tspan>"
    $svg += "<tspan class=`"value`" id=`"commit_data`">0</tspan>"
    $svg += " | <tspan class=`"key`">Followers</tspan>:"
    $svg += "<tspan class=`"cc`" id=`"follower_data_dots`"> ........ </tspan>"
    $svg += "<tspan class=`"value`" id=`"follower_data`">0</tspan>"
    $y += $layout.LineHeight

    # GitHub Stats - Lines of Code line
    $svg += "<tspan x=`"$contentX`" y=`"$y`" class=`"cc`">. </tspan>"
    $svg += "<tspan class=`"key`">Lines of Code on GitHub</tspan>:"
    $svg += "<tspan class=`"cc`" id=`"loc_data_dots`"> ........ </tspan>"
    $svg += "<tspan class=`"value`" id=`"loc_data`">0</tspan>"
    $svg += " ( <tspan class=`"addColor`" id=`"loc_add`">0</tspan><tspan class=`"addColor`">++</tspan>,"
    $svg += " <tspan id=`"loc_del_dots`"> ...... </tspan>"
    $svg += "<tspan class=`"delColor`" id=`"loc_del`">0</tspan><tspan class=`"delColor`">--</tspan> )"

    # Close text and SVG
    $svg += "`n</text>`n</svg>`n"

    return $svg
}

# Generate both SVG files
Write-Host "Generating SVG files from config..."

# Dark mode
$darkSvg = New-SvgDocument -Colors $Config.Colors.Dark -Mode "Dark"
$darkSvg | Set-Content -Path $Config.OutputFiles.Dark -Encoding UTF8
Write-Host "  Created: $($Config.OutputFiles.Dark)"

# Light mode
$lightSvg = New-SvgDocument -Colors $Config.Colors.Light -Mode "Light"
$lightSvg | Set-Content -Path $Config.OutputFiles.Light -Encoding UTF8
Write-Host "  Created: $($Config.OutputFiles.Light)"

Write-Host "`nDone! Run today.ps1 to update GitHub statistics."
