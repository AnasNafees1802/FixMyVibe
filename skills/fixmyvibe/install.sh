#!/usr/bin/env bash
# install.sh - Install the FixMyVibe skill for the agents on this machine. Mirrors install.ps1.
#
# Three locations cover every supported agent:
#   claude       ~/.claude/skills/fixmyvibe          Claude Code (Cursor reads it too)
#   agents       ~/.agents/skills/fixmyvibe          Codex, Cursor, Gemini CLI
#   antigravity  ~/.gemini/config/skills/fixmyvibe   Antigravity
#
# Usage:
#   ./install.sh                          install into every location whose agent is detected
#   ALL=1 ./install.sh                    install into all three, creating folders
#   AGENTS="claude agents" ./install.sh   install into the named locations only
#   REMOVE_LEGACY=1 ./install.sh          also remove what older FixMyVibe installers left behind
#   HOME_DIR=/tmp/h ./install.sh          use another home folder (for testing)
#
# Re-runnable: each run replaces the installed copy with this one.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME_DIR:-$HOME}"
[[ -f "$SRC/SKILL.md" ]] || { echo "SKILL.md not found next to the installer ($SRC)." >&2; exit 1; }

install_skill() { # dest
  if [[ -e "$1" ]]; then
    # Replace only a folder that is a FixMyVibe install, so a stale file from an older version cannot linger.
    grep -qE '^name:[[:space:]]*fixmyvibe[[:space:]]*$' "$1/SKILL.md" 2>/dev/null ||
      { echo "$1 exists and is not a FixMyVibe install. Move it away and run again." >&2; exit 1; }
    rm -rf "$1"
  fi
  mkdir -p "$1"; cp -R "$SRC/." "$1/"; rm -rf "$1/.git"
  chmod +x "$1/bin/fixmyvibe-audit.sh" 2>/dev/null || true
}
wanted() { case " ${AGENTS:-} " in *" $1 "*) return 0 ;; esac; return 1; }
detected() { local d; for d in "$@"; do [[ -e "$HOME_DIR/$d" ]] && return 0; done; return 1; }

used=()
echo "== FixMyVibe installer ==  (home: $HOME_DIR)"
target() { # name dir use detect...
  local name="$1" dir="$2" use="$3"; shift 3
  local go=0
  if [[ "${ALL:-0}" == 1 ]]; then go=1
  elif [[ -n "${AGENTS:-}" ]]; then
    wanted "$name" && go=1
    [[ "$name" == agents ]] && { wanted codex || wanted cursor || wanted gemini; } && go=1
  elif detected "$@"; then go=1; fi
  if [[ $go -eq 0 ]]; then printf 'skip      %-12s (not detected)\n' "$name"; return; fi
  install_skill "$HOME_DIR/$dir"
  printf 'installed %-12s %s\n' "$name" "$HOME_DIR/$dir"
  used+=("$use")
}
target claude .claude/skills/fixmyvibe '/fixmyvibe in Claude Code' .claude
target agents .agents/skills/fixmyvibe '$fixmyvibe in Codex, /fixmyvibe in Cursor and Gemini CLI' .codex .cursor .agents .gemini
target antigravity .gemini/config/skills/fixmyvibe '/fixmyvibe in Antigravity' .gemini/config .gemini/antigravity

# Older installers wrote to paths the agents no longer read, plus an always-on AGENTS.md block.
legacy=()
for p in .codex/skills/fixmyvibe .gemini/skills/fixmyvibe .antigravity/skills/fixmyvibe .claude/commands/fixmyvibe.md \
         .codex/prompts/fixmyvibe.md .gemini/workflows/fixmyvibe.md .antigravity/workflows/fixmyvibe.md; do
  [[ -e "$HOME_DIR/$p" ]] && legacy+=("$HOME_DIR/$p")
done
blocks=()
for p in .codex/AGENTS.md .gemini/AGENTS.md; do
  grep -qF '<!-- fixmyvibe:managed -->' "$HOME_DIR/$p" 2>/dev/null && blocks+=("$HOME_DIR/$p")
done
if [[ ${#legacy[@]} -gt 0 || ${#blocks[@]} -gt 0 ]]; then
  if [[ "${REMOVE_LEGACY:-0}" == 1 ]]; then
    for p in ${legacy[@]+"${legacy[@]}"}; do rm -rf "$p"; echo "removed   $p"; done
    for f in ${blocks[@]+"${blocks[@]}"}; do
      awk '/<!-- fixmyvibe:managed -->/ { skip = 1 } !skip { print } /<!-- \/fixmyvibe:managed -->/ { skip = 0 }' "$f" > "$f.fixmyvibe.tmp"
      mv "$f.fixmyvibe.tmp" "$f"; echo "cleaned   $f (removed the FixMyVibe block)"
    done
  else
    echo 'Found files from an older FixMyVibe install that agents no longer read:'
    for p in ${legacy[@]+"${legacy[@]}"} ${blocks[@]+"${blocks[@]}"}; do echo "  $p"; done
    echo 'Run again with REMOVE_LEGACY=1 to remove them.'
  fi
fi

echo '----------------------------------------'
if [[ ${#used[@]} -eq 0 ]]; then
  echo 'Nothing installed. No agent was detected. Run again with ALL=1, or set AGENTS="claude agents antigravity".'
  exit 1
fi
echo 'Open a new agent session, then use:'
for u in "${used[@]}"; do echo "  $u"; done
echo 'To make the audit run after every edit and before the agent stops, see adapters/ in the installed folder.'
