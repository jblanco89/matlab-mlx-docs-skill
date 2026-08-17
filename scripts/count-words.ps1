# count-words.ps1
# Count body words in a .mlx document.xml, EXCLUDING:
#   - the references section (everything from a heading whose text mentions
#     "referencias" / "references" / "bibliografia" onward)
#   - code cells (pStyle="code", CDATA content)
#   - equations (customXml element="equation" -- LaTeX is not prose)
#   - images (customXml element="image" -- altText is not prose)
# Headings and captions DO count.
#
# Enforces the skill's body budget: <= 1000 words (default; override with -Budget).
# Exit code 0 if within budget, 1 otherwise.
#
# Usage:
#   powershell -File count-words.ps1 -DocumentXml path\to\matlab\document.xml
#   powershell -File count-words.ps1 -DocumentXml ... -Budget 1200

param(
    [Parameter(Mandatory=$true)][string]$DocumentXml,
    [int]$Budget = 1000
)
$ErrorActionPreference = 'Stop'

$path = (Resolve-Path -LiteralPath $DocumentXml).Path
$doc = New-Object System.Xml.XmlDocument
$doc.XmlResolver = $null
if ((Get-Content -LiteralPath $path -Raw).Contains('<!DOCTYPE')) {
    Write-Error 'DOCTYPE forbidden (XXE risk) in document.xml'
    exit 1
}
$doc.Load($path)
$ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
$ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
$ns.AddNamespace('mc', 'http://schemas.openxmlformats.org/markup-compatibility/2006')

function Get-ParaStyle($p) {
    $style = $p.SelectSingleNode('./w:pPr/w:pStyle', $ns)
    if ($null -ne $style) { return $style.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') }
    # heading2 keeps pStyle inside mc:AlternateContent -- fetch it
    $alt = $p.SelectSingleNode('./mc:AlternateContent/mc:Choice/w:pPr/w:pStyle', $ns)
    if ($null -ne $alt) { return $alt.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') }
    return ''
}

function Get-ParaText($p) {
    # All w:t descendant text nodes of the paragraph, excluding equation/image
    # customXml subtrees and anything under mc:Fallback (rendered on old MATLAB).
    $sb = New-Object System.Text.StringBuilder
    foreach ($t in $p.SelectNodes('.//w:t', $ns)) {
        $node = $t
        $skip = $false
        while ($null -ne $node -and $node -ne $p) {
            $nodeName = $node.LocalName
            $nodeAttr = ''
            if ($node -is [System.Xml.XmlElement]) {
                $nodeAttr = $node.GetAttribute('element', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
            }
            if ($nodeName -eq 'customXml' -and ($nodeAttr -eq 'equation' -or $nodeAttr -eq 'image')) { $skip = $true; break }
            if ($nodeName -eq 'Fallback') { $skip = $true; break }
            $node = $node.ParentNode
        }
        if (-not $skip) { [void]$sb.Append($t.InnerText); [void]$sb.Append(' ') }
    }
    return $sb.ToString()
}

$total = 0
$inReferences = $false
$refHeadings = 0
$codeWords = 0
$paras = $doc.SelectNodes('//w:body/*', $ns)

foreach ($p in $paras) {
    if ($p.LocalName -ne 'p') { continue }
    $style = Get-ParaStyle $p
    $text = Get-ParaText $p
    $trimmed = $text.Trim()

    # Detect references heading before counting it.
    if (-not $inReferences -and ($style -eq 'heading' -or $style -eq 'heading2' -or $style -eq 'title') `
        -and $trimmed -match '(?i)^\s*(referencias|references|bibliograf|bibliography)\b') {
        $inReferences = $true
        $refHeadings++
        continue
    }
    if ($inReferences) { continue }

    if ($style -eq 'code') {
        $codeWords += ($trimmed -split '\s+' | Where-Object { $_ -ne '' }).Count
        continue
    }
    $n = ($trimmed -split '\s+' | Where-Object { $_ -ne '' }).Count
    $total += $n
}

Write-Host "Body words (excl. code/equations/images/references): $total"
Write-Host "Code-cell words excluded: $codeWords"
Write-Host "References headings detected: $refHeadings"
Write-Host "Budget: $Budget"
if ($total -le $Budget) {
    Write-Host "RESULT: PASS (within budget)"
    exit 0
} else {
    Write-Host "RESULT: FAIL (over budget by $($total - $Budget) words)"
    exit 1
}