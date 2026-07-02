#!/usr/bin/env bash
#
# AI-BugBounty-OS — install.sh
# Production-grade, idempotent, resumable installer for a macOS bug bounty
# + AI-assisted recon environment (Apple Silicon + Intel).
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
# shellcheck source=lib/state.sh
source "${AIBOS_ROOT}/lib/state.sh"
# shellcheck source=lib/rollback.sh
source "${AIBOS_ROOT}/lib/rollback.sh"
# shellcheck source=lib/progress.sh
source "${AIBOS_ROOT}/lib/progress.sh"
# shellcheck source=lib/validate.sh
source "${AIBOS_ROOT}/lib/validate.sh"

for m in "${AIBOS_ROOT}"/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$m"
done

AIBOS_VERSION="$(cat "${AIBOS_ROOT}/VERSION" 2>/dev/null || echo "0.0.0")"
AIBOS_FORCE=0
AIBOS_NON_INTERACTIVE=0
AIBOS_NO_ROLLBACK=0
AIBOS_SKIP_VSCODE=0
AIBOS_MODEL="${AIBOS_MODEL:-qwen2.5-coder:7b}"

usage() {
    cat <<EOF
AI-BugBounty-OS installer v${AIBOS_VERSION}

Usage: ./install.sh [options]

Options:
  --force              Re-run all steps even if already completed
  --resume             Resume from last completed step (default behavior)
  --non-interactive     Assume yes for all confirmation prompts
  --no-rollback         Do not undo changes automatically on failure
  --model <name>        Ollama model to install (default: qwen2.5-coder:7b)
  --skip-vscode          Skip VS Code + Continue setup
  -h, --help            Show this help message

Examples:
  ./install.sh
  ./install.sh --force
  ./install.sh --model qwen2.5-coder:14b
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) AIBOS_FORCE=1; shift ;;
        --resume) shift ;;
        --non-interactive) AIBOS_NON_INTERACTIVE=1; shift ;;
        --no-rollback) AIBOS_NO_ROLLBACK=1; shift ;;
        --model) AIBOS_MODEL="$2"; shift 2 ;;
        --skip-vscode) AIBOS_SKIP_VSCODE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done
export AIBOS_FORCE AIBOS_NON_INTERACTIVE AIBOS_NO_ROLLBACK
export AIBOS_MODEL
export AIBOS_DEFAULT_MODEL="$AIBOS_MODEL"

_aibos_log_init
state_init
setup_error_trap

log_banner "AI-BugBounty-OS Installer v${AIBOS_VERSION}"
log_info "Log file: ${AIBOS_LOG_FILE}"
log_info "State file: ${AIBOS_STATE_FILE}"
log_info "Target model: ${AIBOS_MODEL}"
[[ "$AIBOS_FORCE" == "1" ]] && log_info "Force mode: all steps will be re-run"

validate_environment

STEPS=(
    "xcode_clt:step_xcode_clt"
    "homebrew:step_homebrew"
    "homebrew_update:step_homebrew_update"
    "ollama_install:step_ollama_install"
    "ollama_start:step_ollama_start"
    "pull_model:step_pull_model"
    "go_install:step_go_install"
    "go_env:step_go_env"
    "go_tools:step_go_tools_install"
    "nuclei_templates:step_nuclei_templates"
    "seclists:step_seclists_install"
    "assetnote_wordlists:step_assetnote_wordlists"
)

if [[ "$AIBOS_SKIP_VSCODE" != "1" ]]; then
    STEPS+=(
        "vscode_install:step_vscode_install"
        "vscode_cli_link:step_vscode_cli_link"
        "vscode_extensions:step_vscode_extensions"
        "continue_config:step_continue_config"
    )
fi

AIBOS_TOTAL_STEPS=${#STEPS[@]}
export AIBOS_TOTAL_STEPS

for entry in "${STEPS[@]}"; do
    name="${entry%%:*}"
    func="${entry##*:}"
    run_step "$name" "$func"
done

log_banner "Installation Complete"
log_success "AI-BugBounty-OS v${AIBOS_VERSION} is ready."
cat <<EOF

Next steps:
  1. Restart your terminal (or 'source ~/.zshrc') to pick up PATH changes
  2. Open VS Code and check the Continue panel — it's wired to ${AIBOS_MODEL} via Ollama
  3. Wordlists live in: ${AIBOS_WORDLISTS_DIR:-$HOME/.ai-bugbounty-os/wordlists}
  4. Run './update.sh' periodically to refresh templates, wordlists, and tools
  5. Run './uninstall.sh' if you ever want to remove everything cleanly

Happy (and responsible) hunting.
EOF
