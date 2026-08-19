# Hints

- Do not add `nushell` to the flake development dependencies; `nu` is expected
  to be installed by the host system.
- Keep package and app outputs limited to Linux architectures with official Zed
  prebuilt tarballs.
- When updating Zed, refresh hashes for both `x86_64-linux` and
  `aarch64-linux`.
