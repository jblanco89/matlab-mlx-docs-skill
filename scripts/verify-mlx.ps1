# verify-mlx.ps1
# Structural verification of a .mlx package. Re-runs the skill's inherent checks:
#   - valid OPC zip with forward-slash entry names
#   - all required entries present
#   - metadata/mwcorePropertiesReleaseInfo.xml ABSENT (R2019b file that hangs
#     the R2024a editor with MATLAB:Editor:Document:OpenLoadTimeout when a
#     heading is present)
#   - [Content_Types].xml overrides / defaults correct
#   - _rels/.rels has the 5 expected relationships
#   - matlab/document.xml well-formed; element counts reported
#   - image relationships in matlab/_rels/document.xml.rels resolve
#
# Exit code 0 if all checks pass, 1 otherwise.
#
# Usage:
#   powershell -File verify-mlx.ps1 -MlxPath out.mlx

param(
    [Parameter(Mandatory=$true)][string]$MlxPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$mlx = (Resolve-Path -LiteralPath $MlxPath).Path
$pass = $true

# XXE/DTD hardening: resolve nothing external, reject entity-bearing documents.
function Load-XmlSafe([string]$text, [string]$what) {
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    if ($text -match '<!DOCTYPE') {
        Check "${what}: no DTD" $false 'DOCTYPE forbidden (XXE risk)'
        return $null
    }
    try {
        $doc.LoadXml($text)
        Check "${what}: well-formed XML" $true ''
    } catch {
        Check "${what}: well-formed XML" $false $_.Exception.Message
        return $null
    }
    return $doc
}
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) { Write-Host "[PASS] $name" }
    else { $script:pass = $false; Write-Host "[FAIL] $name -- $detail" }
}

if (-not (Test-Path -LiteralPath $mlx)) { Write-Error "Not found: $mlx"; exit 1 }

$zip = [System.IO.Compression.ZipFile]::OpenRead($mlx)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    Check 'Zip opens' ($names.Count -gt 0) 'empty archive'

    $bs = @($names | Where-Object { $_ -match '\\' })
    Check 'Forward-slash entry names (no backslashes)' ($bs.Count -eq 0) "found: $($bs -join ', ')"

    $required = @(
        '[Content_Types].xml',
        '_rels/.rels',
        'matlab/document.xml',
        'matlab/output.xml',
        'metadata/coreProperties.xml',
        'metadata/mwcoreProperties.xml',
        'metadata/mwcorePropertiesExtension.xml'
    )
    foreach ($r in $required) {
        Check "Entry present: $r" ($names -contains $r) 'missing'
    }

    Check 'No metadata/mwcorePropertiesReleaseInfo.xml' (-not ($names -contains 'metadata/mwcorePropertiesReleaseInfo.xml')) 'R2019b ReleaseInfo + heading hangs R2024a open'

    # --- [Content_Types].xml ---
    $ct = $zip.GetEntry('[Content_Types].xml')
    $ctXml = Load-XmlSafe (New-Object System.IO.StreamReader($ct.Open())).ReadToEnd() '[Content_Types].xml'
    $ns = New-Object System.Xml.XmlNamespaceManager($ctXml.NameTable)
    $ns.AddNamespace('t', 'http://schemas.openxmlformats.org/package/2006/content-types')

    $png = $ctXml.SelectSingleNode("//t:Default[@Extension='png']", $ns)
    Check 'Content_Types: image/png default' ($null -ne $png -and $png.GetAttribute('ContentType') -eq 'image/png') 'missing png Default'

    $overrides = @(
        '/matlab/output.xml',
        '/metadata/coreProperties.xml',
        '/metadata/mwcoreProperties.xml',
        '/metadata/mwcorePropertiesExtension.xml'
    )
    foreach ($ov in $overrides) {
        $node = $ctXml.SelectSingleNode("//t:Override[@PartName='$ov']", $ns)
        Check "Content_Types: Override $ov" ($null -ne $node) 'missing'
    }
    $relOv = $ctXml.SelectSingleNode("//t:Override[contains(@PartName,'ReleaseInfo')]", $ns)
    Check 'Content_Types: no ReleaseInfo override' ($null -eq $relOv) 'remove it'

    # --- _rels/.rels ---
    $rels = $zip.GetEntry('_rels/.rels')
    $relsXml = Load-XmlSafe (New-Object System.IO.StreamReader($rels.Open())).ReadToEnd() '_rels/.rels'
    $rns = New-Object System.Xml.XmlNamespaceManager($relsXml.NameTable)
    $rns.AddNamespace('r', 'http://schemas.openxmlformats.org/package/2006/relationships')
    $relList = $relsXml.SelectNodes('//r:Relationship', $rns)
    $expectedRels = @{
        'rId1' = 'http://schemas.mathworks.com/matlab/code/2013/relationships/document'
        'rId2' = 'http://schemas.mathworks.com/matlab/code/2013/relationships/output'
        'rId3' = 'http://schemas.mathworks.com/package/2012/relationships/coreProperties'
        'rId4' = 'http://schemas.mathworks.com/package/2014/relationships/corePropertiesExtension'
        'rId5' = 'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties'
    }
    foreach ($id in $expectedRels.Keys) {
        $rel = $relList | Where-Object { $_.GetAttribute('Id') -eq $id }
        Check "_rels/.rels: $id" ($null -ne $rel -and $rel.GetAttribute('Type') -eq $expectedRels[$id]) 'missing/wrong'
    }

# --- matlab/document.xml ---
        $docEntry = $zip.GetEntry('matlab/document.xml')
        $docText = (New-Object System.IO.StreamReader($docEntry.Open())).ReadToEnd()
        # Check single-line requirement: after XML declaration, all body content must be on one line
        $lines = $docText -split "`r?`n"
        $xmlDeclLines = $lines | Where-Object { $_ -match '^<\?xml' }
        if ($lines.Count -gt 2 -or ($lines.Count -eq 2 -and -not ($lines[0] -match '^<\?xml'))) {
            Check 'document.xml single-line body' $false "found $($lines.Count) lines; body must be single line after XML declaration"
        } else {
            Check 'document.xml single-line body' $true ''
        }
        $docXml = Load-XmlSafe $docText 'document.xml'
        if ($pass -and $null -ne $docXml) {
        $wns = New-Object System.Xml.XmlNamespaceManager($docXml.NameTable)
        $wns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
        $wns.AddNamespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')
        $count = @{}
        $count['title']   = $docXml.SelectNodes('//w:p[w:pPr/w:pStyle[@w:val="title"]]', $wns).Count
        $count['heading'] = $docXml.SelectNodes('//w:p[w:pPr/w:pStyle[@w:val="heading"]]', $wns).Count
        $count['heading2']= $docXml.SelectNodes('//w:p[mc:AlternateContent/mc:Choice/w:pPr/w:pStyle[@w:val="heading2"]]', $wns).Count
        $count['text']    = $docXml.SelectNodes('//w:p[w:pPr/w:pStyle[@w:val="text"]]', $wns).Count
        $count['code']    = $docXml.SelectNodes('//w:p[w:pPr/w:pStyle[@w:val="code"]]', $wns).Count
        $count['equation']= $docXml.SelectNodes('//w:customXml[@w:element="equation"]', $wns).Count
        $count['image']   = $docXml.SelectNodes('//w:customXml[@w:element="image"]', $wns).Count
        $count['sectPr']  = $docXml.SelectNodes('//w:sectPr', $wns).Count
        Write-Host ("[INFO] counts: " + (($count.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '))
        Check 'At least one title' ($count['title'] -ge 1) 'document should have a title'
        Check 'Trailing sectPr' ($count['sectPr'] -ge 1) 'document must end with a section-break paragraph'

        # --- image relationships resolve + Ids unique ---
        $imgRels = $zip.GetEntry('matlab/_rels/document.xml.rels')
        if ($null -eq $imgRels) {
            Check 'document.xml.rels present' $false 'missing matlab/_rels/document.xml.rels'
        } else {
            $imgRelsXml = Load-XmlSafe (New-Object System.IO.StreamReader($imgRels.Open())).ReadToEnd() 'document.xml.rels'
            $irns = New-Object System.Xml.XmlNamespaceManager($imgRelsXml.NameTable)
            $irns.AddNamespace('r', 'http://schemas.openxmlformats.org/package/2006/relationships')
            $imgRelList = @($imgRelsXml.SelectNodes('//r:Relationship', $irns))
            $dupIds = @($imgRelList | Group-Object { $_.GetAttribute('Id') } | Where-Object { $_.Count -gt 1 })
            Check 'Image rels: unique Ids' ($dupIds.Count -eq 0) "duplicates: $(($dupIds | ForEach-Object { $_.Name }) -join ', ')"
            $usedImgRels = @($docXml.SelectNodes('//w:customXml[@w:element="image"]/@relationshipId', $wns) | ForEach-Object { $_.Value })
            foreach ($rid in $usedImgRels) {
                Check "Image rel $rid declared in document.xml" ($imgRelList | Where-Object { $_.GetAttribute('Id') -eq $rid }) 'no matching Relationship in document.xml.rels'
            }
            foreach ($rel in $imgRelList) {
                $target = $rel.GetAttribute('Target')
                $mediaName = [System.IO.Path]::GetFileName($target.Replace('/','\'))
                $checkName = 'media/' + $mediaName
                Check "Image rel $($rel.GetAttribute('Id')) -> $checkName" ($names -contains $checkName) 'media file missing in zip'
            }
        }
    }
} finally {
    $zip.Dispose()
}

if ($pass) { Write-Host "RESULT: PASS -- $mlx" } else { Write-Host "RESULT: FAIL -- $mlx" }
exit $(if ($pass) { 0 } else { 1 })