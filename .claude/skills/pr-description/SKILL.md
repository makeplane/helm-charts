---
name: pr-description
description: Write a clear, reviewer-focused pull request description that explains the changes introduced in the PR. Use whenever creating or updating a PR for this helm-charts repo (e.g. "raise a PR", "open a PR", "write the PR description"), or when asked to improve/rewrite an existing PR body.
---

# PR Description

Write PR descriptions that let a reviewer understand **what changed, why, and how it was verified** without having to read the whole diff first. Optimize for the reviewer's time.

## How to gather the facts (do this before writing)

1. `git diff master...HEAD --stat` and a full `git diff master...HEAD` to see exactly what changed.
2. `git log master..HEAD --oneline` for the commits on the branch.
3. For Helm chart changes, identify the **rendered effect**: which templates consume the changed values, and under what conditions they render. Run `helm template` to confirm before claiming behavior.
4. Note whether the change alters **default behavior** or is opt-in / docs-only — reviewers care about this most.

Never invent results. Only state testing that was actually run.

## Required structure

Use these sections (drop one only if genuinely not applicable):

### `## What`
1–3 sentences naming the file(s) and the concrete change. Include a short code/YAML snippet of the key change when it helps. State it factually, not aspirationally.

### `## Why`
The problem this solves or the motivation. Tie config knobs to the real-world symptom they address (e.g. "`proxy-buffer-size` fixes `502 upstream sent too big header`"). A reviewer should understand why this is worth merging.

### `## Scope / behavior`
The most important section for infra/chart changes. Explicitly answer:
- Does this change **default behavior**, or is it opt-in / commented / docs-only?
- What conditions gate the change (e.g. "only renders for `ingressClass: nginx`")?
- What is intentionally *not* affected.

### `## Testing`
Exactly what was run and what was observed. For charts, prefer `helm template` output showing the rendered result under the relevant value combinations. If nothing was run, say so plainly.

### Optional sections (add when relevant)
- `## Traefik note` / cross-controller notes — when a change applies to one ingress controller, state whether the other (traefik vs nginx) needs an equivalent and why/why not.
- `## Breaking changes` / `## Upgrade notes` — call out anything an operator must do on upgrade.
- `## Related` — linked issues/PRs.

## Style rules

- Lead with the conclusion; reviewers skim.
- Be specific: name files, value keys, template paths, and conditions.
- Show the diff's key lines as fenced snippets rather than describing them vaguely.
- Distinguish "no behavior change" loudly when true — it shortens review.
- Don't overclaim. "Verified via `helm template`" only if you actually ran it.
- Keep it tight. Every line should help the reviewer decide to approve.

## Commit & PR mechanics for this repo

- Base branch is `master`. Never commit directly to `master` — branch first.
- End commit messages with the `Co-Authored-By: Claude ...` trailer.
- End PR bodies with the `🤖 Generated with [Claude Code]` line.
- Create the PR with `gh pr create --base master`.
