#!/usr/bin/env nu

use utils.nu [require-command strip-v]

const LINUX_ARCHES = [x86_64 aarch64]
const ZED_RELEASE_BASE = "https://github.com/zed-industries/zed/releases/download"
const PACKAGE_REPO = "mert-kurttutan/zed-nix"

def main [
  --version: string # Zed version, with or without the leading v.
  --output-dir: string = ".release-assets"
] {
  require-command curl
  require-command gh
  require-command mktemp
  require-command tar
  require-command zstd

  let version = strip-v $version
  let tag = $"v($version)"
  let output = ($output_dir | path expand)
  mkdir $output

  for arch in $LINUX_ARCHES {
    let upstream = $"zed-linux-($arch).tar.gz"
    let source = $"($ZED_RELEASE_BASE)/($tag)/($upstream)"
    let work = (mktemp --directory | str trim)
    let archive = $"($output)/zed-linux-($arch).tar.zst"

    try {
      print $"Downloading ($source)"
      ^curl --fail --location --show-error --silent $source --output $"($work)/($upstream)"
      mkdir $"($work)/root"
      ^tar --extract --file $"($work)/($upstream)" --directory $"($work)/root" --gzip
      ^tar --create --file - --directory $"($work)/root" --sort=name --owner=0 --group=0 --numeric-owner --mtime="UTC 1970-01-01" . | ^zstd --compress --ultra --threads=0 -19 -f -o $archive
      print $"Created ($archive)"
    } finally {
      rm --recursive --force $work
    }
  }

  let release = (^gh release view $tag --repo $PACKAGE_REPO | complete)
  if $release.exit_code != 0 {
    ^gh release create $tag --repo $PACKAGE_REPO --title $tag --notes $"zstd-compressed Zed ($version) release assets."
  }
  ^gh release upload $tag $"($output)/*.tar.zst" --repo $PACKAGE_REPO --clobber
}
