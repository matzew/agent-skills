---
name: rebase-upstream-main
description: Sync the current branch by fetching upstream and rebasing onto upstream/main. Checks for uncommitted changes first.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, AskUserQuestion
---

Sync the current git branch to the latest upstream/main. Follow these steps exactly:

## Step 1: Verify this is a git repository

Run `git rev-parse --is-inside-work-tree`. If it fails, tell the user this is not a git repo and stop.

## Step 2: Verify the `upstream` remote exists

Run `git remote get-url upstream`. If it fails, tell the user there is no `upstream` remote configured and stop.

## Step 3: Check for uncommitted changes

Run `git status --porcelain`. If there is ANY output (staged, unstaged, or untracked files), do the following:

1. Show the user the output of `git status` (the human-readable version, not porcelain).
2. Ask the user using AskUserQuestion what they want to do, with these options:
   - **Stash and continue** - Run `git stash push -m "rebase-upstream-main: auto-stash"` then continue. After the rebase completes, run `git stash pop`.
   - **Abort** - Stop the operation entirely.

If the working tree is clean, proceed directly to the next step.

## Step 4: Fetch upstream

Run `git fetch upstream`. Report any errors and stop if the fetch fails.

## Step 5: Rebase onto upstream/main

Run `git rebase upstream/main`. If the rebase fails due to conflicts:

1. Show the user the conflicting files via `git status`.
2. Tell the user to resolve conflicts manually and run `git rebase --continue`.
3. Stop - do NOT attempt to resolve conflicts automatically.

If the rebase succeeds, show the user a short summary: how many new commits were pulled in (compare HEAD before and after, or show `git log --oneline` of the new commits).

## Step 6: Pop stash if applicable

If changes were stashed in Step 3, run `git stash pop`. If it fails due to conflicts, warn the user.
