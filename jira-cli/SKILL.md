---
name: jira-cli
description: Use when the user asks about Jira tickets, issues, epics, sprints, or boards. Use when querying, creating, editing, transitioning, or commenting on Jira issues. Use when the user mentions a Jira project key (e.g. MYPROJECT) or issue key (e.g. MYPROJECT-42). Always use the local `jira` CLI tool via Bash, never web scraping or APIs.
---

# Jira CLI

Use the locally installed `jira` CLI (github.com/ankitpokhrel/jira-cli) for all Jira operations. Never use WebFetch or web scraping for Jira data.

## Quick Reference

| Action | Command |
|--------|---------|
| List issues | `jira issue list -p PROJECT --plain --no-truncate` |
| View issue | `jira issue view ISSUE-KEY --plain --comments 5` |
| Create issue | `jira issue create -p PROJECT -tType -s"Summary" -b"Body" --no-input` |
| Edit issue | `jira issue edit ISSUE-KEY -s"New summary" --no-input` |
| Transition | `jira issue move ISSUE-KEY "In Progress"` |
| Assign | `jira issue assign ISSUE-KEY "user@email"` |
| Unassign | `jira issue assign ISSUE-KEY x` |
| Assign to self | `jira issue assign ISSUE-KEY $(jira me)` |
| Add comment | `jira issue comment add ISSUE-KEY -b"Comment body"` |
| List epics | `jira epic list -p PROJECT --plain --no-truncate` |
| List sprints | `jira sprint list -p PROJECT --plain` |
| List boards | `jira board list -p PROJECT --plain` |
| Open in browser | `jira open ISSUE-KEY` |
| Current user | `jira me` |

## Listing Issues

Always use `--plain` and `--no-truncate` for machine-readable output. Use `--reverse` with `--order-by created` for newest-first.

```bash
# All issues, newest first
jira issue list -p PROJECT --plain --no-truncate --order-by created --reverse

# Filter by status
jira issue list -p PROJECT -s"In Progress" --plain --no-truncate

# Filter by assignee
jira issue list -p PROJECT -a"user@email" --plain --no-truncate

# Filter by type
jira issue list -p PROJECT -tEpic --plain --no-truncate

# Filter by priority
jira issue list -p PROJECT -yHigh --plain --no-truncate

# Filter by label
jira issue list -p PROJECT -l"label-name" --plain --no-truncate

# Combine filters
jira issue list -p PROJECT -tStory -s"In Progress" -yHigh --plain --no-truncate

# Created/updated time filters
jira issue list -p PROJECT --created month --plain --no-truncate
jira issue list -p PROJECT --updated week --plain --no-truncate
jira issue list -p PROJECT --created-after 2026-01-01 --plain --no-truncate

# Exclude a status (prefix with ~)
jira issue list -p PROJECT -s~Closed --plain --no-truncate

# Unassigned issues
jira issue list -p PROJECT -ax --plain --no-truncate

# Raw JQL
jira issue list -p PROJECT -q"status = 'In Progress' AND priority = High" --plain --no-truncate

# Select specific columns
jira issue list -p PROJECT --plain --columns KEY,SUMMARY,STATUS,ASSIGNEE

# Pagination
jira issue list -p PROJECT --paginate 0:50 --plain --no-truncate

# Search by text
jira issue list -p PROJECT "search text" --plain --no-truncate
```

## Creating Issues

Always use `--no-input` to avoid interactive prompts.

```bash
# Basic
jira issue create -p PROJECT -tStory -s"Summary" -b"Description" --no-input

# With labels, components, priority, assignee
jira issue create -p PROJECT -tBug -s"Bug title" -b"Description" \
  -yHigh -a"user@email" -lbug -l"urgent" -CBackend --no-input

# Sub-task (requires parent)
jira issue create -p PROJECT -tSub-task -P"PROJECT-42" -s"Subtask title" --no-input

# With custom fields
jira issue create -p PROJECT -tStory -s"Title" --custom story-points=3 --no-input

# Description from stdin
echo "Description from pipe" | jira issue create -p PROJECT -tTask -s"Title" --no-input
```

## Editing Issues

```bash
jira issue edit ISSUE-KEY -s"Updated summary" --no-input
jira issue edit ISSUE-KEY -b"Updated description" --no-input
jira issue edit ISSUE-KEY -yHigh --no-input
jira issue edit ISSUE-KEY -l"new-label" --no-input

# Remove a label (prefix with -)
jira issue edit ISSUE-KEY --label -"old-label" --no-input
```

## Transitioning Issues

```bash
jira issue move ISSUE-KEY "In Progress"
jira issue move ISSUE-KEY "Done"
jira issue move ISSUE-KEY "Closed" -R"Done"        # with resolution
jira issue move ISSUE-KEY "In Progress" --comment "Starting work"
```

## Issue Types

Epic, Spike, Ticket, Bug, Risk, Story, Task, Sub-task, Vulnerability, Weakness

## Common Mistakes

- Forgetting `--plain` causes interactive mode which blocks the CLI
- Forgetting `--no-input` on create/edit causes interactive prompts
- Assignee must be exact match (email or full display name)
- Sub-tasks require `-P PARENT-KEY`
- Use `--no-truncate` with `--plain` to see all fields
