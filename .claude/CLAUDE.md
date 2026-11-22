# Git workflow

- Start all development on a new dev branch. Use git branch prefixes, such as feature/, fix/, chore/, refactor/, test/, build/, release/, etc.
- Consider if work can be split up and fanned out to separate cloud agents to speed up work. To reduce chance of conflicts, group related changes and consider assigning these to the same agent. The agent should follow these same instructions, but should not itself start other agents without explicit consent.
- Open a PR when work is ready. To save time, don't run checks locally just before opening the PR, as the PR itself will run all the checks. Once the code is fairly final, commit, push, and let CI do the final run on the PR.
- Only open a PR in draft mode if for any reason the change isn't ready to be merged, e.g. if a change in another project should go in first. Take the PR out of draft mode once all conditions have cleared.
- Watch the PR. React automatically to resolve git conflicts or failing CI. After every push check `mergeStateStatus`. If this comes back `CONFLICTING` or `DIRTY`, resolve problem immediately. If it comes back `UNKNOWN`, try again after a few seconds. Otherwise, start waiting for CI checks.
  - For local sessions:
    - Call `gh pr checks --watch <PR number>` in a background task to wait for CI to finish without burning turns. Retry if no checks are reported yet. Report the result (all checks pass/check failure) to the main task when the checks finish. If the PR is still open after the checks pass, start a second background task that calls `gh pr view --json state,mergeStateStatus <PR number>` every minute or so until the PR has merged or has conflicts, and reports that result (merged/conflict) to the main task.
    - While the background task is waiting for CI, the main task should progress with the overall project. If the next step is independent, branch from origin/main after a fetch. But if it builds on the waiting PR, branch from the current dev branch and open the second PR stacked on it. If the background task reports either a check failure or conflict and the main checkout has moved on to another branch, resolve this in a temporary git worktree, which is removed afterward.
  - For cloud sessions, watch the PR and react to events from GitHub itself. Even when all checks have succeeded, keep checking `mergeStateStatus` regularly until the PR is merged.
- Resolve git conflicts by merging the main branch into the dev branch instead of rebasing, as the latter requires a force push.
- When a PR is merged, delete the local dev branch. If we are not working on another change on another branch, switch back to main and pull (`git checkout main && git pull && git branch -D <branch>`). GitHub deletes the remote branch automatically on merge, so the local one is pointless. Don't discard uncommitted changes when switching.
- Don't start work until explicitly told to. For example, when asked a question, simply run the required analysis and answer the question - don't start making code changes.

# Retired names

- `auth-broker` (countdown-server's old name; its host directory is now `/opt/countdown-server`) and the domain `nikolaivorkinn.com` are retired. Never reintroduce them in code, docs, test fixtures or settings. Use `countdown-server`, `countdown.run` (Countdown's domain) and `vorkinn.org` (everything else, e.g. `vault.vorkinn.org`). If either old name turns up, treat it as stale and replace it.
