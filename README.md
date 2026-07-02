# AI-BugBounty-OS

A production-grade, idempotent installer that turns a clean macOS machine (Apple Silicon or Intel) into a fully configured **AI-assisted bug bounty recon environment** — local LLM via Ollama, ProjectDiscovery tool suite, wordlists, and VS Code wired up with the Continue extension.

[![ShellCheck](https://github.com/your-org/AI-BugBounty-OS/actions/workflows/shellcheck.yml/badge.svg)](.github/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it installs

| Category | Tools |
|---|---|
| Local AI | [Ollama](https://ollama.com) + `qwen2.5-coder` model |
| Editor | VS Code + [Continue](https://continue.dev) (wired to your local model) + ShellCheck/GitLens/Go extensions |
| Recon (Go) | subfinder, httpx, nuclei, naabu, katana, dnsx, gau, ffuf, dalfox, waybackurls, gf, anew, assetfinder |
| Templates | Official Nuclei templates (`nuclei -update-templates`) |
| Wordlists | [SecLists](https://github.com/danielmiessler/SecLists), Assetnote wordlist index |
| Foundation | Xcode Command Line Tools, Homebrew, Go |

## Requirements

- macOS 12+ (Apple Silicon `arm64` or Intel `x86_64`)
- ~15 GB free disk space
- Active internet connection
- Admin privileges (for Xcode CLT / Homebrew)

## Quick start

```bash
git clone https://github.com/your-org/AI-BugBounty-OS.git
cd AI-BugBounty-OS
chmod +x install.sh update.sh uninstall.sh
./install.sh
```

The installer is **idempotent** — re-running it only performs work that hasn't already completed. If it's interrupted (network drop, laptop sleep, Ctrl-C), just run it again; it **resumes** from the last successful step using state tracked in `~/.ai-bugbounty-os/state/completed_steps`.

### Common flags

```bash
./install.sh --model qwen2.5-coder:14b   # use a larger model
./install.sh --force                     # re-run every step, ignoring saved state
./install.sh --skip-vscode               # skip VS Code + Continue setup
./install.sh --non-interactive           # no confirmation prompts
./install.sh --help                      # full option list
```

## Updating

```bash
./update.sh                 # refreshes Go tools, Nuclei templates, SecLists, and the model
./update.sh --model qwen2.5-coder:14b
```

## Uninstalling

```bash
./uninstall.sh              # removes AI-BugBounty-OS data, wordlists, and installed Go tools
./uninstall.sh --purge      # also removes Ollama, VS Code, and Go themselves via Homebrew
```

## Architecture

```
AI-BugBounty-OS/
├── install.sh              # orchestrator: validates env, runs steps in order, resumable
├── update.sh                # refreshes tools/templates/wordlists/model
├── uninstall.sh              # clean removal, with optional --purge
├── lib/
│   ├── colors.sh            # terminal color codes
│   ├── logging.sh            # colored console + persistent file logging
│   ├── state.sh               # resume support (completed-step tracking)
│   ├── progress.sh            # progress bar rendering
│   ├── rollback.sh             # register/run rollback actions on failure
│   ├── validate.sh             # macOS/arch/disk/network pre-flight checks
│   └── utils.sh                # command_exists, retry, confirm, arch helpers
├── modules/                    # one file per installable unit, sourced by install.sh/update.sh
│   ├── 00_prereqs.sh            # Xcode CLT, Homebrew
│   ├── 01_ollama.sh              # Ollama install + service start
│   ├── 02_models.sh               # qwen2.5-coder pull
│   ├── 03_go.sh                    # Go toolchain + GOPATH/bin on PATH
│   ├── 04_go_tools.sh               # ProjectDiscovery + recon tool suite
│   ├── 05_nuclei_templates.sh        # nuclei -update-templates
│   ├── 06_seclists.sh                 # SecLists + Assetnote wordlist index
│   ├── 07_vscode.sh                    # VS Code + extensions
│   └── 08_continue_config.sh            # Continue config pointed at local Ollama
├── config/
│   ├── continue/config.json              # template, model name templated in at install time
│   └── vscode/settings.json               # recommended editor settings
├── tests/shellcheck.sh                      # local lint runner
└── .github/workflows/shellcheck.yml          # CI lint on every push/PR
```

### Design principles

- **Bash strict mode** everywhere: `set -euo pipefail`, `IFS=$'\n\t'`, `errtrace` + `ERR` trap.
- **Idempotent**: every step checks whether its target state already exists before acting (`command_exists`, file checks, `brew list` equivalents) so re-runs are safe and fast.
- **Resumable**: completed steps are recorded in a flat state file; `install.sh` skips anything already done unless `--force` is passed.
- **Rollback**: modules register undo actions (`register_rollback`) as they make changes; on any uncaught error the trap unwinds them in reverse order before exiting, unless `--no-rollback` is set.
- **Modular**: each module is a small, single-purpose, independently sourceable script exposing `step_*` functions — easy to test, extend, or skip.
- **ShellCheck-clean**: CI lints every `.sh` file on push/PR; run `./tests/shellcheck.sh` locally.

## Continue + Ollama

After install, `~/.continue/config.json` points the Continue extension at your local Ollama instance running `qwen2.5-coder` (`http://localhost:11434`). No API keys, no data leaving your machine. Open the Continue panel in VS Code and it should be ready to go — if Ollama isn't running, start it with `open -a Ollama`.

## Logs & state

- Logs: `~/.ai-bugbounty-os/logs/install-<timestamp>.log`
- State: `~/.ai-bugbounty-os/state/completed_steps`
- Wordlists: `~/.ai-bugbounty-os/wordlists/`

## Troubleshooting

- **Xcode CLT dialog doesn't appear / install hangs**: install manually with `xcode-select --install`, then re-run `./install.sh`.
- **A `go install` step fails for one tool**: it's logged as a warning, not a hard failure — the rest of the install continues. Retry manually: `go install -v <module>@latest`.
- **Ollama won't start**: `open -a Ollama` manually, wait a few seconds, then re-run `./install.sh` (it resumes from `ollama_start`).
- **Want a clean slate**: `./uninstall.sh --purge` then `./install.sh --force`.

## Responsible use

This project installs offensive security tooling intended for **authorized** testing only — bug bounty programs, CTFs, and environments you own or have explicit permission to test. Follow the scope and rules of engagement of any program you participate in.

## Contributing

Issues and PRs welcome. Please run `./tests/shellcheck.sh` before submitting, and keep new functionality inside a module under `modules/` following the existing `step_*` naming convention.

## License

[MIT](LICENSE)
