---
name: supabase-migration-merge
description: Coordinates multi-branch Supabase migration merges. INVOKE when there are unmerged feature branches touching `supabase/migrations/`, before any of them merges to main. Walks five phases — gather (via gh) → merge view → collision-fix plan → serialized local merge via cherry-pick → commit + merge. Hard human gates between phases; copy-paste approval. Only one developer at a time runs this skill against a given target branch.
---

# supabase-migration-merge — multi-branch migration coordinator

## When to invoke

- Two or more branches ahead of `main` have files under `supabase/migrations/`.
- A migration on one branch was authored before another but merged to main *after* — leaving the timestamps stale.
- A merge is about to happen and you want to know if there's hidden conflict between concurrent migrations.

**Don't invoke** for a single dev's single-branch migration — that's normal flow.

## Hard rule before anything else: serialization

Only **one developer at a time** should be driving this skill against a given target branch. The cherry-pick + renumber + replay sequence creates a window where the migrations directory is in a half-merged state on the target branch; if two devs do this simultaneously they will collide.

**Coordinate in the team chat first.** Whoever takes the merge says so. The others wait.

If you (the agent) detect that someone else is mid-merge (a recent branch named `merge/migrations-*` exists, or git history shows in-progress cherry-picks on the merge target), **stop and surface that** instead of proceeding.

---

## Phase 1 — gather (via `gh`)

### Precondition: `gh` installed and authenticated

Run these as your first action — don't proceed if either fails:

```bash
gh --version
gh auth status
```

If `gh` is not installed: tell the human to install it (`brew install gh` / `winget install GitHub.cli` / `apt install gh`) and stop.
If `gh auth status` shows no logged-in account: tell the human to run `gh auth login` and stop.

**Don't try to work around either.** This skill needs `gh` for the cross-branch view, and silent fallback to local-only data misses the point.

### Collect branches ahead of main

```bash
# Default branch (usually main; some projects use master)
DEFAULT=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)

# All open branches with commits ahead of default, sorted by latest activity
gh api "repos/{owner}/{repo}/branches" --paginate \
  --jq '.[] | select(.name != "'"$DEFAULT"'") | .name' \
  | while read b; do
      ahead=$(gh api "repos/{owner}/{repo}/compare/${DEFAULT}...${b}" --jq .ahead_by 2>/dev/null)
      [ "$ahead" -gt 0 ] 2>/dev/null && echo "$b  ahead=$ahead"
    done
```

PowerShell equivalent uses the same `gh api` calls; same logic.

### For each branch ahead, list its migration files

```bash
gh api "repos/{owner}/{repo}/compare/${DEFAULT}...${BRANCH}" \
  --jq '.files[] | select(.filename | startswith("supabase/migrations/")) | {filename, status}'
```

`status` is `added` / `modified` / `removed`. **`modified` on an existing migration is a red flag** — migration files should be immutable once merged. Surface it.

### Build the merge view

Render a markdown table the human can read at a glance:

```
| Branch                          | Migration                                       | Status | Author     |
|---------------------------------|-------------------------------------------------|--------|------------|
| feat/users-table                | 20260520120000_add_users_table.sql              | added  | Kirill M.  |
| feat/notifications              | 20260522093000_add_notifications_indexes.sql    | added  | Timofey N. |
| feat/notifications              | 20260525140000_add_notifications_status.sql     | added  | Timofey N. |
| feat/oauth-consent              | 20260518100000_alter_users_add_oauth.sql        | added  | Dima P.    |
```

Show:
- **Branch** (with `gh pr view <branch>` link if there's an open PR — fetch with `gh pr list --head <branch> --json url`)
- **Migration filename** (full, so timestamps and order are obvious)
- **Status** (added / modified / removed)
- **Author** (from `gh api .../compare` `commits[].author.login`)

Below the table, list **objects touched** per migration (parse the SQL: `CREATE TABLE X`, `ALTER TABLE Y ADD ...`, `DROP X`). If the same object name appears on two rows, **flag it as a potential conflict** in the next phase.

---

## Phase 2 — collision-fix plan

### Detect collisions

Two categories:

**A. Order collisions** — timestamps are out of merge order.

Symptom: branch X has `20260518_alter_users.sql`, but branch Y (already merged to main) has `20260520_add_users_table.sql`. X was authored before Y but Y landed first. X's migration would now fail (it ALTERs a table that doesn't exist yet on a fresh DB replay).

Fix: renumber X's migration to a timestamp AFTER Y's. New ID = current UTC timestamp.

**B. Object collisions** — two unmerged migrations both modify the same object.

Symptom: branch X has `ALTER TABLE Users ADD COLUMN foo INT;`, branch Y has `ALTER TABLE Users ADD COLUMN foo TEXT;`. Same column, different types — one must lose.

Fix: humans decide which version wins. Skill cannot resolve this — surface it, ask, wait.

### Output the fix plan

For order collisions (resolvable), produce a renumbering table:

```
| Migration (current)                              | New ID (proposed)               | Reason                                                                       |
|--------------------------------------------------|---------------------------------|------------------------------------------------------------------------------|
| 20260518100000_alter_users_add_oauth.sql         | 20260527140000_alter_users_...  | Depends on `Users` table created in 20260520120000_add_users_table.sql       |
| 20260522093000_add_notifications_indexes.sql     | 20260527141000_add_...          | Depends on `Notifications` table; renumber for consistent merge order        |
```

For object collisions (unresolvable):

```
⚠️  OBJECT COLLISION — needs human decision

Both `feat/users-table` and `feat/oauth-consent` modify column Users.email_verified:
  - feat/users-table:    ALTER TABLE Users ADD COLUMN email_verified BOOLEAN DEFAULT false;
  - feat/oauth-consent:  ALTER TABLE Users ADD COLUMN email_verified TIMESTAMPTZ;

Pick one. Either:
  (a) Drop one branch's migration and re-derive on top of the other.
  (b) Combine into a single migration on a fresh branch.

Migration-merge can't decide this. Pause and resolve in chat.
```

---

## Phase 3 — approve (copy-paste gate)

**Do not proceed to local merge without explicit copy-paste approval.**

Print to the human:

```
=== Approval required ===

To approve the plan above, paste back EXACTLY this line:

  APPROVE migration-merge for branches: <branch-1>, <branch-2>, ...

Pasting anything else (including "yes", "ok", "go") will NOT count as approval.
This is intentional — it forces you to read the branch list.
```

Wait for the literal "APPROVE migration-merge for branches: ..." line from the human. If they paste a different branch list (added or removed branches), re-render the merge view + fix plan for that adjusted scope.

If they paste anything else, ask them to use the exact form. Don't infer approval.

---

## Phase 4 — local merge (serialized, cherry-pick based)

### Branch off the default

```bash
git fetch origin
git switch -c "merge/migrations-$(date +%Y%m%d%H%M%S)" origin/main
```

### Cherry-pick each branch's migration commits

For each branch in the approved list, identify the commits that touch `supabase/migrations/`:

```bash
gh api "repos/{owner}/{repo}/compare/main...${BRANCH}" \
  --jq '.commits[] | select(.files // [] | map(.filename | startswith("supabase/migrations/")) | any) | .sha'
```

(Or use a local `git log --diff-filter=A -- supabase/migrations/ origin/main..${BRANCH}` once the branches are fetched locally.)

Then cherry-pick them onto the merge branch:

```bash
git cherry-pick <sha>
```

If a cherry-pick conflicts on a non-migration file, **stop and ask** — that's not a migration-merge concern, that's a regular merge.

### Apply the renumbering from Phase 2

For each entry in the renumber table, `git mv` the file:

```bash
git mv supabase/migrations/20260518100000_alter_users_add_oauth.sql \
       supabase/migrations/20260527140000_alter_users_add_oauth.sql
```

If the migration file references its own timestamp internally (some teams stamp it in a header comment), update that too.

### Apply locally and check it replays

```bash
# Drop + recreate local DB to test from scratch
npx supabase db reset
```

If `db reset` fails on any migration, **stop**. The order is still wrong, or there's a missing dependency, or the object collision wasn't actually resolved. Don't paper over it — go back to Phase 2.

### Verify the resulting schema matches expectations

Use `mcp__supabase__list_tables` or run a sanity query against the freshly-reset local DB:

```bash
mcp__supabase__execute_sql with: SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
```

Compare the expected new tables/columns from the merge view against what's actually present.

---

## Phase 5 — finalize

### Commit + push the merge branch

```bash
git add supabase/migrations/
git commit -m "merge: consolidate migrations from <branch-1>, <branch-2>, ..."
git push -u origin HEAD
```

### Open a PR

```bash
gh pr create --base main --title "merge: consolidate migrations from <N> branches" \
  --body "$(cat <<EOF
Merges migration files from:
- <branch-1>
- <branch-2>
- ...

Renumbered (see commit history for the renames):
- old-id → new-id (because: reason)
- ...

Verified locally via 'npx supabase db reset' on a fresh DB.

This PR REPLACES the migration commits in each source branch. Close those PRs
without merging once this one lands — they are now in this PR's history via
cherry-pick.
EOF
)"
```

### After merge

- Tell the source-branch authors that their migration commits are now in main via the merge PR; they should rebase their branches on the new main and drop the obsolete migration files (they were cherry-picked away).
- If any branch had non-migration commits, those branches stay open and rebase normally.

### Lock-release

Tell the team chat: *migration-merge complete*. The next person can now take a turn.

---

## What this skill won't do

- It won't decide object collisions for you. Two branches that both ALTER the same column with incompatible types need a human call.
- It won't validate semantic correctness of the migrations — only that they replay cleanly. A migration that creates a table with no PK will replay but is still wrong.
- It won't rewrite history on the source branches. The cherry-pick lands the migrations on the merge branch; the source branches keep their (now redundant) commits until they're rebased.
- It won't recover from a botched cherry-pick mid-flight. If you bail out in the middle, the merge branch is in a half-applied state — `git cherry-pick --abort` and start over.

## Composition with other skills

- Run `librarian` (if installed) BEFORE Phase 1 — the `supabase` librarian view tells you what's already on main; useful for spotting object collisions early.
- Run `ai-workflow` AROUND this whole skill — it's the parent loop. Migration-merge is the Implement phase of a larger "ship these features" task.
