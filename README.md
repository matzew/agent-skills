# agent-skills

Personal collection of Claude Code skills for daily development workflows.

## Skills

### rebase-upstream-main

Syncs the current git branch to the latest `upstream/main`. Checks for uncommitted changes before rebasing and offers to stash them. Stops on conflicts for manual resolution.

Usage: `/rebase-upstream-main`

## Installation

Symlink individual skills into `~/.claude/skills/`:

```sh
ln -s /path/to/agent-skills/rebase-upstream-main ~/.claude/skills/rebase-upstream-main
```
