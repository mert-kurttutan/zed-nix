#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="zed-industries/zed"
readonly GITHUB_RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases/download"
readonly ASSET_NAME="zed-linux-x86_64.tar.gz"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1 | sed 's/^v//' || echo "unknown"
}

get_latest_version() {
    local tag
    tag=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || echo "")
    if [ -z "$tag" ]; then
        log_error "Failed to fetch latest version from GitHub"
        exit 1
    fi
    echo "$tag" | sed 's/^v//'
}

fetch_tarball_hash() {
    local version="$1"
    local url="${GITHUB_RELEASE_BASE}/v${version}/${ASSET_NAME}"

    local hash
    hash=$(nix-prefetch-url "$url" 2>/dev/null | tail -1)
    echo "$hash" | tr -d '\n'
}

hash_to_sri() {
    local hash="$1"
    nix hash convert --hash-algo sha256 --to sri "$hash" 2>/dev/null
}

update_package_version() {
    local version="$1"
    sed -i.bak "s/version = \".*\"/version = \"$version\"/" package.nix
}

update_tarball_hash() {
    local sri_hash="$1"
    local temp_file
    temp_file=$(mktemp)

    awk -v hash="$sri_hash" '
        /src = fetchurl/ { in_fetchurl_block=1 }
        in_fetchurl_block && /sha256 = / {
            sub(/sha256 = "[^"]*"/, "sha256 = \"" hash "\"")
            in_fetchurl_block=0
        }
        { print }
    ' package.nix > "$temp_file"
    mv "$temp_file" package.nix
}

cleanup_backup_files() {
    rm -f package.nix.bak
}

update_to_version() {
    local new_version="$1"

    log_info "Updating to version $new_version..."

    update_package_version "$new_version"

    log_info "Fetching tarball hash..."
    local base32_hash
    base32_hash=$(fetch_tarball_hash "$new_version")
    if [ -z "$base32_hash" ]; then
        log_error "Failed to fetch tarball hash"
        mv package.nix.bak package.nix
        exit 1
    fi

    local sri_hash
    sri_hash=$(hash_to_sri "$base32_hash")
    if [ -z "$sri_hash" ]; then
        log_error "Failed to convert hash to SRI"
        mv package.nix.bak package.nix
        exit 1
    fi

    log_info "Tarball hash: $sri_hash"
    update_tarball_hash "$sri_hash"

    cleanup_backup_files

    log_info "Verifying build..."
    if ! nix build .#zed > /dev/null 2>&1; then
        log_error "Build verification failed"
        return 1
    fi

    log_info "✅ Build successful!"
    return 0
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "package.nix" ]; then
        log_error "flake.nix or package.nix not found. Please run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v nix-prefetch-url >/dev/null 2>&1 || { log_error "nix-prefetch-url is required but not installed."; exit 1; }
    command -v gh >/dev/null 2>&1 || { log_error "gh (GitHub CLI) is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to specific version"
    echo "  --check           Only check for updates, don't apply"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update to latest version"
    echo "  $0 --check            # Check if update is available"
    echo "  $0 --version 0.222.4  # Update to specific version"
}

parse_arguments() {
    local target_version=""
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                target_version="${2#v}"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    echo "$target_version|$check_only"
}

update_flake_lock() {
    if command -v nix >/dev/null 2>&1; then
        log_info "Updating flake.lock..."
        nix flake update
    fi
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat package.nix flake.lock 2>/dev/null || true
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local args
    args=$(parse_arguments "$@")
    local target_version
    target_version=$(echo "$args" | cut -d'|' -f1)
    local check_only
    check_only=$(echo "$args" | cut -d'|' -f2)

    local current_version
    current_version=$(get_current_version)
    local latest_version
    if [ -n "$target_version" ]; then
        latest_version="$target_version"
    else
        latest_version=$(get_latest_version)
    fi

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date!"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version → $latest_version"
        exit 1
    fi

    update_to_version "$latest_version"

    log_info "Successfully updated zed from $current_version to $latest_version"

    update_flake_lock
    show_changes
}

main "$@"
