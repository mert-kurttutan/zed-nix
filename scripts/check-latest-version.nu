#!/usr/bin/env nu

const GITHUB_REPO = "zed-industries/zed"

def strip-v [version: string] {
  $version | str trim | str replace -r '^v' ''
}

def get-current-version [] {
  let versions = (
    open --raw package.nix
    | parse --regex 'version = "(?P<version>[^"]+)"'
    | get version
  )

  if ($versions | is-empty) {
    "unknown"
  } else {
    strip-v ($versions | first)
  }
}

def get-latest-version [] {
  if (which gh | is-empty) {
    error make "Missing required command: gh"
  }

  let result = (^gh release view --repo $GITHUB_REPO --json tagName -q '.tagName' | complete)
  if $result.exit_code != 0 {
    let stderr = $result.stderr | str trim
    if ($stderr | is-empty) {
      error make "Failed to fetch latest version from GitHub"
    } else {
      error make $stderr
    }
  }

  strip-v $result.stdout
}

def main [
  --version: string = "" # Specific Zed version to compare against.
] {
  let current_version = get-current-version
  let new_version = if ($version | is-empty) {
    get-latest-version
  } else {
    strip-v $version
  }

  if ($new_version | is-empty) {
    error make "Could not fetch latest version"
  }

  print $"current_version=($current_version)"
  print $"new_version=($new_version)"
  print $"update_needed=($current_version != $new_version)"
}
