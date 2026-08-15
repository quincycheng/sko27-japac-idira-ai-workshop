"""Shared client + model config for the whole demo.

Every lesson imports `pick_model()` from here, so the talk only explains the
connection once. Two things live in this file and nowhere else:

  1. WHICH MODELS EXIST -- the registry below. Part 1 runs on two tiers on
     purpose (see MODELS), and the lessons switch between them.
  2. WHICH PROVIDER YOU ARE ON -- one env var, LLM_PROVIDER.

--- The honest bit, and the reason this file is shaped like this ---------------
The old version of this file claimed "the harness never learns which model it is
talking to". That is true of the *format* and false of the *capability*. An
adapter can make two models answer the same call; it cannot make last year's
model grow tool support. So every model here ships a CAPABILITY RECORD -- tools yes/no,
system role yes/no, window size -- the lessons read and the footer displays.

Format is a replaceable part. Capability is not. That distinction is the answer
to the first question a customer asks about bringing their own model.

--- Bedrock (the workshop default) ------------------------------------------
    # Nothing extra to install or log into: this reads the SAME temporary AWS
    # credentials you pasted into the terminal for Claude Code.
    export AWS_REGION=us-east-1
    export ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5-20250929-v1:0

    Both tiers are Bedrock model IDs, so one login covers both. Each one has to
    be enabled in the account AND permitted by your elevated role --
    model access and bedrock:InvokeModel are two separate switches.

--- The other providers, unchanged and unused by the lab ---------------------
    LLM_PROVIDER=vertex   -> Claude on Google Vertex AI (anthropic SDK)
    LLM_PROVIDER=gemini   -> Gemini on Vertex AI, Express mode (google-genai SDK)
    LLM_PROVIDER=llama    -> a local GGUF model (llama-cpp-python)

    These stay for people who want to try them at home. The in-app model picker
    is deliberately Bedrock-only: a dropdown spanning four providers implies four
    working credential setups on sixty laptops.

    export LLM_PROVIDER=gemini && export GEMINI_API_KEY=<vertex-express-key>
    export LLM_PROVIDER=llama  && export LLAMACPP_MODEL_PATH=/path/to/model.gguf
"""

import os
from types import SimpleNamespace

PROVIDER = os.environ.get("LLM_PROVIDER", "bedrock").lower()


# --- TLS: this app does not verify certificates, and this is the only place ----
#
# READ THIS BEFORE YOU COPY ANYTHING OUT OF THIS FILE.
#
# Every outbound HTTPS connection in Part 1 is made with certificate
# verification switched OFF. That is a deliberate workshop decision with exactly
# one justification: a corporate TLS-inspecting proxy on an attendee's laptop
# would otherwise end their session at lesson 01 with an error nobody in the room
# can fix, and we would spend the hour on trust stores instead of on agents.
#
# It is the wrong choice everywhere else. Unverified TLS means anything on the
# path can read and rewrite what you send to the model and what comes back --
# including, in lesson 04 onward, the tool calls the agent decides to make. If you
# would not accept that for a database connection, do not accept it for this.
#
# What you would do instead, in a client environment: point the trust store at the
# proxy's own root CA and keep verification on.
#
#     export AWS_CA_BUNDLE=/path/to/corp-root.pem
#     export SSL_CERT_FILE=/path/to/corp-root.pem
#
# One function and one call. If a Domain Consultant greps this repo -- and they
# will -- there is a single honest answer to "where did you turn it off?", which
# is worth more than a shortcut nobody admits to.
_VERIFY_TLS = False


def _hush_tls_warnings() -> None:
    """Stop urllib3 shouting about the choice we just made, on every request.

    botocore's transport is urllib3, which emits InsecureRequestWarning per host.
    On a projector that reads as a broken lab, and it is not news: the warning is
    telling us the thing the comment above already says at length.
    """
    import warnings

    warnings.filterwarnings("ignore", message=".*[Uu]nverified HTTPS request.*")
    try:
        import urllib3

        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    except Exception:
        # urllib3 arrives with botocore, so this only fires on a provider that
        # does not use it. The filterwarnings call above already covers us.
        pass


def insecure_http_client(timeout=600.0):
    """An httpx client with verification off, for every SDK that accepts one.

    The anthropic SDK (Bedrock and Vertex) takes `http_client=`, and so does
    google-genai indirectly. Returning the client from here rather than building
    one per provider is what keeps `_VERIFY_TLS` a single fact.
    """
    import httpx

    _hush_tls_warnings()
    return httpx.Client(verify=_VERIFY_TLS, timeout=timeout, follow_redirects=True)


_hush_tls_warnings()


# --- The capability record ---------------------------------------------------
def capabilities(name, model_id, window, tools, system, note=""):
    """What this model can actually do. Four facts, printed in the footer.

    `window` is the model's REAL context window, because the gauge is a
    percentage of it. If you ever have to gauge against a budget we chose
    instead, say so on screen -- labelling our own number as the model's ceiling
    would be the one dishonest thing on the display.
    """
    return SimpleNamespace(
        name=name,
        model_id=model_id,
        window=window,
        tools=tools,
        system=system,
        note=note,
    )


# --- The registry ------------------------------------------------------------
# Two tiers, named by CAPABILITY rather than by age or marketing tier. The
# lessons switch from one to the other at lesson 04, and by then attendees have
# already driven the legacy model into its own context wall -- so the upgrade is
# a conclusion they reached, not an assertion we made.
#
# The legacy tier is a genuinely old model, not the good one with its hands tied.
# This room reads config files for a living; a dropdown that says "legacy" while
# Sonnet answers underneath is a credibility problem, not a shortcut.
MODELS = {
    "legacy": capabilities(
        name="legacy",
        model_id=os.environ.get("LEGACY_MODEL", "meta.llama3-8b-instruct-v1:0"),
        window=int(os.environ.get("LEGACY_WINDOW", "8192")),
        tools=False,
        system=True,
        note="April 2024. No tools, and an 8,192-token window it enforces exactly.",
    ),
    "frontier": capabilities(
        name="frontier",
        model_id=(
            os.environ.get("BEDROCK_MODEL")
            or os.environ.get("ANTHROPIC_MODEL")
            or "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
        ),
        window=int(os.environ.get("FRONTIER_WINDOW", "200000")),
        tools=True,
        system=True,
        note="Current. Tools, a 200k window, and it follows instructions.",
    ),
}

# --- Why THIS legacy model, and what to swap to -------------------------------
#
# Llama 3 8B Instruct is here for one reason above all others: its window is 8,192
# tokens and Bedrock enforces that number exactly. Lesson 03 needs a model an
# attendee can genuinely fill in five minutes of talking, because a gauge that
# never leaves 1% teaches nothing and a dumb zone nobody reaches is a claim rather
# than an experience. It also has no tool support, which is what makes lesson 04's
# upgrade a conclusion instead of an announcement.
#
# It is NOT the cheapest model on Bedrock, and that was a deliberate trade. The
# cheaper candidates all have windows of 32k or more, which costs the lesson its
# best five minutes to save a fraction of a cent per attendee.
#
# WHAT HAPPENED TO TITAN. `amazon.titan-text-express-v1` was the obvious choice --
# 2023, no tools, no system role, 8k, cheapest of all -- and it is now end-of-life:
# Bedrock answers a Converse call with ResourceNotFoundException, "This model
# version has reached the end of its life." Same for claude-instant-v1. Worth
# saying out loud in the room, because it is the lesson underneath the lesson: the
# model is the part of your stack with the shortest support window, and anything
# you build that only works with one model has an expiry date you do not control.
#
# TO SEE THE NO-SYSTEM-ROLE PATH. Mistral 7B refuses a system prompt entirely, so
# the harness has to prepend the instructions into the first user message instead
# (session.py._payload). That is worth five minutes if you have them:
#
#     export LEGACY_MODEL=mistral.mistral-7b-instruct-v0:2
#     export LEGACY_WINDOW=32000
#
# and set system=False in the record above, or the adapter will tell you to. The
# 32k window is the cost: the gauge crawls, and the wall moves out of reach.


def _bedrock_client(caps):
    """One AWS login, two SDK paths -- because the models are from two vendors.

    Anthropic models on Bedrock: the anthropic SDK, which speaks their native
    format. Everything else on Bedrock (Llama, Mistral, Nova): boto3's Converse
    API. `converse_provider` wraps the second one so both look identical upstream.
    """
    region = os.environ.get("AWS_REGION") or os.environ.get(
        "AWS_DEFAULT_REGION", "us-east-1"
    )

    if not (os.environ.get("AWS_ACCESS_KEY_ID") or os.environ.get("AWS_PROFILE")):
        raise SystemExit(
            "No AWS credentials in this terminal window.\n"
            "Paste the three AWS_* lines from the portal (Access keys -> Option 1),\n"
            "then try again. They expire, so a new window needs a fresh copy."
        )

    if caps.model_id.startswith("anthropic.") or ".anthropic." in caps.model_id:
        from anthropic import AnthropicBedrock

        # http_client is how the anthropic SDK lets us hand it a transport with
        # verification off. See the TLS note at the top of this file.
        return AnthropicBedrock(aws_region=region, http_client=insecure_http_client())

    from converse_provider import ConverseClient

    return ConverseClient(region=region)


def pick_model(tier="frontier"):
    """Return (client, model_id, caps) for one tier of the registry.

    This is the ONLY function the lessons call. Switching models at runtime --
    the app's /model command -- is just calling it again with the other tier.
    """
    if tier not in MODELS:
        raise SystemExit(
            f"Unknown model tier '{tier}'. Known tiers: {', '.join(MODELS)}."
        )
    caps = MODELS[tier]

    if PROVIDER == "bedrock":
        return _bedrock_client(caps), caps.model_id, caps

    # --- The non-Bedrock providers ------------------------------------------
    # One tier only: these exist so the lessons run on another provider at home,
    # not so the picker spans four clouds. The capability record is whatever the
    # chosen model actually is, so override the two env vars if it differs.
    if PROVIDER == "gemini":
        from gemini_provider import GeminiClient

        api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        if not api_key:
            raise SystemExit(
                "Set GEMINI_API_KEY to a Vertex AI Express-mode key. This path uses "
                "genai.Client(vertexai=True, ...); an AI Studio key targets a "
                "different endpoint and will be rejected."
            )
        model_id = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
        caps = capabilities("gemini", model_id, 1000000, True, True, "google-genai SDK")
        return GeminiClient(api_key=api_key), model_id, caps

    # Note for the two paths above and the Vertex one below: they are optional and
    # nobody in the room runs them, so they are the least-tested code in the repo.
    # They get the same TLS treatment anyway -- a provider switch should not
    # quietly change the security properties of the thing you are demonstrating.

    if PROVIDER == "llama":
        from llama_provider import LlamaClient

        model_path = os.environ.get("LLAMACPP_MODEL_PATH")
        if not model_path:
            raise SystemExit(
                "Set LLAMACPP_MODEL_PATH to a local .gguf file (e.g. "
                "gemma-3-12b-it-Q4_K_M.gguf)."
            )
        if not os.path.isfile(model_path):
            raise SystemExit(
                f"LLAMACPP_MODEL_PATH does not point to a file: {model_path}"
            )
        n_ctx = int(os.environ.get("LLAMACPP_N_CTX", "8192"))
        model_id = os.environ.get("LLAMACPP_MODEL", os.path.basename(model_path))
        # A local model's window is whatever you loaded it with, so n_ctx IS the
        # honest number here.
        caps = capabilities("local", model_id, n_ctx, True, True, "llama-cpp-python")
        client = LlamaClient(
            model_path=model_path,
            n_ctx=n_ctx,
            n_gpu_layers=int(os.environ.get("LLAMACPP_N_GPU_LAYERS", "-1")),
            chat_format=os.environ.get("LLAMACPP_CHAT_FORMAT") or None,
        )
        return client, model_id, caps

    # --- Claude on Vertex ----------------------------------------------------
    from anthropic import AnthropicVertex

    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get(
        "ANTHROPIC_VERTEX_PROJECT_ID"
    )
    if not project_id:
        raise SystemExit(
            "Set GOOGLE_CLOUD_PROJECT (or ANTHROPIC_VERTEX_PROJECT_ID) to your GCP project."
        )
    model_id = os.environ.get("CLAUDE_MODEL", "claude-opus-4-7")
    caps = capabilities("vertex", model_id, 200000, True, True, "anthropic SDK")
    client = AnthropicVertex(
        project_id=project_id,
        region=os.environ.get("CLAUDE_REGION", "global"),
        http_client=insecure_http_client(),
    )
    return client, model_id, caps


# After this point every client behaves the same regardless of provider: same
# client.messages.create(...), same response shape (.content blocks,
# .stop_reason, .usage). What differs is CAPS -- and the lessons read that
# out loud rather than pretending it away.
