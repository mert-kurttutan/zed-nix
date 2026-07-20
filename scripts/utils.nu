export const GITHUB_REPO = "zed-industries/zed"

export def strip-v [version: string] {
  $version | str trim | str replace -r '^v' ''
}

export def require-command [name: string] {
  if (which $name | is-empty) {
    error make $"($name) is required but not installed."
  }
}

export def get-current-version [] {
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

export def get-latest-version [] {
  require-command gh

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
