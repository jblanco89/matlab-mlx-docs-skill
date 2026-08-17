---
name: matlab-mlx-docs-skill
description: >
  Creates custom binary MATLAB Live Code (.mlx) documents programmatically
  for MATLAB R2024a by authoring the OPC/WordprocessingML package directly —
  text, headings, LaTeX equations, code cells, and embedded images — then
  packing, structurally verifying, and word-counting them with bundled
  PowerShell scripts. Use when the user asks to generate a .mlx report,
  paper, or notebook with equations and figures for MATLAB R2024a, or to
  build a .mlx without the Live Editor. Do NOT use for R2025a+ plain-text
  .m live scripts (use matlab-create-live-script).
metadata:
  author: jblanco
  version: "1.0"
---

# Write MLX Docs (custom)

Author binary MATLAB Live Code documents (.mlx) for MATLAB R2024a by hand-crafting the OPC package, then validate with the bundled PowerShell scripts. Every step and gotcha below was empirically verified on MATLAB R2024a Update 6.

## When to Use

- User wants a .mlx paper, report, or notebook with LaTeX equations and embedded figures
- User needs a .mlx for MATLAB R2016a–R2024a that cannot use the R2025a+ plain-text live format
- User wants reproducible, script-driven .mlx generation with verification

## When NOT to Use

- R2025a+ plain-text `.m` live scripts — use `matlab-create-live-script` (different format)
- Editing an existing .mlx in place — open/saveAs in MATLAB instead
- Regular `.m` scripts or function files

## Instructions

Follow the steps in order. Each step ends in a check you can re-run with the bundled scripts.

### Step 1: Plan the document

Define: title, sections, equations (LaTeX source), code cells, image files, and references. Respect the word budget: body text ≤ 1000 words, excluding references, code cell, equations, and images (headings/captions count).

### Step 2: Author `matlab/document.xml`

WordprocessingML in the `w` namespace. One `<w:p>` per block. See `references/mlx-format.md` for exact markup:

- Title: `<w:pPr><w:pStyle w:val="title"/></w:pPr>`
- Text: `<w:pStyle w:val="text"/>` (+ optional `<w:jc w:val="center"/>`)
- H1 heading: `<w:pStyle w:val="heading"/>`
- H2 heading: `<w:pStyle w:val="heading2"/>` wrapped in `mc:AlternateContent` with `Requires="R2018b"` and an `mc:Fallback` to `heading` (do not copy this by hand — copy the exact block from `references/mlx-format.md`)
- Equation: `<w:customXml w:element="equation">` with `<w:attr w:name="displayStyle" w:val="true"/>` and LaTeX in `<w:t>`
- Image: `<w:customXml w:element="image">` with `height`, `width`, `verticalAlign`, `altText`, `relationshipId` attrs
- Code cell: `<w:pStyle w:val="code"/>` with `<w:t><![CDATA[...]]></w:t>`
- Trailing section break: `<w:p><w:pPr><w:sectPr/></w:pPr></w:p>`

Use literal-text tools (Write/Edit) — never Bash heredocs, which collapse `\\` to `\` and corrupt LaTeX. Escape XML entities (`<`, `>`, `&`) in body text.

**CRITICAL**: The entire `matlab/document.xml` MUST be a **single line** after the XML declaration (no newlines between `<w:p>` elements). MATLAB R2024a's Live Editor importer silently discards content if newlines are present between paragraphs — the file opens but `saveAs` produces an empty 235-byte shell. Use literal-text tools (Write/Edit) with no newline separators; never Bash heredocs or multi-line writes. Escape XML entities (`<`, `>`, `&`) in body text.

### Step 3: Assemble the package

Copy the skeleton from `assets/package-skeleton/`, then:
- Place your authored `matlab/document.xml`
- Put images at `media/image1.png`, `media/image2.png`, ...
- Add one `<Relationship>` per image in `matlab/_rels/document.xml.rels`, with INCREMENTING Ids starting at `rId10` (`rId10`, `rId11`, ...) and matching `Target="../media/imageN.png"` and `Type="http://schemas.mathworks.com/matlab/code/2013/relationships/image"`
- Keep exactly 3 metadata files: `metadata/coreProperties.xml`, `metadata/mwcoreProperties.xml`, `metadata/mwcorePropertiesExtension.xml`

CRITICAL: do NOT add `metadata/mwcorePropertiesReleaseInfo.xml` — a heading plus that R2019b file hangs the R2024a editor with `MATLAB:Editor:Document:OpenLoadTimeout`. MATLAB re-adds it harmlessly on saveAs.

### Step 4: Pack

Run:

```powershell
powershell scripts/pack-mlx.ps1 -SourceDir <package-folder> -OutputMlx <out.mlx>
```

Zip entry names MUST use forward slashes. The script enforces this. If `<out.mlx>` already exists, pass `-Force` to overwrite it — never point `-OutputMlx` at a file outside the user's workspace, and never run the script against a `-SourceDir` outside the workspace without explicit user confirmation.

### Step 5: Verify structure

Run:

```powershell
powershell scripts/verify-mlx.ps1 -MlxPath <out.mlx>
```

Confirms: valid zip, forward-slash entries, required files present, ReleaseInfo absent, correct Content_Types overrides and .rels, well-formed XML (no DTD/XXE), unique image rels that resolve, and element counts (title/heading/heading2/text/code/equation/image/sectPr).

To inspect an existing `.mlx` (e.g. to edit or diagnose one), unpack it first:

```powershell
powershell scripts/unpack-mlx.ps1 -MlxPath in.mlx -DestDir <folder>   # add -Force to overwrite a non-empty folder
```

`unpack-mlx.ps1` refuses to overwrite an existing non-empty `-DestDir` without `-Force`, and rejects zip entries that try to escape the destination (zip-slip).

### Step 6: Count words

Run:

```powershell
powershell scripts/count-words.ps1 -DocumentXml <package-folder>\matlab\document.xml
```

Confirms body ≤ 1000 words, excluding code cell, equations, images, and the references section.

### Step 7: Open in MATLAB and normalize (if MATLAB is attached)

```matlab
ed = matlab.desktop.editor.openDocument('path\out.mlx');  % must open fast (< ~1 s)
disp(numel(ed.Text));                                      % code cell text
ed.saveAs('path\normalized.mlx'); ed.closeNoPrompt;
```

The saveAs round-trip normalizes the package (renumbered rels, ReleaseInfo re-added). Deliver the normalized copy. If `openDocument` hangs, fix the package per Troubleshooting.

## Examples

### Example 1: Minimal paper

User: "Crea un .mlx con título, una ecuación y una figura."

Actions: author document.xml (title → equation `\frac{dx}{dt} = \sigma (y - x)` → image), assemble package with 1 image, pack, verify, count words, open+saveAs in MATLAB.

Result: a valid .mlx that opens in the R2024a Live Editor showing the rendered equation and figure.

## Common Issues

### MATLAB:Editor:Document:OpenLoadTimeout (hang on open)

Cause: `metadata/mwcorePropertiesReleaseInfo.xml` present together with any heading.

Solution: delete that file from the package and repack (keep 3-metadata skeleton).

### Modal dialog / hang after `sim` or open

Cause: backslash in a zip entry name (`matlab\document.xml`).

Solution: repack with `pack-mlx.ps1` (forward slashes) and re-verify.

### Images don't show

Cause: `relationshipId` in document.xml doesn't match the `Id` in `matlab/_rels/document.xml.rels`, or `Target` wrong.

Solution: check `verify-mlx.ps1` output for unresolved image rels.

### Word count over budget

Cause: references/equations/code counted.

Solution: `count-words.ps1` excludes those categories; trim prose to ≤ 1000 body words.

### Empty document after saveAs (content silently dropped)

Cause: `matlab/document.xml` contains newlines between `<w:p>` elements. MATLAB R2024a's Live Editor importer requires the entire document body to be a single line after the XML declaration. If newlines are present, the file opens but content is silently discarded — `saveAs` yields an empty 235-byte shell.

Solution: ensure `matlab/document.xml` is a single line (XML declaration on line 1, all body content on line 2). Use Write/Edit tools with no newline separators; avoid multi-line writes or Bash heredocs. Verify with `verify-mlx.ps1` and a quick open+saveAs test.

## Checklist

- [ ] `pack-mlx.ps1` succeeds (forward slashes)
- [ ] `verify-mlx.ps1` all PASS (no ReleaseInfo, counts sane)
- [ ] `count-words.ps1` body ≤ 1000 words
- [ ] Opens fast in MATLAB; `saveAs` round-trip delivered

## Path safety

- Keep `-OutputMlx`/`-DestDir`/`-SourceDir` inside the user's workspace unless they explicitly ask otherwise
- `unpack-mlx.ps1` refuses to overwrite an existing non-empty `-DestDir` unless `-Force` is given (with `-Force` it deletes that directory's contents — confirm before doing so)
- `pack-mlx.ps1` refuses to overwrite an existing `-OutputMlx` unless `-Force` is given
- `verify-mlx.ps1` and `count-words.ps1` are read-only; `count-words.ps1` rejects `document.xml` files containing a `<!DOCTYPE>` (XXE risk)
- Relative paths resolve against the caller's current directory — prefer absolute workspace paths

## References

- `references/mlx-format.md` — exact OPC/WordprocessingML markup, copied blocks for heading2/equation/image
- `references/version-compat.md` — which .mlx features need which MATLAB release

---

Copyright 2026 Javier Blanco

---