# MLX package format (OPC / WordprocessingML)

A `.mlx` file is a ZIP (OPC) container. Entry names MUST use forward slashes.
Verified on MATLAB R2024a Update 6.

## Package layout

```
[Content_Types].xml
_rels/.rels
matlab/document.xml      <- the document (WordprocessingML)
matlab/output.xml        <- embedded output state
matlab/_rels/document.xml.rels   <- image relationships
media/image1.png, image2.png, ...
metadata/coreProperties.xml
metadata/mwcoreProperties.xml
metadata/mwcorePropertiesExtension.xml
```

Use exactly these 3 metadata files. Do NOT add `metadata/mwcorePropertiesReleaseInfo.xml`.

## `[Content_Types].xml`

Defaults: `rels`, `xml` (as `application/vnd.mathworks.matlab.code.document+xml`), `png`.
Overrides: `/matlab/output.xml`, `/metadata/coreProperties.xml`,
`/metadata/mwcoreProperties.xml`, `/metadata/mwcorePropertiesExtension.xml`.
No ReleaseInfo override. (Template in `assets/package-skeleton/`.)

## `_rels/.rels`

Exactly 5 relationships: document, output, mwcoreProperties, mwcorePropertiesExtension,
coreProperties (see template). No `.../2019/relationships/corePropertiesReleaseInfo`.

## `matlab/_rels/document.xml.rels`

Image relationships, Ids starting at `rId10`:

```xml
<Relationship Id="rId10" Target="../media/image1.png" Type="http://schemas.mathworks.com/matlab/code/2013/relationships/image"/>
```

## `matlab/document.xml`

Root: `<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">`.
Body children are `<w:p>` paragraphs in order. Namespaces: `w` and `mc`.

**CRITICAL**: The entire document (after the XML declaration) MUST be a **single line** with no newlines between `<w:p>` elements. MATLAB R2024a's Live Editor importer silently discards content if newlines are present between paragraphs — the file opens but `saveAs` produces an empty 235-byte shell. All examples below show the compact single-line format.

### Title

```xml
<w:p><w:pPr><w:pStyle w:val="title"/><w:jc w:val="left"/></w:pPr><w:r><w:t>Title</w:t></w:r></w:p>
```

### Text paragraph

```xml
<w:p><w:pPr><w:pStyle w:val="text"/><w:jc w:val="left"/></w:pPr><w:r><w:t>Paragraph text.</w:t></w:r></w:p>
```

`<w:jc w:val="center"/>` centers. Multiple `<w:r>` runs allowed (e.g. bold `<w:rPr><w:b/></w:rPr>`).
Escape XML entities in text (`<`, `>`, `&`).

### H1 heading

```xml
<w:p><w:pPr><w:pStyle w:val="heading"/><w:jc w:val="left"/></w:pPr><w:r><w:t>1. Section</w:t></w:r></w:p>
```

### H2 heading (COPY EXACTLY)

`heading2` requires R2018b+. Use the `mc:AlternateContent` block with a `mc:Fallback`
to plain `heading`. The heading text is a `<w:r>` AFTER the AlternateContent block:

```xml
<w:p><mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:Choice Requires="R2018b"><w:pPr><w:pStyle w:val="heading2"/><w:jc w:val="left"/></w:pPr></mc:Choice><mc:Fallback><w:pPr><w:pStyle w:val="heading"/><w:jc w:val="left"/></w:pPr></mc:Fallback></mc:AlternateContent><w:r><w:t>Subsection</w:t></w:r></w:p>
```

Do not hand-edit this block; copy it verbatim.

### Equation

LaTeX in `<w:t>` inside a `customXml` with `displayStyle`:

```xml
<w:p><w:pPr><w:pStyle w:val="text"/><w:jc w:val="center"/></w:pPr><w:customXml w:element="equation"><w:customXmlPr><w:attr w:name="displayStyle" w:val="true"/></w:customXmlPr><w:r><w:t>\frac{dx}{dt} = \sigma (y - x)</w:t></w:r></w:customXml></w:p>
```

`w:val="false"` for inline display. LaTeX backslashes are literal single backslashes in the XML.

### Image

`customXml` with height/width (pixels), verticalAlign, altText, and relationshipId
matching an Id in `matlab/_rels/document.xml.rels`:

```xml
<w:p><w:pPr><w:pStyle w:val="text"/><w:jc w:val="center"/></w:pPr><w:customXml w:element="image"><w:customXmlPr><w:attr w:name="height" w:val="376"/><w:attr w:name="width" w:val="800"/><w:attr w:name="verticalAlign" w:val="baseline"/><w:attr w:name="altText" w:val="modelo_lorenz.png"/><w:attr w:name="relationshipId" w:val="rId10"/></w:customXmlPr></w:customXml></w:p>
```

The actual image lives at `media/image1.png`; `altText` is its file name.

### Code cell

```xml
<w:p><w:pPr><w:pStyle w:val="code"/></w:pPr><w:r><w:t><![CDATA[x = 1;
disp(x)]]></w:t></w:r></w:p>
```

Code goes in CDATA (verbatim, including `<`, `>`, `&`). Do not embed `]]>` in the code.

### Section break (required at end)

```xml
<w:p><w:pPr><w:sectPr/></w:pPr></w:p>
```

A `<w:sectPr>` paragraph terminates the body. Verified documents end with one.

## Word-count rule

Body <= 1000 words excluding references, code cell, equations, and images.
Headings and figure captions count. Re-run `scripts/count-words.ps1`.