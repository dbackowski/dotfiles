---
description: Generate a markdown PR description from the current branch's changes
---

Generate a PR title and description for the current branch and print them to the chat as two separate markdown code blocks so the user can copy each one independently.

## Steps

1. Determine the current branch name:
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```
   The branch always starts with a Jira ticket ID like `PAY-3621-...`. Extract the ticket ID using the regex `^[A-Z]+-\d+`. If the branch does not match, ask the user for the ticket ID before continuing.

2. Detect the base branch (usually `main`) and gather the full diff and commit log for the branch in parallel:
   ```bash
   git log --no-merges main..HEAD --pretty=format:'%h %s%n%b%n---'
   git diff main...HEAD --stat
   git diff main...HEAD
   ```
   If `main` doesn't exist locally, try `origin/main` or `master`.

3. Read the diff carefully. Focus on what actually changed in production code (not test-only changes or formatting). Identify:
   - The user-visible or system-level behavior change (for the summary)
   - The motivation behind it — infer from commit messages, code comments, and surrounding context (for **Why?**)
   - The implementation approach — key files, patterns, new modules, renamed concepts (for **How?**)
   - How a reviewer can verify it — UI flow, rake task, rspec command, curl, etc. (for **How to test?**)
   - The PR **type** for the title prefix:
     - `[feature]` — adds new user-visible or system-level behavior (new endpoint, new UI, new model field that is acted on, new flag, new integration). Title verb: `Add`, `Introduce`, `Support`, `Enable`.
     - `[bugfix]` — fixes incorrect behavior in existing code (wrong result, crash, regression). Title verb: `Fix`, `Correct`, `Prevent`, `Guard`.
     - `[internal]` — no behavior change for users or external systems: refactors, renames, dead-code removal, test-only changes, dependency bumps without behavior change, tooling/CI/docs. Title verb: `Refactor`, `Rename`, `Remove`, `Bump`, `Clean up`.
     - When in doubt between `[feature]` and `[internal]`, ask: "would a user, support engineer, or downstream service notice anything different after this ships?" If yes → `[feature]`. If no → `[internal]`.

4. If the motivation, test plan, or PR type is not clear from the diff/commits, ask the user one concise question before writing the description rather than guessing.

5. Detect whether this is the **chargify** repository — it has a different PR template that requires an `### Acceptance Criteria` section. Check with:

   ```bash
   git remote get-url origin 2>/dev/null
   ```

   If the remote URL contains `chargify` (e.g. `github.com:chargify/chargify` or similar), treat this as the chargify repo and include the `### Acceptance Criteria` block in the description (see template below). Otherwise omit that section.

6. Output **two** fenced code blocks in this order — first the title, then the description:

    Title block (single line, plain text fence):

    ```
    [<type>] <Imperative summary, sentence case, no trailing period>
    ```

    Examples of well-formed titles:
    - `[feature] Add support for monthly surcharge fee`
    - `[bugfix] Fix nil dereference when merchant has no Adyen account`
    - `[internal] Refactor SurchargeSettingsHelper into a frozen lookup`

    Description block (use this exact structure; replace `PAY-XXXX` and content). The `### Acceptance Criteria` block is **only** included when step 5 detected the chargify repo — omit it entirely otherwise:

    ```markdown
    <one-sentence summary of what the PR does>

    Jira: [PAY-XXXX](https://maxioevolution.atlassian.net/browse/PAY-XXXX)

    ### Why?

    <short paragraph explaining the motivation — the problem or requirement driving the change>

    ### How?

    <bulleted or short-paragraph description of the implementation: key files touched, new objects/modules, notable decisions>

    ### Acceptance Criteria

    <bulleted list of clear, testable outcomes that must be true for this PR to be considered complete — focus on expected behavior, not implementation details>

    ### How to test?

    <numbered steps or bullets a reviewer can follow to verify the change>
    ```

## Rules

- Use the ticket ID only (e.g. `PAY-3621`) in the Jira URL — not the full branch slug.
- The title prefix is one of `[feature]`, `[bugfix]`, `[internal]` — pick exactly one. Do not invent other prefixes (no `[chore]`, `[refactor]`, `[hotfix]`, etc.); refactors and chores are `[internal]`.
- The title itself is sentence case (only the first word capitalised, no trailing period) and stays under ~70 characters so it doesn't wrap on GitHub.
- Output the **title block first**, then a blank line, then the **description block**.
- Keep the top summary in the description to **one sentence**.
- **Why?** explains motivation, not implementation. **How?** is the inverse.
- Do not invent behavior that isn't in the diff. If something is ambiguous, leave it out or ask.
- Skip test-only / cassette / lockfile noise when summarising — mention them only if they're the point of the PR.
- Respect this repo's conventions from AGENTS.md (Actions, Services, ViewComponents, etc.) when naming patterns in **How?**.
- Do not create a PR, do not push, do not commit. Only output the description text.
