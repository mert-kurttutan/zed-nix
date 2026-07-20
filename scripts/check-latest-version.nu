#!/usr/bin/env nu

use utils.nu [get-current-version get-latest-version strip-v]

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
