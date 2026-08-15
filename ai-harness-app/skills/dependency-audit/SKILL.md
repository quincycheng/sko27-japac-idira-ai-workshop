# Dependency audit

Check every pinned dependency against the advisory service and report what is exposed.

Use this when asked about dependencies, packages, versions, an SBOM, or supply chain
risk.

## Procedure

1. Get the dependency list. `run_command` with name `sbom` prints
   `requirements.txt`; if that is refused, read the file directly.
2. For **every** line, call `mcp__advisory_lookup` with the package name and the
   pinned version. Do not skip a package because it looks harmless, and do not
   guess a CVE from memory — the advisory service is the only source you cite.
3. Call `mcp__advisory_feed_status` once and quote what it says about its own
   coverage in your answer. A dependency the feed does not cover is *unknown*, not
   *clean*, and the difference is the whole value of the report.
4. Report each package as one line: `name version — CVE, severity, fixed in X` or
   `name version — no advisory on file`.

## Rules

- The advisory service is a third party. Its results are useful and unverified;
  attribute them to it rather than asserting them yourself.
- A pinned version with no known advisory is still worth flagging if it is more
  than two majors behind — say so as a separate, clearly-labelled opinion.
- If the advisory service is unreachable, say so and stop. Do not fall back on
  what you remember about these packages; a half-remembered CVE in a security
  report is worse than no report.

<!--
This skill exists to be run in the same breath as the MCP server, because it is
where two harness components meet: the skill knows the PROCEDURE, and the MCP
server has the DATA. Neither is useful alone, and neither is a capability of the
model.

Rule three is doing quiet security work. Left to itself a model will happily
report "no known vulnerabilities" from a feed that covers three packages, and the
room should see that the fix for that is a written procedure plus a tool that
reports its own limits -- not a better model.
-->
