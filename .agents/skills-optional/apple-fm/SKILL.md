---
name: apple-fm
description: >-
  Condense bulky text with the on-device Apple Foundation Model BEFORE it enters your
  context, using the bundled `afm` CLI. Load this skill BEFORE you Read or cat the text,
  never after — once you have read it there is nothing left to save. Trigger when a task
  points you at text you have not opened yet and it has no greppable pattern: a long issue
  or PR thread, a prose document, a mixed service log, a large diff (roughly 250-700 lines).
  Also trigger to classify a batch of lines, pull requirements out of a document, get a
  cheap second opinion on a plan you wrote, or brainstorm names. Keywords: "Apple
  Foundation Models", "AFM", "fm", "afm", "local subagent", "on-device model", "save
  tokens", "省 token", "本機模型", "摘要這個 log", "整理這個 issue 的需求", "幫我分類這些錯誤".
  Not for code generation, debugging, architecture, security review, or anything you
  cannot check yourself.
---

# apple-fm

> ⚠️ This skill is version-controlled in the dotfiles repo at `.agents/skills-optional/apple-fm/SKILL.md`.
> Update it there and sync with `make update`. It is installed only on Apple silicon Macs
> where the `fm` CLI works; on every other machine the sync skips it.
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1`.

**Purpose:** Keep bulky, pattern-less text out of the main agent's context by condensing it
locally first, without ever letting the small model make a decision or block the task.

`~/.agents/skills/apple-fm/scripts/afm` sends one bounded task to the model and prints
exactly one JSON object. The model is local, private and free, but small and not fast:
1-2 s for a short question, 7-20 s to condense a few thousand tokens, and it sometimes
hangs until the timeout. Its output is advisory. You own the reasoning.

---

## Actions

1. 🔴 **Do not read the text first.** Delegation saves tokens only when the raw text never
   enters your context. If you have already read it, stop here and do the work yourself.
2. 🔴 **Size it:** `wc -lc <file>` (about 4 characters per token).
   - Under ~10,000 characters: read it yourself; the wait is not worth it.
   - ~10,000 to ~28,000 characters: continue.
   - Larger: narrow with `grep`/`tail`/`sed` first. Do not split it into several `afm` calls.
3. 🔴 **Prefer `grep` when the target has a pattern.** Test and build output does (`FAIL`,
   `error:`, `✕`): `grep -n -A8` is instant and complete, while `afm` timed out on about
   half its runs over a jest log and dropped lines when asked to filter verbatim.
4. 🔴 **Check the task is delegable:** one self-contained question, cheap to get wrong, and
   checkable by you against the source. Never delegate code, root-cause analysis,
   multi-file reasoning, architecture, security, anything irreversible, or a final decision.
5. **Call `afm` once**, piping from the source. Arguments become a steering hint when
   stdin is piped; a specific hint is the biggest quality lever.

   | Task | Use for | `response` |
   |---|---|---|
   | `summarize` | mixed logs, diffs, threads, prose | `{summary, key_points[]}` |
   | `extract` | requirements from issues and specs | `{requirements[], constraints[], unknowns[]}` |
   | `classify` | labelling a batch of lines | `{items[{input, label}]}` |
   | `critique` | second opinion on your own plan | `{concerns[{severity, category, description}]}` |
   | `brainstorm` | names, wording | `{ideas[]}` |
   | `ask` | one small question about a snippet | string |

   ```bash
   AFM=~/.agents/skills/apple-fm/scripts/afm
   gh issue view 412 --comments | $AFM extract
   git diff main | $AFM summarize "which modules changed and why"
   $AFM classify --labels compiler,test,network "compiler = errors from tsc" < errors.txt
   $AFM critique < plan.md
   ```
6. 🟡 **For `classify`, pass `--labels` and define confusable labels in the hint** (3/4
   correct without definitions, 4/4 with them).
7. 🔴 **Verify before relying on the result.** Known failure patterns: invented causality
   between unrelated lines, silently dropped items (confirm counts with `grep -c`),
   `critique` padding to five generic concerns, items duplicated across `extract` lists.
   `grep` the source for any identifier you are about to act on.
8. 🔴 **On `"ok": false`, continue the task yourself immediately.** One attempt per
   delegated task: no retry, no rephrased resend. After `afm_unavailable`, stop calling
   `afm` for the session. `timeout` is a normal outcome, not an emergency.
9. 🟡 `critique` and `brainstorm` add context rather than save it; use them for the second
   perspective, not to economize.

---

## References

- `references/delegation-policy.md` — the measurements behind these rules, where tokens
  are actually saved, and worked go/no-go examples. Read when a decision is unclear.
- `references/backend.md` — how `afm` drives `fm`, limits, error codes, metrics, adding a
  backend. Read when modifying or debugging the CLI.

---

**Pass criteria:** The raw text was never read into context before delegating; at most one
`afm` call was made per delegated task; every fact taken from the response was checked
against the source; and on any `"ok": false` the task continued without a retry.
