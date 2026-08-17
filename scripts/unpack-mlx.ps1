# unpack-mlx.ps1
# Extract a .mlx file to a folder for inspection / editing / re-packing.
# Safety: will NOT delete an existing non-empty DestDir unless -Force is given,
# and validates every zip entry name to prevent zip-slip (CVE-2018-8421).
#
# Usage:
#   powershell -File unpack-mlx.ps1 -MlxPath in.mlx -DestDir out [-Force]

param(
    [Parameter(Mandatory=$true)][string]$MlxPath,
    [Parameter(Mandatory=$true)][string]$DestDir,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$mlx = (Resolve-Path -LiteralPath $MlxPath).Path

if (Test-Path -LiteralPath $DestDir) {
    $existing = Get-ChildItem -LiteralPath $DestDir -Force -ErrorAction SilentlyContinue
    if ($existing.Count -gt 0) {
        if (-not $Force) {
            Write-Error "DestDir exists and is not empty: $DestDir. Pass -Force to overwrite (deletes its contents)."
            exit 1
        }
        Remove-Item -LiteralPath $DestDir -Recurse -Force
    }
} else {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

# Zip-slip guard: reject any entry that could escape DestDir.
$zip = [System.IO.Compression.ZipFile]::OpenRead($mlx)
try {
    foreach ($entry in $zip.Entries) {
        $name = $entry.FullName
        if ($name -match '^[A-Za-z]:' -or $name -match '(^|/|\\)\.\.($|/)' -or $name.StartsWith('/') -or $name.StartsWith('\')) {
            Write-Error "Unsafe zip entry name rejected (zip-slip): $name"
            exit 1
        }
        $target = [System.IO.Path]::GetFullPath((Join-Path $DestDir $name.Replace('/', '\')))
        $root = [System.IO.Path]::GetFullPath($DestDir).TrimEnd('\') + '\'
        if (-not $target.StartsWith($root)) {
            Write-Error "Unsafe zip entry name rejected (outside DestDir): $name"
            exit 1
        }
    }
} finally {
    $zip.Dispose()
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($mlx, $DestDir)
Write-Host "Unpacked to: $DestDir"