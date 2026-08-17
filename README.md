## write-mlx-docs-custom

**Author binary MATLAB Live Code (`.mlx`) documents via the MATLAB Agentic Toolkit.**

This skill scaffolds a complete OPC package — `[Content_Types].xml`, `_rels/.rels`, `metadata/coreProperties.xml`, `metadata/mwcoreProperties.xml`, `metadata/mwcorePropertiesExtension.xml` — and scripts to pack, verify, and word-count the result. It targets the legacy binary `.mlx` format (WordprocessingML inside a ZIP container), not the plain-text `.m` live script introduced in R2025a.

### Why not `matlab-create-livescript`?

`matlab-create-livescript` ships with R2025a and produces **plain-text `.m` live scripts** using `%[text]` inline annotations. This skill produces **binary `.mlx` files** (OPC/ZIP) compatible with MATLAB **R2016a–R2024a**.

| Feature               | This Skill                         | `matlab-create-livescript`      |
|-----------------------|------------------------------------|---------------------------------|
| Output format         | Binary `.mlx` (OPC/WordprocessingML) | Text `.m` live script          |
| MATLAB versions       | R2016a – R2024a                   | R2025a+                         |
| Date stamping         | Dynamic via `pack-mlx.ps1`         | N/A                             |
| Verification          | `verify-mlx.ps1` (31 structural checks) | None                         |
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
   git clone https://github.com/jblanco/write-mlx-docs-custom.git
   cd write-mlx-docs-custom
   ```

2. Copy the skill into your toolkit's `skills-catalog/`:

   ```powershell
   Copy-Item -Recurse -Path .\write-mlx-docs-custom -Destination (Join-Path $env:USERPROFILE ".matlab-agent\skills-catalog")
   ```

3. Restart MATLAB Agent.

### Usage

The skill exposes no MATLAB functions directly. It generates an `.mlx` artifact through the agentic toolkit's `write_file` tool — the agent writes a package folder, you run `pack-mlx.ps1` to produce the binary `.mlx`, then `verify-mlx.ps1` and `count-words.ps1` validate it.

#### Example prompt

```text
/write-mlx-docs-custom Draft a formal paper-style article in .mlx format that
summarizes the contents of this repo. Structure it as:

  • Introduction (≈150 words) — contextualize deterministic chaos in engineering.
  • Objectives (≈50 words) — state what the simulation demonstrates.
  • Materials and Methods (≈300 words) — describe the Lorenz system, parameter
    values (σ, ρ, β), and the Runge-Kutta 4th-order integrator. Reference
    simulate_lorenz_chaos.m.
  • Mathematical Foundation — explain:
      - The Lorenz attractor and why it qualifies as a strange attractor.
      - Deterministic chaos and sensitivity to initial conditions.
      - Lyapunov exponent: definition, analytical expression, and how it
        quantifies divergence rate in this experiment.
      - Benettin's algorithm: why and how it was used to compute the
        largest Lyapunov exponent numerically.
  • Results and Discussion (≈300 words) — compare the nominal trajectory
    against the perturbed one. Cite the Lyapunov exponent as evidence of
    exponential divergence. Embed Simulink screenshots here.
  • Conclusion (≈50 words) — summarize implications.

Constraints:
  - LaTeX math: $E = mc^2$ style, consistent symbol naming.
  - Academic register, CS jargon, ≤1000 words (excludes references).
  - References: cite 4–6 high-impact sources (DOI or arXiv).
  - Embed screenshots of: (1) the Simulink model, (2) the phase-space plot
    from simulate_lorenz_chaos.m. Use actual filenames as placeholders.
  - Treat this as a template — replace "[FILE_REF]" and "[WORD_COUNT]"
    and section titles dynamically.

The agent should output the package folder structure; then run:
  1. pack-mlx.ps1   — creates the .mlx
  2. verify-mlx.ps1 — runs 31 structural checks
  3. count-words.ps1 — validates word budget
```

### Helper scripts

| Script              | Purpose                                              |
|---------------------|------------------------------------------------------|
| `pack-mlx.ps1`      | Zips the package folder into a binary `.mlx`          |
| `verify-mlx.ps1`    | Validates OPC structure, XML well-formedness, entry presence, forward-slash paths, and document structure (31 checks) |
| `count-words.ps1`   | Counts body words (excluding code, equations, images, references) against a 1000-word budget |

### Assets

```
assets/package-skeleton/
├── [Content_Types].xml
├── _rels/.rels
├── matlab/
│   └── document.xml          ← template (single-line body)
│   └── output.xml
├── metadata/
│   ├── coreProperties.xml
│   ├── mwcoreProperties.xml
│   └── mwcorePropertiesExtension.xml
```

### References

- `references/mlx-format.md` — full OPC/WordprocessingML specification for `.mlx`
- `references/version-compat.md` — version compatibility across MATLAB releases

### License

MIT — see `LICENSE`.
