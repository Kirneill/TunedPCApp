## v1.0.18 - One-click NVIDIA GPU Driver Profile

This release adds one-click GPU driver profile automation for NVIDIA users.

### New in this release
- Added a dedicated GPU Driver page with a single **APPLY GPU PROFILE** action.
- Added automated NVIDIA profile import flow using `nvidiaProfileInspector`.
- Added first-run auto-download for `nvidiaProfileInspector.exe` when missing.
- Added automatic backup of NVIDIA DRS database files before import.
- Added packaged GPU tools preset (`sq_competitive.nip`) and runtime sync into writable tools cache.

### Profile settings applied
- Power Management: **Prefer Maximum Performance**
- Texture Filtering Quality: **High Performance**
- VSync: **Force Off**
- Max Pre-Rendered Frames: **1**
- Threaded Optimization: **On**
- Triple Buffering: **Off**
- Shader Cache Size: **Unlimited**
- Anisotropic Sample Optimization: **On**
- Trilinear Optimization: **On**
- Negative LOD Bias: **Allow**

### UI/flow updates
- Sidebar entry renamed from **GPU Guide** to **GPU Driver**.
- GPU page now shows live logs and apply status.
- Added verification log labels for tool readiness, preset readiness, profile apply, and key settings checks.

### Notes
- Restart any currently running games after applying GPU profile changes.
- AMD auto-profile path remains placeholder/not yet implemented in this version.
