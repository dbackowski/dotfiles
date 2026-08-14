---
description: Review the current branch's changes for improvements, optimizations, and simplifications
---

Perform a code review of the current branch against its base branch. Your job is to read the diff like a senior reviewer would and report concrete, actionable findings focused on **improvements, optimizations, and simplifications** — not a summary of what changed.

## Steps

1. Detect the base branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's|^origin/||'
   ```
   If that fails, fall back to `main`, then `origin/main`, then `master`. Use `git merge-base HEAD <base>` to find the divergence point.

2. Gather the branch diff and commit log in parallel:
   ```bash
   git log --no-merges <base>..HEAD --pretty=format:'%h %s%n%b%n---'
   git diff <base>...HEAD --stat
   git diff <base>...HEAD
   ```

3. Identify the changed files. For anything non-trivial, **Read the full file** — not just the hunk — so you understand the surrounding context before judging the change. Diff-only review misses broken invariants.

4. Before listing findings, infer the repo's conventions from what you see:
   - Look at neighbouring files to learn the project's patterns, naming, and layering.
   - Check for `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`, or a `docs/` folder and skim anything relevant.
   - Note the language(s), framework(s), and test runner so your feedback matches the stack.

5. For each changed file, look for:

   **Simplifications**
   - Verbose constructs that have a shorter idiomatic form in this language/framework (e.g. `if x then x else y` → `x || y`, `map { |x| x.foo }` → `map(&:foo)`, nested `if`s collapsible to a guard clause).
   - Conditional branches that can be expressed as a single expression, ternary, or `case`/`when`.
   - Local variables used exactly once that just add noise.
   - Custom helpers that reimplement something the standard library, framework, or an existing helper in this repo already provides.
   - Defensive code (nil checks, type checks, fallbacks) for cases that can't actually happen given the call sites.
   - Comments that restate the code — delete them; if intent is unclear, rename instead.
   - Dead code, unused exports, unreachable branches, unused parameters.

   **Optimizations**
   - N+1 queries, missing `includes`/`preload`/`joins`, `.count` in a loop, `.pluck` opportunities instead of instantiating AR objects.
   - Repeated computation inside a loop that could be hoisted, memoized, or precomputed once.
   - Unnecessary allocations: building intermediate arrays/hashes that are immediately reduced; `select` + `first` → `find`; `map.flatten` → `flat_map`.
   - DB-level work being done in Ruby (filtering, sorting, aggregating in memory when SQL could do it).
   - Missing indexes for newly-queried columns or for foreign keys introduced in this branch.
   - Synchronous external calls that belong in a background job.
   - Eager work on cold paths; lazy enumerators where the full collection isn't needed.

   **Improvements (design / quality / correctness)**
   - Does the change follow the patterns already established in this repo? (Learned from step 4.) Violations of layering (controller doing work that belongs in an action/service/query), business logic in jobs, presenter logic in views, etc.
   - Inappropriate abstraction — premature generalization for a single caller, or copy-paste that should be factored.
   - Reusable extraction opportunities: a block of logic that already exists elsewhere in the repo and could be shared.
   - Naming that hides intent (boolean flags whose meaning flips, ambiguous predicates, vague helper names).
   - Hard-coded user-facing strings in a codebase that otherwise uses i18n; magic numbers/strings that deserve a constant.
   - Correctness: nil/undefined handling, off-by-one, wrong operator, wrong constant, shadowed variables, mutated shared state, race conditions, missing transactions around multi-step writes, swallowed exceptions, broken retries.
   - Schema / migration changes: safe defaults, backfills, locking implications on large tables, reversibility, `ext_` prefix for external-system columns.
   - Newly introduced branches (new enum value, new flag, new status) — are all existing call sites / views / serializers / state machines updated?
   - Authorization / tenancy leaks; security: injection (SQL, shell, template), secrets in logs, unsafe deserialization, missing auth on new endpoints.

   **Tests**
   - Is every new branch/condition covered? Uncovered enum values, error paths, unauthorized access paths, edge-case inputs.
   - Tests that assert the call happened but not the observable outcome.
   - Overly verbose setup that could use a shared factory/helper; repetitive `it` blocks that could be parameterized.
   - Fixtures/factories/snapshots changed in a way that silently alters unrelated tests' defaults.
   - Recorded network fixtures (VCR/Polly/MSW/etc.) hand-edited in a way that won't survive a re-record.
   - Missing test for a migration/backfill or for a new public API surface.

6. Output a single review report with this structure. Group findings by severity, and for each finding cite the file + line range using markdown links (e.g. `[src/foo.ts:42-51](src/foo.ts#L42-L51)`). If a section has no findings, omit it.

   **Numbering:** Every finding and suggestion across the entire report MUST be numbered with a single continuous sequence starting at `1` — do NOT restart numbering per section. The user uses these numbers to refer back ("fix #3", "skip #7"), so each number must uniquely identify one finding across the whole review. Test-coverage gaps and "Looks good" notes are also numbered as part of the same sequence. Render each item as `**N.** **<short title>** — ...` (bold number, then bold title) so the IDs stand out.

   ```markdown
   # Code review — <branch-name>

   **Base:** `<base>` · **Commits:** N · **Files changed:** N

   One- or two-sentence summary of what the branch does, so the findings below have context.

   ## 🔴 Must fix
   - **1.** **<short title>** — [path:line](path#Lline). What's wrong and why it matters. Suggested fix in one line.
   - **2.** **<short title>** — [path:line](path#Lline). ...

   ## 🟡 Should consider
   - **3.** **<short title>** — [path:line](path#Lline). Concern and reasoning.

   ## 🟢 Nits / style
   - **4.** **<short title>** — [path:line](path#Lline). Minor suggestion.

   ## 🧪 Test coverage gaps
   - **5.** What isn't covered and the simplest test that would cover it.

   ## ✅ Looks good
   - **6.** Brief note on the non-obvious things that were done well (only if worth calling out).
   ```

## Rules

- **Read full files, not just hunks.** A diff-only review misses broken invariants in surrounding code.
- **Be specific.** "Consider refactoring" is useless. Name the concrete smell and the concrete fix.
- **Cite every finding** with a clickable `[path:line](path#Lline)` link.
- **Number every finding** with a single continuous sequence (1, 2, 3, …) across all sections so the user can refer back by ID ("fix #3", "skip #7"). Never restart numbering per section.
- **Severity discipline**:
  - 🔴 Must fix = correctness bug, security issue, data loss risk, or broken contract.
  - 🟡 Should consider = meaningful improvement, optimization with clear win, simplification that removes real complexity, missing test, convention violation.
  - 🟢 Nit = small simplification or readability tweak with marginal payoff.
- **Prefer simpler over cleverer.** When proposing a simplification, the suggested form must be at least as readable as the original — don't trade clarity for brevity.
- **Optimizations need a reason.** Don't suggest micro-optimizations without an actual hot path, large collection, or measurable cost. Speculative perf changes belong in 🟢 at most.
- **Don't invent issues.** If the code is fine, say so. False positives erode trust.
- **Don't report purely cosmetic issues** that a linter/formatter would catch (whitespace, line length, quote style, import order). Focus on things a human reviewer would catch and tools won't.
- **Learn the repo's conventions from the repo itself** (step 4) rather than assuming a particular stack.
- **Do not modify any files.** This is a read-only review. No edits, no commits, no PR actions.
