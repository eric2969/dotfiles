# Delegation policy

The rules in SKILL.md come from measurements on macOS 27.2 (arm64) with the on-device model `AFM 3 Core Advanced`, September 2026. Re-measure after a major macOS update; the numbers here are observations, not guarantees.

## Principles

- AFM is an accelerator, not the primary agent.
- AFM output is advisory, not authoritative.
- The main agent owns reasoning and final decisions.
- Delegation should reduce work, not create complexity.
- AFM failure must never block the main workflow.

## What was measured

| Observation | Result | Consequence |
|---|---|---|
| Context window | 8,025-token prompt accepted, 9,025 rejected | Hard limit 7,000 leaves room for the response; soft warning at 6,000 |
| Latency, short inputs (< 400 tokens) | 0.7-1.3 s free text, 2-5 s structured | Fine for `ask`, `classify`, `brainstorm`, `critique` |
| Latency, realistic inputs (1.5K-6K tokens, structured) | 7-20 s; issue thread 8-11 s, prose docs 12-16 s, 5.7K service log 14-20 s | Inputs under ~2.5K tokens are not worth the wait |
| Hangs | jest log, 3.8K tokens: about half of runs never finished within 30 s, with or without `--greedy`, streaming or not. Same log cut to 854 tokens with `grep -v`: 1 of 4 hung. Issue thread, prose, service log: 0 of 10 | The timeout is a normal outcome, not an edge case. Pattern-shaped output goes to `grep` |
| `--greedy` | Hung on every run of the jest log | The CLI always samples |
| `extract` on a 1.7K-token issue thread | 3/3 runs recalled 11/11 planted facts and 3/3 open questions; items were often duplicated across `requirements` and `constraints` | Reliable recall, sloppy bucketing; re-sort the items yourself |
| `summarize` on a 5.7K-token service log | 4/4 runs surfaced both ERROR lines among 150 | Works where you do not know the pattern in advance |
| Token counting | `fm count-tokens` takes ~45 ms | Exact pre-check on every call, no character-based guessing |
| Free-text output | Often opens with "I am a foundation model created by Apple..." and varies run to run | Every task except `ask` uses structured output |
| Verbatim line filtering | Asked for every error line, returned 1 of 3 | Use `grep` for pattern filters; never AFM |
| Structured extraction, string fields | Both compiler errors returned with exact path and line, 2.3 s | Schemas copy identifiers reliably |
| Schema with `integer` fields nested in an array | Generated until the context filled; minutes, then a misleading "context size" error | Bundled schemas are string-only; timeout kills the process; error is reported as `generation_overflow` |
| `enum` in schema | Honoured | `classify --labels` and `critique` categories are hard-constrained |
| Classification without label definitions | 3/4 correct (`error TS2304` labelled `test`) | Put label definitions in the hint |
| Classification with label definitions | 4/4 correct | |
| Traditional Chinese input and output | Accurate, fluent | Non-English text is fine |
| Default guardrails on hostile-sounding logs ("kill -9", "brute force attack") | No refusal | No guardrail flag needed for engineering text |
| Summary of unrelated log lines | Invented a causal chain between them | Trust copied facts, not connective narrative |
| `critique` of a small plan | Returned exactly five concerns, one per category | Expect padding; keep only specific concerns |

## What an end-to-end trial showed

Six subagent runs on three tasks (3.8K-token jest log, 1.5K-token issue thread, 34K-token service log), with and without the skill:

- Every run cost 36K-42K total tokens, dominated by the agent's fixed overhead. The file being condensed was 4-10% of that, so one delegation can save at most a few percent of a short task, while loading this skill costs about 2.5K tokens.
- The skill therefore pays only when several delegations happen in one session, or when the session is long enough that text kept out of context early is not re-sent on many later turns.
- Agents read the target file before the skill's rules reached them. The "size it before you read it" step exists because of that.
- On the 34K-token log the skill-equipped agent correctly chose `grep`, did not call AFM and did not chunk.

## Where tokens are actually saved

The saving is `tokens of raw input you did not read` minus `tokens of the JSON you did read`. That is only positive when the raw text is piped from its source and never displayed to you.

| Task | Saves tokens? | Why |
|---|---|---|
| `summarize` on mixed logs, diffs, prose | Yes | Thousands of tokens become a few hundred. Pattern-shaped output (test, build) is cheaper and safer through `grep` |
| `extract` on long threads | Yes | Discussion collapses into three short lists |
| `classify` on a batch | Somewhat | The input lines are echoed back, so the saving comes from not reasoning over them |
| `ask` on a snippet | Marginal | Useful for a relevance check before deciding to read a file |
| `critique` | No | You already paid to write the plan and now read feedback too; the value is a second view |
| `brainstorm` | No | Output is small either way |

## Worked examples

**Delegate.** A 60-comment issue thread, about 5,000 tokens, mostly "+1" and status pings. `gh issue view 412 --comments | scripts/afm extract`, then `grep` the thread for any item you are about to rely on.

**Do not delegate: the output has a pattern.** `cargo build` or `jest` printed 4,000 tokens and you need the failures. `grep -n -A8 -E "error|FAIL|✕"` is instant and complete; AFM took 7-10 seconds when it worked and hung about half the time on this kind of input.

**Do not delegate: grep is better.** You need every line containing `ERROR` from a log. `grep -n ERROR app.log` is exact and instant.

**Do not delegate: already read.** You read a 3,000-token diff two turns ago and the user asks for a summary. The tokens are spent. Write the summary yourself.

**Do not delegate: too small.** A 20-line stack trace. Reading it costs less than waiting.

**Do not delegate: too large.** A 40,000-token log. Do not chunk it into six calls. Narrow it first (`tail -300`, `grep -C3 -i fail`) and then decide whether what remains is still worth delegating.

**Do not delegate: not checkable.** "Is this authentication flow secure?" A wrong answer is expensive and you could not tell it was wrong.

**Delegate for perspective.** You drafted a migration plan and want a quick sanity check before presenting it. `scripts/afm critique < plan.md`, keep any concern that names a real gap, ignore the rest.

## Limits on delegation

- One AFM attempt per delegated task. No retries, no rephrased resends.
- No recursive or fan-out delegation. If a task needs many AFM calls, it is not a small task.
- After `afm_unavailable`, stop calling `afm` for the session.
- Never pass secrets you would not write to a local process. The model runs on-device and the CLI logs no content, but the principle of least exposure still applies.
