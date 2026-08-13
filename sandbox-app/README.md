# Incident Summariser (sandbox app)

A small Python app that reads a security incident report and asks Amazon Bedrock to
summarise it.

> ⚠️ **This app is deliberately insecure.** It is workshop material. Every credential in
> it is a **fake placeholder** — none of them work anywhere. Do not use this code as a
> pattern for anything real.

## Files

| File | What it does |
| --- | --- |
| `summarize.py` | Reads a report, calls Bedrock, prints a summary |
| `notify.py` | Builds Slack and GitHub notifications (dry run — sends nothing) |
| `config/settings.py` | Bedrock region, model, and AWS credentials |
| `config/integrations.json` | GitHub, Slack, and database settings |
| `sample-incident.txt` | An example report to summarise |

## Run it

Dependencies go into a virtual environment, never into your system Python — no admin rights,
nothing installed globally. From the **workshop root** (the folder above this one):

```
python -m venv .venv                      # once
source .venv/bin/activate                 # macOS: every new terminal window
pip install -r sandbox-app/requirements.txt
```

On Windows PowerShell, activate with `.\.venv\Scripts\Activate.ps1` instead. Your prompt shows
`(.venv)` when it is active. Then:

```
cd sandbox-app
python summarize.py
```

It will fail. Working out **why** it fails, and what that tells you about how it was
built, is the first exercise.
