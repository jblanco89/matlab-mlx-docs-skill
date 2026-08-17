# .mlx feature version compatibility

Empirically verified only on MATLAB R2024a Update 6. Below is the known matrix
from MathWorks format evolution and the probes run during development.

| Feature | Minimum release | Notes |
|---------|-----------------|-------|
| Base `.mlx` OPC container (text, code, equations, images) | R2016a | `.mlx` format introduced in R2016a |
| `heading2` style via `mc:AlternateContent Requires="R2018b"` | R2018b | Older releases fall back to the `mc:Fallback` (`heading`) branch, which is why the fallback is mandatory |
| `metadata/mwcorePropertiesReleaseInfo.xml` (2019 relationship) | R2019b | **Do NOT add in R2024a docs**: a heading + this file hangs the R2024a editor (`MATLAB:Editor:Document:OpenLoadTimeout`). MATLAB re-adds it automatically on saveAs |
| Single-line `matlab/document.xml` requirement | R2024a | **Mandatory in R2024a**: newlines between `<w:p>` elements cause silent content loss. Document body must be a single line after XML declaration. Verified on R2024a Update 6. |
| Numbered lists | (unconfirmed) | Introduced in some release between R2021b and R2024a; not verified — prefer heading2 or text for safety |
| Plain-text live script `.m` format | R2025a | Different format entirely; use `matlab-create-live-script` skill, not this one |

## Practical rule

- Target R2024a with the 3-metadata skeleton (no ReleaseInfo) and heading2
  AlternateContent blocks.
- **Ensure `matlab/document.xml` is a single line after the XML declaration.**
- The verified package (`lorenz_chaos_paper.mlx`) opens in R2024a in ~0.3 s and
  survives a MATLAB `saveAs` round-trip, which normalizes rels and re-adds
  ReleaseInfo.