$tocFile = Get-ChildItem (Join-Path $PSScriptRoot "src") -Filter "*.toc" | Select-Object -First 1

if (-not $tocFile) {
    Write-Error "No .toc file found in src"
    exit 1
}

$addonName = $tocFile.BaseName
$tocContent = Get-Content $tocFile.FullName -Raw

if ($tocContent -match '## Version:\s*(.+)') {
    $version = $Matches[1].Trim()
} else {
    Write-Error "Could not parse version from $($tocFile.Name)"
    exit 1
}

$zipName = "${addonName}_$version.zip"
$zipPath = Join-Path $PSScriptRoot $zipName
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "${addonName}_release_$(Get-Random)"
$stageDir = Join-Path $tempDir $addonName

try {
    Copy-Item (Join-Path $PSScriptRoot "src") $stageDir -Recurse

    if (Test-Path $zipPath) {
        Remove-Item $zipPath
    }

    Compress-Archive -Path $stageDir -DestinationPath $zipPath
    Write-Host "Created $zipName (v$version)"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}
