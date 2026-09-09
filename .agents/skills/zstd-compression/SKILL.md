---
name: zstd-compression
description: Prefer zstd for distributing compressed files when size and compression speed both matter, especially in Nix packaging.
---

# zstd compression

- Prefer `zstd -19` for release archives when download size matters; use a lower level when compression CPU/time matters more.
- Repack compressed archives: extract the original first, then create an uncompressed tar stream and compress it with zstd. Do not zstd-compress an existing `.gz` stream.
- For Nix packages, add `zstd` to `nativeBuildInputs`, extract with `tar --zstd -xf`, and update the fixed-output hash.
- Keep the upstream format as a fallback unless zstd hosting and redistribution are controlled.
