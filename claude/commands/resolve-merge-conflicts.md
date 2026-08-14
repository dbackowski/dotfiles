---
description: Resolve merge conflicts in the working tree, preserving changes from both sides
---

Resolve all outstanding merge conflicts in the working tree. Do not delete work from either side — compare what each branch changed and keep both sets of changes when they are independent additions.

## Procedure

1. **Find conflicted files.** Run `git status` and identify files listed under "Unmerged paths" (or files containing `<<<<<<<` markers if the user pointed you at a specific path).

2. **Understand the merge context.** Run `git status` to confirm which two refs are being merged (look for the `HEAD` and the other ref named in the conflict markers — usually a branch like `master` or `main`, or `MERGE_HEAD`). Note the names so you can refer to them correctly in step 4.

3. **For each conflicted file, before editing:**
   - Read the full file to see every conflict hunk in context.
   - Inspect history on **both** sides since they diverged so you understand the intent of each change:
     - `git log --oneline <merge-base>..HEAD -- <file>` for this branch's commits
     - `git log --oneline <merge-base>..MERGE_HEAD -- <file>` (or the other ref) for the incoming side
     - Use `git show <sha> -- <file>` on the relevant commits to see exactly what each side added/changed.
   - You can find the merge base with `git merge-base HEAD MERGE_HEAD` if needed.

4. **Resolve each hunk by combining intent, not by picking a side.**
   - If both sides added independent things at the same location (e.g. two new test contexts, two new functions, two new imports), **keep both** in a sensible order.
   - If both sides modified the same line for different reasons, integrate both intents — don't silently drop one. If the two intents truly conflict and can't coexist, stop and ask the user which to take.
   - If one side is a strict superset of the other, take the superset.
   - Preserve surrounding formatting and indentation exactly.

5. **Verify each file after editing:**
   - Grep the file for `<<<<<<<`, `=======`, `>>>>>>>` to confirm no markers remain.
   - Run a language-appropriate syntax/parse check when cheap:
     - Ruby: `bundle exec ruby -c <file>` (or `ruby -c <file>`)
     - JavaScript/TypeScript: `node --check <file>` for `.js`, or use the project's linter for `.ts`/`.tsx`
     - Python: `python -m py_compile <file>`
     - JSON: `python -m json.tool <file> > /dev/null` or `jq . <file> > /dev/null`
   - Skip the syntax check for file types where it doesn't apply (Markdown, YAML without a parser handy, etc.).

6. **Do not run `git add` or `git commit`** unless the user explicitly asks. Resolving the conflict is the task; staging and committing are separate decisions for the user.

7. **Report back** with a short summary per file: which hunks existed, what each side contributed, and how you combined them. Cite file paths with line numbers using the markdown link format. Mention any places where you had to make a judgment call so the user can sanity-check.

## Guardrails

- Never resolve a conflict by deleting one side's content unless you can clearly justify it from the diffs (e.g. one side reverted code the other side also removed). When in doubt, keep both and ask.
- Never use `git checkout --ours` / `--theirs` or `git reset` to make conflicts disappear — those discard work.
- If `git status` shows the file as deleted on one side and modified on the other (a delete/modify conflict), stop and ask the user how to resolve it rather than guessing.
- If the conflicts span more than ~5 files or look semantically tangled, summarize what you're seeing and check in with the user before mass-editing.
