#!/usr/bin/env bash
# Install ssh-egress into ~/.local/bin (or $1), and optionally the Claude Code skill.
#   ./install.sh                  install the command
#   ./install.sh --claude         install the command + the Claude Code skill
#   ./install.sh --prefix /usr/local/bin [--claude]
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CLAUDE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) BIN_DIR="$2"; shift 2 ;;
    --claude) CLAUDE=1; shift ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$BIN_DIR"
install -m 0755 "$SRC/ssh-egress" "$BIN_DIR/ssh-egress"
echo "installed $BIN_DIR/ssh-egress"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not in your PATH; add it to your shell profile:"
     echo "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

if [ "$CLAUDE" = 1 ]; then
  SKILL_DIR="$HOME/.claude/skills/ssh-egress"
  mkdir -p "$SKILL_DIR"
  install -m 0644 "$SRC/claude/SKILL.md" "$SKILL_DIR/SKILL.md"
  echo "installed Claude Code skill: $SKILL_DIR/SKILL.md"
fi

echo "next: ssh-egress init <ssh-host>   then   ssh-egress ip"
