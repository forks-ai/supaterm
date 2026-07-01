---
name: review
description: "Perform code reviews following best  engineering practices. Use when reviewing pull requests, examining code changes, or providing feedback on code quality."
---

# Review

Run the three review passes as parallel subagents, then synthesize their results.

## Invocation contracts

Use the host agent's subagent mechanism. Prefer exact keys where the host defines them:

- Codex custom agents: call `spawn_agent` once per reviewer with `agent_type: "thermo-nuclear-correctness-review-subagent"`, `agent_type: "thermo-nuclear-maintainability-review-subagent"`, and `agent_type: "product-requirement-alignment-review-subagent"`. The spawned agents run in the background; wait for all three agent ids before synthesis. Codex custom agent files use `name`, `description`, and `developer_instructions`.
- Markdown-frontmatter agents: invoke the agents whose frontmatter `name` values are `thermo-nuclear-correctness-review-subagent`, `thermo-nuclear-maintainability-review-subagent`, and `product-requirement-alignment-review-subagent`. Use `background: true` when that frontmatter field is supported.
- Task-schema hosts: use `subagent_type: "thermo-nuclear-correctness-review-subagent"`, `subagent_type: "thermo-nuclear-maintainability-review-subagent"`, and `subagent_type: "product-requirement-alignment-review-subagent"`. Use `run_in_background: true` only when that host exposes the field.

## Workflow

1. Determine the review scope from the user request, PR, current branch, or relevant changed files.
2. Gather the diff and any file/context excerpts needed for reviewers to evaluate the change without guessing.
3. Launch all three configured reviewers in parallel:
   - `thermo-nuclear-correctness-review-subagent` for bugs, breakages, security, devex regressions, feature-flag leaks, and other branch-audit risks.
   - `thermo-nuclear-maintainability-review-subagent` for maintainability, structure, file-size growth, spaghetti, abstractions, and codebase-health risks.
   - `product-requirement-alignment-review-subagent` for PRD alignment, requirement/evaluation drift, missing product-doc updates, and untracked scope changes before PR submission.
4. Pass each subagent the same scoped diff/file context and ask it to return prioritized findings with file references and evidence.
5. After all three finish, synthesize the results with findings first, deduplicated across reviewers. Weight overlapping findings more heavily, resolve disagreements with your own judgment, and keep summaries brief.

If individual background summaries are already visible to the user, do not restate them wholesale. Surface the unified verdict, the highest-signal findings, and any remaining uncertainty.
