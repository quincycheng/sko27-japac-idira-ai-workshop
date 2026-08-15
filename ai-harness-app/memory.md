- The repository under `sandbox/` is a deliberately vulnerable demo. Its
  credentials are fake, so report them as findings but do not treat them as an
  incident.
- Findings must be written up using the `vuln-report` skill. The review board
  rejects any other format.
- `requirements.txt` is pinned to old versions on purpose. Always check it against
  the advisory service rather than assuming it is current.

<!--
This file is the agent's memory. Lesson 05 prepends it to the context on every
run; nothing before Lesson 05 reads it at all. The HTML comments are stripped
before it is sent, exactly as in prompts/system.md, so this note costs nothing.

Two things to say out loud when it goes on screen.

FIRST: memory is what makes an agent feel like a colleague rather than a tool. The
second line above is why the agent in Lesson 05 reaches for the vuln-report skill
without being told to. Nobody typed that instruction this session. It remembered.

SECOND, and this is the part a security audience should sit with: this file is
plain text, it is not signed, it is read on every run, and anything that can write
here can change what your agent believes about the world -- permanently, silently,
and for every future session. An attacker who gets one line into an agent's memory
does not need to attack it again.

Whatever writes to memory needs the same scrutiny as whatever grants it
credentials. That is EPM's argument for the CLI, and the AI Agent Identity Broker's for
the tools it reaches. See lab/reference/securing-agentic-ai.html.

If attendees leave this file a mess, `git checkout ai-harness-app/memory.md`.
-->
