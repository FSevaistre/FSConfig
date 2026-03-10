## Create PR

1. Identify the project context (Ruby/Rails or TypeScript) from the changed files
2. Run all tests for the project:
   - Ruby: `make rspec` (or `make rspec spec/path` for targeted specs if only specific files changed)
   - TypeScript: `npx tsc --noEmit && npm test`
3. Run linter and fix issues:
   - Ruby: `make rubocop` (auto-correct with `bundle exec rubocop -A` if needed)
   - TypeScript: `npm run lint` or `yarn lint`
4. If any test or lint fails, fix the issues and re-run until green. Do NOT proceed with failures.
5. Create a branch if not already on one (use conventional naming: `feat/`, `fix/`, `chore/`)
6. Stage changed files and commit with a conventional commit message (feat, fix, chore, refactor, etc.)
7. Push the branch with `-u` flag
8. Create a PR using `gh pr create` with a clear title and description including:
   - Summary of changes
   - Test plan
9. Post the PR link to Slack #team-pretto-produit-tech
