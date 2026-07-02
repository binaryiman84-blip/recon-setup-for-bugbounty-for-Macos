#!/usr/bin/env bash
#
# AI-BugBounty-OS — uninstall.sh
# Cleanly removes tools and configuration installed by AI-BugBounty-OS.
#
set -euo pipefail
IFS=$'\n\t'

AIBOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AIBOS_ROOT

# shellcheck source=lib/colors.sh
source "${AIBOS_ROOT}/lib/colors.sh"
# shellcheck source=lib/logging.sh
source "${AIBOS_ROOT}/lib/logging.sh"
# shellcheck source=lib/utils.sh
source "${AIBOS_ROOT}/lib/utils.sh"

_aibos_log_init

AIBOS_PURGE=0
AIBOS_NON_INTERACTIVE=0

usage() {
    cat <<EOF
AI-BugBounty-OS uninstaller

Usage: ./uninstall.sh [options]

Options:
  --purge              Also remove Homebrew-managed Ollama, VS Code, and Go
                        (default: only removes AI-BugBounty-OS-specific data/tools)
  --non-interactive     Assume yes for all confirmation prompts
  -h, --help            Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge) AIBOS_PURGE=1; shift ;;
        --non-interactive) AIBOS_NON_INTERACTIVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done
export AIBOS_NON_INTERACTIVE

log_banner "AI-BugBounty-OS Uninstaller"

if ! confirm "This will remove AI-BugBounty-OS data (wordlists, state, logs, config). Continue?"; then
    log_info "Aborted."
    exit 0
fi

log_step "Removing Go-installed recon tools"
GOPATH_BIN="$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin"
if [[ -d "$GOPATH_BIN" ]]; then
    for tool in subfinder httpx nuclei naabu katana dnsx gau ffuf dalfox waybackurls gf anew assetfinder; do
        if [[ -f "${GOPATH_BIN}/${tool}" ]]; then
            rm -f "${GOPATH_BIN}/${tool}"
            log_info "Removed ${tool}"
        fi
    done
else
    log_info "No Go bin directory found; skipping tool removal"
fi

log_step "Removing AI-BugBounty-OS data directory"
if [[ -d "$HOME/.ai-bugbounty-os" ]]; then
    rm -rf "$HOME/.ai-bugbounty-os"
    log_info "Removed ~/.ai-bugbounty-os (logs, state, wordlists)"
else
    log_info "No AI-BugBounty-OS data directory found"
fi

log_step "Removing Continue configuration"
if [[ -f "$HOME/.continue/config.json" ]]; then
    if confirm "Remove ~/.continue/config.json?"; then
        rm -f "$HOME/.continue/config.json"
        log_info "Removed Continue config"
    fi
else
    log_info "No Continue config found"
fi

if [[ "$AIBOS_PURGE" == "1" ]]; then
    log_warn "Purge mode: removing underlying applications (Ollama, VS Code, Go)"
    if confirm "Really uninstall Ollama, VS Code, and Go via Homebrew?"; then
        command_exists ollama && brew uninstall --cask ollama 2>/dev/null || true
        [[ -d "/Applications/Visual Studio Code.app" ]] && brew uninstall --cask visual-studio-code 2>/dev/null || true
        command_exists go && brew uninstall go 2>/dev/null || true
        log_info "Purge complete"
    else
        log_info "Skipping purge of underlying applications"
    fi
else
    log_info "Homebrew, Ollama, VS Code, and Go were left in place (use --purge to remove them too)"
fi

log_success "AI-BugBounty-OS has been uninstalled."
