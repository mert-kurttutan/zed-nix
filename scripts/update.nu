#!/usr/bin/env nu

use utils.nu [GITHUB_REPO get-current-version get-latest-version require-command strip-v]

const GITHUB_RELEASE_BASE = $"https://github.com/($GITHUB_REPO)/releases/download"
const LINUX_ARCHES = [
  x86_64
  aarch64
]

def log-info [message: string] {
  print $"(ansi green)[INFO](ansi reset) ($message)"
}

def ensure-in-repository-root [] {
  if (not ("flake.nix" | path exists)) or (not ("package.nix" | path exists)) {
    error make "flake.nix or package.nix not found. Please run this script from the repository root."
  }
}

def ensure-required-tools-installed [] {
  require-command nix
  require-command nix-prefetch-url
  require-command gh
}

def fetch-tarball-hash [version: string, arch: string] {
  let url = $"($GITHUB_RELEASE_BASE)/v($version)/zed-linux-($arch).tar.gz"
  let result = (^nix-prefetch-url $url | complete)

  if $result.exit_code != 0 {
    ""
  } else {
    let lines = ($result.stdout | str trim | lines)
    if ($lines | is-empty) {
      ""
    } else {
      $lines | last | str trim
    }
  }
}

def hash-to-sri [hash: string] {
  let result = (^nix hash convert --hash-algo sha256 --to sri $hash | complete)

  if $result.exit_code != 0 {
    ""
  } else {
    $result.stdout | str trim
  }
}

def set-package-version [content: string, version: string] {
  $content | str replace -r 'version = "[^"]*"' $"version = \"($version)\""
}

def set-tarball-hash [content: string, arch: string, sri_hash: string] {
  let asset_line = $"asset = \"zed-linux-($arch).tar.gz\";"
  let parts = $content | split row $asset_line
  if (($parts | length) != 2) {
    error make $"Could not find source for ($arch)"
  }

  let updated_tail = ($parts | get 1) | str replace -r 'hash = "[^"]*"' $"hash = \"($sri_hash)\""
  [($parts | get 0), $asset_line, $updated_tail] | str join ""
}

def update-to-version [new_version: string] {
  log-info $"Updating to version ($new_version)..."

  let original_package = open --raw package.nix
  let version_updated = set-package-version $original_package $new_version
  $version_updated | save --force package.nix

  mut hash_updated = $version_updated
  for arch in $LINUX_ARCHES {
    log-info $"Fetching ($arch) tarball hash..."
    let base32_hash = fetch-tarball-hash $new_version $arch
    if ($base32_hash | is-empty) {
      $original_package | save --force package.nix
      error make $"Failed to fetch ($arch) tarball hash"
    }

    let sri_hash = hash-to-sri $base32_hash
    if ($sri_hash | is-empty) {
      $original_package | save --force package.nix
      error make $"Failed to convert ($arch) hash to SRI"
    }

    log-info $"($arch) tarball hash: ($sri_hash)"
    $hash_updated = set-tarball-hash $hash_updated $arch $sri_hash
  }
  $hash_updated | save --force package.nix

  log-info "Verifying build..."
  let build = (^nix build ".#zed" | complete)
  if $build.exit_code != 0 {
    let stderr = $build.stderr | str trim
    if ($stderr | is-empty) {
      error make "Build verification failed"
    } else {
      error make {
        msg: "Build verification failed"
        help: $stderr
      }
    }
  }

  log-info "Build successful!"
}

def update-flake-lock [] {
  log-info "Updating flake.lock..."
  ^nix flake update
}

def show-changes [] {
  print ""
  log-info "Changes made:"
  let diff = (^git diff --stat package.nix flake.lock | complete)
  if ($diff.stdout | str trim | is-not-empty) {
    print ($diff.stdout | str trim)
  }
}

def main [
  --version: string = "" # Update to a specific Zed version.
  --check               # Only check for updates; exit 1 when an update is available.
] {
  ensure-in-repository-root
  ensure-required-tools-installed

  let current_version = get-current-version
  let latest_version = if ($version | is-empty) {
    get-latest-version
  } else {
    strip-v $version
  }

  log-info $"Current version: ($current_version)"
  log-info $"Latest version: ($latest_version)"

  if $current_version == $latest_version {
    log-info "Already up to date!"
    exit 0
  }

  if $check {
    log-info $"Update available: ($current_version) -> ($latest_version)"
    exit 1
  }

  update-to-version $latest_version
  log-info $"Successfully updated zed from ($current_version) to ($latest_version)"

  update-flake-lock
  show-changes
}
