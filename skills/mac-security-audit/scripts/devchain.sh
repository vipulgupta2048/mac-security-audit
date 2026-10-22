#!/bin/bash
# The developer supply chain on this Mac: AI-agent hooks and MCP servers,
# editor auto-run tasks, package-manager safety settings. Recent npm worms
# persist through exactly these files. Read-only. Prints names, events and
# executables, never arguments or env values (they carry tokens).
# Usage: devchain.sh [project roots...]
. "$(dirname "$0")/lib.sh"
S=devchain

# Claude Code hooks, user level and per project.
hooks() {
	local f=$1 ev
	[ -f "$f" ] || return 0
	ev=$(jsonq "$f" "Object.keys(d).length") || {
		row $S claude.hooks denied "$f" "could not parse; check it by hand"
		return 0
	}
	ev=$(jsonq "$f" "Object.keys(d.hooks||{}).map(function(e){return e+':'+[].concat.apply([],(d.hooks[e]||[]).map(function(m){return (m.hooks||[]).map(function(h){return String(h.command||'').split(/\s+/)[0]})})).join(',')}).join(' ')")
	[ -n "$ev" ] && row $S claude.hooks warn "$f" "$ev"
}
hooks "$HOME/.claude/settings.json"
hooks "$HOME/.claude/settings.local.json"

# MCP servers across agents: name and the executable or URL it starts.
mcp() {
	local agent=$1 f=$2 key=${3:-mcpServers}
	[ -f "$f" ] || return 0
	jsonq "$f" "1" >/dev/null || {
		row $S mcp denied "$f" "could not parse; check it by hand"
		return 0
	}
	jsonq "$f" "(function(){var o=d.$key||{};return Object.keys(o).map(function(k){var s=o[k]||{};return k+'|'+(s.url?String(s.url).split('?')[0]:(s.command||s.type||''))})})()" |
		while IFS='|' read -r name cmd; do
			[ -n "$name" ] && row $S mcp info "$name" "$agent | $cmd | $f"
		done
}
mcp claude-code "$HOME/.claude.json"
mcp claude-desktop "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
mcp cursor "$HOME/.cursor/mcp.json"
mcp windsurf "$HOME/.codeium/windsurf/mcp_config.json"
mcp vscode "$HOME/Library/Application Support/Code/User/mcp.json" servers
mcp gemini "$HOME/.gemini/settings.json"
[ -f "$HOME/.codex/config.toml" ] && grep -E '^\[mcp_servers\.[^].]+\]' "$HOME/.codex/config.toml" | sed 's/^\[mcp_servers\.//; s/\]$//' | while read -r n; do row $S mcp info "$n" "codex | $HOME/.codex/config.toml"; done

# Installed agent skills and plugins: a skill is code an agent will run.
for d in "$HOME/.claude/skills" "$HOME/.claude/plugins/cache" "$HOME/.codex/skills" "$HOME/.cursor/skills"; do
	[ -d "$d" ] || continue
	n=$(find "$d" -maxdepth 4 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
	row $S agent.skills info "$n skills" "$d"
done

# Per-project files the worms plant: Claude hooks, setup.mjs next to them,
# VS Code tasks that run on folder open, unexpected workflows.
project_roots "$@" | while IFS= read -r root; do
	[ -d "$root" ] || continue
	find "$root" -maxdepth 5 \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build \) -prune -o \
		\( -path '*/.claude/settings.json' -o -path '*/.claude/settings.local.json' -o -path '*/.vscode/tasks.json' \
		-o -path '*/.claude/setup.mjs' -o -path '*/.vscode/setup.mjs' -o -path '*/.claude/math_init.js' \) -type f -print 2>/dev/null |
		while IFS= read -r f; do
			case "$f" in
			*/setup.mjs | */math_init.js) row $S worm.file fail "$f" "file name used by ChainDrop/Tensorlake; modified $(mtime "$f")" ;;
			*/tasks.json) grep -q '"folderOpen"' "$f" 2>/dev/null && row $S vscode.folderOpen warn "$f" "task runs automatically when the folder opens; modified $(mtime "$f")" ;;
			*) hooks "$f" ;;
			esac
		done
	find "$root" -maxdepth 5 \( -name node_modules -o -name .git \) -prune -o -path '*/.github/workflows/*' \
		\( -name security-audit.yml -o -name github_actions_security.yml -o -name security-check.yml \) -type f -print 2>/dev/null |
		while IFS= read -r f; do row $S ghostaction.workflow warn "$f" "workflow name used by GhostAction; check its author and history"; done
done

# Package-manager settings that blunt install-time malware.
if have npm; then
	v=$(npm config get ignore-scripts 2>/dev/null)
	row $S npm.ignore-scripts info "${v:-false}" "true stops install scripts; some packages need them"
fi
if have pnpm; then
	v=$(pnpm config get minimum-release-age 2>/dev/null)
	case "$v" in "" | undefined) v="default (1440 on pnpm 11+, 0 before)" ;; esac
	row $S pnpm.minimum-release-age info "$v" "minutes a version must age before install"
fi
[ -f "$HOME/.bunfig.toml" ] && row $S bunfig info present "$HOME/.bunfig.toml"
exit 0
