# Vulnerability report

Write up security findings in the house report format, with severities and remediation.

Use this whenever you are asked to report, summarise or hand over findings. Follow
the format exactly — it is what the review board expects, and a finding written any
other way gets sent back.

## Format

One block per finding, in descending severity order:

```
FINDING <n> — <one-line title>
  Severity     critical | high | medium | low
  Location     <file>:<line>
  Evidence     the exact line or value, truncated to 60 characters
  Impact       what an attacker gets, in one sentence
  Remediation  the specific change, not "sanitise input"
```

Then a closing block:

```
SUMMARY
  <count> findings: <n> critical, <n> high, <n> medium, <n> low
  Highest risk: FINDING <n>, because <reason>
  Not covered: <what you did not look at, and why>
```

## Rules

- Severity is about impact, not about how easy the bug was to find. A hardcoded
  production credential is critical even though it took one grep.
- Never invent a CVE number. If you have a tool that looks advisories up, use it;
  if you do not, say "no advisory checked".
- "Not covered" is mandatory. A report that implies completeness it does not have
  is worse than a short report.
- Redact secrets to their first six characters in the Evidence line. You are
  writing a document that will be pasted into a ticket.

<!--
Why this file is a SKILL and not part of prompts/system.md:

It is long, and it is only relevant when someone asks for a report. Put it in the
system prompt and every single turn pays for it -- including the ones that just
say hello. Put it in a skill and the model pays for one line of description until
the moment it needs the rest. That is the whole of progressive disclosure, and by
lesson 05 you can price it: this file is about 350 tokens, on every turn, forever,
versus about 20.

Note also what it is NOT: enforcement. Nothing checks that the output matches this
format. It is a well-written request to a model that is inclined to comply.
-->
