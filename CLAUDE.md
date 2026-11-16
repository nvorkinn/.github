# Git workflow

- Start all development on a new dev branch. Use git branch prefixes, such as feature/, fix/, chore/, refactor/, test/, build/, release/, etc.
- Consider if work can be split up and fanned out to separate cloud agents to speed up work. To reduce chance of conflicts and to prevent too many agents from being created, group related changes and consider assigning these to the same agent. The agent should follow these same workflows, but should not itself start other agents without explicit consent.
- Open a PR when work is ready. To save time, don't run the full test suite locally just before opening the PR, as the PR itself will run all the tests. Once the code is fairly final, commit, push, and let CI do the final run on the PR.
- Only open a PR in draft mode if for any reason the change isn't ready to be merged, e.g. if another change should go in first. Take the PR out of draft mode once all conditions have cleared.
- Watch the PR. React automatically to resolve git conflicts or failing CI. For local sessions, call `gh pr checks --watch` to wait for CI to finish without burning turns, then call `gh pr view --json state,mergeStateStatus` to see if the PR has merged or has conflicts. For cloud sessions, watch the PR and react to events from GitHub itself.
- Resolve git conflicts by merging the main branch into the dev branch instead of rebasing, as the latter requires a force push.
- When a PR is merged, switch back to main, pull, and delete the local dev branch (`git checkout main && git pull && git branch -D <branch>`). GitHub deletes the remote branch automatically on merge, so the local one is pointless. Don't discard uncommitted changes when switching.
- Don't start work until explicitly told to. For example, when asked a question, simply run the required analysis and answer the question - don't start making code changes.
