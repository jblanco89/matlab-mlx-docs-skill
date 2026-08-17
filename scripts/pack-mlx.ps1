# pack-mlx.ps1
# Pack a folder into a valid MATLAB Live Code (.mlx) OPC zip.
# CRITICAL: zip entry names MUST use forward slashes; backslashes make MATLAB
# hang with a modal dialog. This script enforces forward slashes.
#
# Usage:
#   powershell -File pack-mlx.ps1 -SourceDir C:\path\to\pkg -OutputMlx out.mlx

param(
    [Parameter(Mandatory=$true)][string]$SourceDir,
    [Parameter(Mandatory=$true)][string]$OutputMlx,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src = (Resolve-Path -LiteralPath $SourceDir).Path
if (-not $OutputMlx.EndsWith('.mlx')) { $OutputMlx = $OutputMlx + '.mlx' }
if (-not [System.IO.Path]::IsPathRooted($OutputMlx)) {
    $OutputMlx = Join-Path (Get-Location) $OutputMlx
}

$required = @(
    '[Content_Types].xml',
    '_rels\.rels',
    'matlab\document.xml',
    'matlab\output.xml',
    'metadata\coreProperties.xml',
    'metadata\mwcoreProperties.xml',
    'metadata\mwcorePropertiesExtension.xml'
)
foreach ($r in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $r))) {
        Write-Error "Missing required file: $r"
        exit 1
    }
}

$corePropsPath = Join-Path $src 'metadata\coreProperties.xml'
if (Test-Path -LiteralPath $corePropsPath) {
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd') + 'T00:00:00Z'
    $xml = Get-Content -LiteralPath $corePropsPath -Raw
    $xml = $xml -replace '(\d{4}-\d{2}-\d{2})T00:00:00Z', $now
    Set-Content -LiteralPath $corePropsPath -Value $xml -NoNewline -Encoding UTF8
}

if (Test-Path -LiteralPath $OutputMlx) {
    if (-not $Force) {
        Write-Error "Output already exists: $OutputMlx. Pass -Force to overwrite."
        exit 1
    }
    Remove-Item -LiteralPath $OutputMlx -Force
}

$zip = [System.IO.Compression.ZipFile]::Open($OutputMlx, 'Create')
try {
    Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length).TrimStart('\').Replace('\','/')
        $entry = $zip.CreateEntry($rel, 'Optimal')
        $in = $_.OpenRead()
        $out = $entry.Open()
        try { $in.CopyTo($out) } finally { $out.Dispose(); $in.Dispose() }
    }
} finally {
    $zip.Dispose()
}

Write-Host "Packed: $OutputMlx"
Write-Host "Entries:" (Get-ChildItem -LiteralPath $src -Recurse -File).Count