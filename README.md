# agent-skills

Personal collection of Claude Code skills for daily development workflows.

## Skills

### rebase-upstream-main

Syncs the current git branch to the latest `upstream/main`. Checks for uncommitted changes before rebasing and offers to stash them. Stops on conflicts for manual resolution.

Usage: `/rebase-upstream-main`

### jira-cli

Handles all Jira operations using the locally installed `jira` CLI. Covers listing, creating, editing, transitioning, and commenting on issues, epics, sprints, and boards. Activates automatically when a Jira project key or issue key is mentioned.

Usage: ask about any Jira ticket (e.g. "show me OCPMCP-42") and the skill activates automatically.

### k8s-deep-derivative

Reviews Kubernetes controller reconciliation code for correct use of the `DeepDerivative`/`DeepEqual` hybrid pattern. Catches missing explicit equality checks for removable fields (slices, maps, pointers, strings) that `DeepDerivative` silently skips, preventing both spurious updates from API server defaulting and missed user field removals.

Usage: invoke when writing or reviewing controller update-detection logic for Deployments, StatefulSets, DaemonSets, Jobs, etc.

## Plugins

### confirm-gh-writes

A PreToolUse hook that blocks GitHub CLI write operations (`gh pr create`, `gh issue close`, `gh release create`, `git push`, etc.) and requires explicit user approval before execution.

Install as a plugin:

```sh
claude --plugin-dir /path/to/agent-skills/confirm-gh-writes
```

## Installation

### As OCI image (recommended)

The repo builds a `scratch`-based OCI image that can be mounted directly into sandbox containers:

```sh
podman build -t quay.io/myorg/agent-skills:latest .
```

Mount into a container with podman:

```sh
podman run --rm -it \
  --mount type=image,src=quay.io/myorg/agent-skills:latest,dst=/opt/skills-0,readwrite=false \
  my-sandbox:latest
```

Inside the container, symlink the skills so Claude Code discovers them:

```sh
mkdir -p "$HOME/.claude/skills"
for d in /opt/skills-*/skills/*/; do
  ln -sfn "$d" "$HOME/.claude/skills/$(basename "$d")"
done
```

### Manual symlinks

Symlink individual skills into `~/.claude/skills/`:

```sh
ln -s /path/to/agent-skills/rebase-upstream-main ~/.claude/skills/rebase-upstream-main
```
