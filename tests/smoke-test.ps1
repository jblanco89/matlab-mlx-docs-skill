# smoke-test.ps1
# End-to-end smoke test: copies skeleton, authors a minimal document.xml,
# runs pack → verify → count, then reports pass/fail.
#
# Usage:
#   powershell -File tests/smoke-test.ps1

param(
    [string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)
$ErrorActionPreference = 'Stop'
$failed = $false

function Step([string]$name, [scriptblock]$block) {
    Write-Host "`n--- $name ---" -ForegroundColor Cyan
    try { & $block }
    catch { Write-Host "FAIL: $_" -ForegroundColor Red; $script:failed = $true }
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("smoke-" + [guid]::NewGuid().ToString('N').Substring(0,8))
$pkgDir = Join-Path $tmpDir 'pkg'
$mlxOut = Join-Path $tmpDir 'smoke.mlx'

try {
    # ── Setup: copy skeleton ──
    Step 'Setup: copy skeleton' {
        Copy-Item -LiteralPath (Join-Path $SkillRoot 'assets\package-skeleton') -Destination $pkgDir -Recurse
        Write-Host "Copied skeleton to $pkgDir"
    }

    # ── Author minimal document.xml ──
    Step 'Author document.xml' {
        $docXml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
            '<w:body>' +
            '<w:p><w:pPr><w:pStyle w:val="title"/><w:jc w:val="left"/></w:pPr><w:r><w:t>Smoke Test</w:t></w:r></w:p>' +
            '<w:p><w:pPr><w:pStyle w:val="heading"/><w:jc w:val="left"/></w:pPr><w:r><w:t>1. Introduction</w:t></w:r></w:p>' +
            '<w:p><w:pPr><w:pStyle w:val="text"/><w:jc w:val="left"/></w:pPr><w:r><w:t>This is a minimal test document.</w:t></w:r></w:p>' +
            '<w:p><w:pPr><w:pStyle w:val="text"/><w:jc w:val="center"/></w:pPr><w:customXml w:element="equation"><w:customXmlPr><w:attr w:name="displayStyle" w:val="true"/></w:customXmlPr><w:r><w:t>E = mc^2</w:t></w:r></w:customXml></w:p>' +
            '<w:p><w:pPr><w:pStyle w:val="code"/></w:pPr><w:r><w:t><![CDATA[x = 42;
disp(x)]]></w:t></w:r></w:p>' +
            '<w:p><w:pPr><w:sectPr/></w:pPr></w:p>' +
            '</w:body></w:document>'
        Set-Content -LiteralPath (Join-Path $pkgDir 'matlab\document.xml') -Value $docXml -NoNewline -Encoding UTF8
        Write-Host "Wrote document.xml (single-line body)"
    }

    # ── Pack ──
    Step 'pack-mlx.ps1' {
        & (Join-Path $SkillRoot 'scripts\pack-mlx.ps1') -SourceDir $pkgDir -OutputMlx $mlxOut
        if (-not (Test-Path -LiteralPath $mlxOut)) { throw "Output file not created" }
    }

    # ── Verify ──
    Step 'verify-mlx.ps1' {
        $result = & (Join-Path $SkillRoot 'scripts\verify-mlx.ps1') -MlxPath $mlxOut 2>&1
        $result | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "verify-mlx.ps1 exited with code $LASTEXITCODE" }
    }

    # ── Count words ──
    Step 'count-words.ps1' {
        $docPath = Join-Path $pkgDir 'matlab\document.xml'
        $result = & (Join-Path $SkillRoot 'scripts\count-words.ps1') -DocumentXml $docPath -Budget 1000 2>&1
        $result | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "count-words.ps1 exited with code $LASTEXITCODE" }
    }

} finally {
    # ── Cleanup ──
    if (Test-Path -LiteralPath $tmpDir) {
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`nCleaned up $tmpDir"
    }
}

# ── Summary ──
Write-Host "`n==============================" -ForegroundColor Cyan
if ($failed) {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: PASS" -ForegroundColor Green
    exit 0
}
