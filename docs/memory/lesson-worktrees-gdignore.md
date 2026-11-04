Agent worktrees live under .claude/worktrees/ inside the Godot project; without `.claude/.gdignore` Godot scans them and tools/check goes RED (duplicate class_name "hides a global script class").
Why: hit during the day-cycle/grass/lighthouse merge. How to apply: keep .claude/.gdignore committed.
