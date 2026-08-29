"""Build notifications for a summarised incident.

Nothing is actually sent — this is a dry run that prints the payloads it
would post. Run it to see which systems this app talks to.

Usage:
    python notify.py "Summary text here"
"""

import json
import sys
from pathlib import Path

CONFIG = json.loads(
    (Path(__file__).parent / "config" / "integrations.json").read_text(encoding="utf-8")
)


def slack_payload(summary):
    return {
        "url": CONFIG["slack"]["webhook_url"],
        "body": {"channel": CONFIG["slack"]["channel"], "text": summary},
    }


def github_payload(summary):
    cfg = CONFIG["github"]
    return {
        "url": f"{cfg['api_url']}/repos/{cfg['repository']}/issues",
        "headers": {"Authorization": f"token {cfg['personal_access_token']}"},
        "body": {"title": "Incident summary", "body": summary},
    }


def main():
    summary = sys.argv[1] if len(sys.argv) > 1 else "(no summary provided)"
    print("DRY RUN — nothing is sent.\n")
    for name, payload in (("slack", slack_payload), ("github", github_payload)):
        print(f"--- {name} ---")
        print(json.dumps(payload(summary), indent=2))
        print()
    print(f"database: {CONFIG['database']['url']}")


if __name__ == "__main__":
    main()
