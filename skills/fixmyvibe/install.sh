#!/usr/bin/env bash
# install.sh - Install the FixMyVibe skill into Claude Code, Codex, and Antigravity,
# and register a /fixmyvibe slash command in each. Mirrors install.ps1.
#
# Usage:
#   ./install.sh                 # auto: install into every agent detected on this machine
#   ALL=1 ./install.sh           # install into all three even if not detected (creates dirs)
#   AGENTS="claude codex" ./install.sh   # install into the named agent(s) only
#   HOME_DIR=/tmp/home ./install.sh      # override HOME (for testing)
# Idempotent: copies overwrite; command file is rewritten; AGENTS.md block inserted once.
set -euo pipefail

SKILL_NAME='fixmyvibe'
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME_DIR:-$HOME}"
MARKER='<!-- fixmyvibe:managed -->'
[[ -f "$SRC/SKILL.md" ]] || { echo "SKILL.md not found next to installer ($SRC)"; exit 1; }
CMD_TEMPLATE="$(cat "$SRC/command.md")"
installed=()

copy_skill() { # dest
  mkdir -p "$1"; cp -R "$SRC/." "$1/"; rm -rf "$1/.git" 2>/dev/null || true
}
write_command() { # destFile skillDir
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "${CMD_TEMPLATE//\{\{SKILL_DIR\}\}/$2}" > "$1"
}
add_agents_block() { # agentsFile skillDir
  mkdir -p "$(dirname "$1")"; touch "$1"
  if ! grep -qF "$MARKER" "$1"; then
    cat >> "$1" <<EOF

$MARKER
## FixMyVibe craft standard (auto-installed)
Before writing/generating/refactoring code or building any UI, follow the FixMyVibe skill at
$2/SKILL.md: read-before-write, refuse the average, and pass references/FINISH-GATE.md
(run bin/fixmyvibe-audit) before claiming done. Never emit anything in references/FORBIDDEN-PATTERNS.md.
Invoke explicitly with /$SKILL_NAME.
<!-- /fixmyvibe:managed -->
EOF
  fi
}

# detection
det_claude=$([[ -d "$HOME_DIR/.claude" ]] && echo 1 || echo 0)
det_codex=$([[ -d "$HOME_DIR/.codex" ]] && echo 1 || echo 0)
det_anti=$([[ -d "$HOME_DIR/.gemini" || -d "$HOME_DIR/.antigravity" ]] && echo 1 || echo 0)

want() { case " ${AGENTS:-} " in *" $1 "*) return 0;; esac; return 1; }
explicit=$([[ -n "${AGENTS:-}" ]] && echo 1 || echo 0)
do_claude=0; do_codex=0; do_anti=0
if [[ "${ALL:-0}" == "1" ]]; then do_claude=1; do_codex=1; do_anti=1;
elif [[ "$explicit" == "1" ]]; then want claude && do_claude=1; want codex && do_codex=1; want antigravity && do_anti=1;
else do_claude=$det_claude; do_codex=$det_codex; do_anti=$det_anti; fi

echo "== FixMyVibe installer ==  (HOME: $HOME_DIR)"
echo "detected -> Claude:$det_claude Codex:$det_codex Antigravity:$det_anti"

if [[ "$do_claude" == "1" ]]; then
  d="$HOME_DIR/.claude/skills/$SKILL_NAME"; copy_skill "$d"
  write_command "$HOME_DIR/.claude/commands/$SKILL_NAME.md" "$d"
  echo "[Claude] skill -> $d ; command -> /$SKILL_NAME"; installed+=("Claude (/fixmyvibe)")
fi
if [[ "$do_codex" == "1" ]]; then
  d="$HOME_DIR/.codex/skills/$SKILL_NAME"; copy_skill "$d"
  write_command "$HOME_DIR/.codex/prompts/$SKILL_NAME.md" "$d"       # prompts/<name>.md -> /<name>
  add_agents_block "$HOME_DIR/.codex/AGENTS.md" "$d"
  echo "[Codex]  skill -> $d ; command -> /$SKILL_NAME (prompts) ; AGENTS.md updated"; installed+=("Codex (/fixmyvibe)")
fi
if [[ "$do_anti" == "1" ]]; then
  base="$HOME_DIR/.gemini"; [[ -d "$HOME_DIR/.antigravity" ]] && base="$HOME_DIR/.antigravity"
  d="$base/skills/$SKILL_NAME"; copy_skill "$d"
  write_command "$base/workflows/$SKILL_NAME.md" "$d"                # global workflow -> /<name>
  add_agents_block "$HOME_DIR/.gemini/AGENTS.md" "$d"
  echo "[Antigravity] skill -> $d ; workflow -> /$SKILL_NAME ; ~/.gemini/AGENTS.md updated"
  echo "  note: if /$SKILL_NAME does not appear, import $base/workflows/$SKILL_NAME.md via the '+ Global' workflow button."
  installed+=("Antigravity (/fixmyvibe)")
fi

echo '----------------------------------------'
if [[ ${#installed[@]} -eq 0 ]]; then
  echo "No agents installed. None detected - re-run with ALL=1 or AGENTS=\"claude codex antigravity\"."
else
  printf 'Installed into: %s\n' "$(IFS=', '; echo "${installed[*]}")"
  echo 'Open a fresh agent session and type /fixmyvibe to use it.'
fi
