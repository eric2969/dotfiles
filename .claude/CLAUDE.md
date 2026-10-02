# Working Rules

## Skills

Skill descriptions are listed at the start of every session; load a skill when the task
matches its description. Two of them are easy to forget because nothing in the request
names them:

- Load the matching `*-dev` skill (`go-dev`, `ts-dev`, `python-dev`) before writing or
  editing code in that language — it holds the conventions I expect.
- Run `verify` after finishing a code change and before every commit or push.

Precedence: my instructions, then skills, then defaults. A task that matches no skill
needs no skill.

## Coding rules (all languages)

1. Code comments in English only, even when we talk in Chinese. Markers: `TODO:` future
   work, `FIXME:` known bug, `XXX:` serious hack — each with an actionable description.
2. Clarity over cleverness: explicit code, no hidden magic.
3. A linter suppression (`nolint`, `eslint-disable`, `# type: ignore`, …) needs a comment
   naming the specific rule and the reason.
4. Small focused functions, early returns over deep nesting.
5. Handle every error explicitly; never swallow a failure.
