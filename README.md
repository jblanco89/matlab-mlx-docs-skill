## MATLAB mlx documents skills

**Author binary MATLAB Live Code (`.mlx`) documents via the MATLAB Agentic Toolkit.**

This skill scaffolds a complete OPC package — `[Content_Types].xml`, `_rels/.rels`, `metadata/coreProperties.xml`, `metadata/mwcoreProperties.xml`, `metadata/mwcorePropertiesExtension.xml` — and scripts to pack, verify, and word-count the result. It targets the legacy binary `.mlx` format (WordprocessingML inside a ZIP container), not the plain-text `.m` live script introduced in R2025a.

### Why not `matlab-create-live-script`?

`matlab-create-live-script` ships with R2025a and produces **plain-text `.m` live scripts** using `%[text]` inline annotations. This skill produces **binary `.mlx` files** (OPC/ZIP) compatible with MATLAB **R2016a–R2024a**.

| Feature               | This Skill                         | `matlab-create-live-script`    |
|-----------------------|------------------------------------|---------------------------------|
| Output format         | Binary `.mlx` (OPC/WordprocessingML) | Text `.m` live script          |
| MATLAB versions       | R2016a – R2024a                   | R2025a+                         |
| Date stamping         | Dynamic via `pack-mlx.ps1`         | N/A                             |
| Verification          | `verify-mlx.ps1` (~30 structural checks) | None                        |
| Word-count budgeting  | `count-words.ps1` (≤1000 words)    | None                            |

### System requirements

- **Operating system:** Windows 10+ or Windows Server 2019+
- **Shell:** PowerShell 5.1 (built into Windows)
- **MATLAB:** R2016a – R2024a (for opening and rendering `.mlx` files)
- **MATLAB Agentic Toolkit:** installed and configured in your MATLAB Agent
- **Disk space:** <5 MB

### Installation

1. Clone this repository:

   ```bash
    git clone https://github.com/jblanco89/matlab-mlx-docs-skill.git
    cd matlab-mlx-docs-skill
   ```

2. Copy the skill into your toolkit's `skills-catalog/`:

   ```powershell
   Copy-Item -Recurse -Path .\matlab-mlx-docs-skill -Destination (Join-Path $env:USERPROFILE ".matlab-agent\skills-catalog")
   ```

   > **Note:** `skills-catalog\` is the local folder your agent reads skills from — the exact path depends on your agent runtime. `.matlab-agent\skills-catalog` is just the example here. If you are running this skill under:
   > - **Claude (Claude Code)** → use `~/.claude/skills`
   > - **opencode** → use `~/.agent/skills`
   > - **MATLAB Agentic Toolkit** → use `~/.matlab-agent/skills-catalog` (the default shown above)
   >
   > Point `-Destination` at whichever directory your runtime scans for skills.

3. Restart MATLAB Agent.

### Usage

The skill exposes no MATLAB functions directly. It generates an `.mlx` artifact through the agentic toolkit's `write_file` tool — the agent writes a package folder, you run `pack-mlx.ps1` to produce the binary `.mlx`, then `verify-mlx.ps1` and `count-words.ps1` validate it.

#### Example prompt

```text
/matlab-mlx-docs-skill Draft a formal paper-style article in .mlx format that
summarizes the contents of this repo. Structure it as:

  • Introduction (≈150 words) — contextualize [TOPIC YOU WANT IT TO BE WRITTEN].
  • Objectives (≈50 words).
  • Materials and Methods (≈300 words) — describe the [YOUR MAIN SUBJECT TOPIC] system, parameter
    values, and the [NUMERICAL METHOD] integrator. Reference
    [MATLAB_SCRIPT_FILE].m.
  • Mathematical Foundation
  • Results and Discussion (≈300 words).
  • Embed Simulink screenshots here.
  • Conclusion (≈50 words) — summarize implications.

Constraints:
  - LaTeX math: $E = mc^2$ style, consistent symbol naming.
  - Academic register, CS jargon, ≤ [N] words (excludes references).
  - Treat this as a template — replace "[FILE_REF]" and "[WORD_COUNT]"
    and section titles dynamically.

The agent should output the package folder structure; then run:
  1. pack-mlx.ps1   — creates the .mlx
  2. verify-mlx.ps1 — runs ~30 structural checks
  3. count-words.ps1 — validates word budget
```

### Helper scripts

| Script              | Purpose                                              |
|---------------------|------------------------------------------------------|
| `pack-mlx.ps1`      | Zips the package folder into a binary `.mlx`          |
| `verify-mlx.ps1`    | Validates OPC structure, XML well-formedness, entry presence, forward-slash paths, and document structure (~30 checks) |
| `count-words.ps1`   | Counts body words (excluding code, equations, images, references) against a 1000-word budget |
| `unpack-mlx.ps1`    | Extracts a `.mlx` back to a folder for inspection / editing (zip-slip guarded) |

### Assets

```
assets/package-skeleton/
├── [Content_Types].xml
├── _rels/
│   └── .rels
├── matlab/
│   ├── document.xml            ← template (single-line body, replace with authored content)
│   ├── output.xml
│   └── _rels/
│       └── document.xml.rels   ← one <Relationship> per image, Ids from rId10
├── media/                      ← optional, only when embedding images (image1.png, ...)
└── metadata/
    ├── coreProperties.xml
    ├── mwcoreProperties.xml
    └── mwcorePropertiesExtension.xml
```

### References

- `references/mlx-format.md` — full OPC/WordprocessingML specification for `.mlx`
- `references/version-compat.md` — version compatibility across MATLAB releases

### License

MIT — see `LICENSE`.
