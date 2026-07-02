#!/usr/bin/env bash
#
# AI-BugBounty-OS — update.sh
# Refreshes recon tools, Nuclei templates, wordlists, and Ollama models.
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
# shellcheck source=lib/rollback.sh
source "${AIBOS_ROOT}/lib/rollback.sh"
# shellcheck source=lib/progress.sh
source "${AIBOS_ROOT}/lib/progress.sh"

for m in "${AIBOS_ROOT}"/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$m"
done

usage() {
    cat <<EOF
AI-BugBounty-OS updater

Usage: ./update.sh [options]

Options:
  --model <name>   Ollama model to refresh (default: qwen2.5-coder:7b)
  -h, --help       Show this help message
EOF
}

AIBOS_MODEL="${AIBOS_MODEL:-qwen2.5-coder:7b}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model) AIBOS_MODEL="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

_aibos_log_init
AIBOS_NO_ROLLBACK=1   # updates are non-destructive; individual step failures are non-fatal
AIBOS_DEFAULT_MODEL="$AIBOS_MODEL"
export AIBOS_NO_ROLLBACK AIBOS_DEFAULT_MODEL

log_banner "AI-BugBounty-OS Updater"
log_info "Log file: ${AIBOS_LOG_FILE}"

log_step "Updating Homebrew and casks"
if command_exists brew; then
    brew update --quiet || log_warn "brew update had issues"
    brew upgrade --cask ollama --quiet 2>/dev/null || log_debug "Ollama already current or not managed by brew"
else
    log_warn "Homebrew not found; skipping brew updates"
fi

log_step "Pulling latest model weights"
if command_exists ollama; then
    ollama pull "${AIBOS_DEFAULT_MODEL}" || log_warn "Model update failed"
else
    log_warn "Ollama not installed; skipping model update"
fi

log_step "Updating Go recon tools"
if command_exists go; then
    step_go_tools_install
else
    log_warn "Go not installed; skipping tool updates"
fi

log_step "Updating Nuclei templates"
step_nuclei_templates || log_warn "Nuclei template update failed"

log_step "Updating SecLists"
step_seclists_install || log_warn "SecLists update failed"

log_success "Update complete. See log: ${AIBOS_LOG_FILE}"
