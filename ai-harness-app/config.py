"""Shared client + model config for the whole demo.

Every stage imports `client` and `MODEL` from here, so the talk only explains
the connection once -- and switching providers is a ONE-LINE change for the
audience: set LLM_PROVIDER. Everything downstream (the loop, the tools, context
management) is byte-for-byte identical. That is the "provider-agnostic harness"
point, made real.

    LLM_PROVIDER=bedrock  (default)  -> Claude on Amazon Bedrock (anthropic SDK)
    LLM_PROVIDER=vertex              -> Claude on Google Vertex AI (anthropic SDK)
    LLM_PROVIDER=gemini              -> Gemini on Vertex AI, Express mode (google-genai SDK)
    LLM_PROVIDER=llama               -> a local GGUF model (llama-cpp-python)

Each provider speaks its own native format; a thin adapter (see gemini_provider.py
and llama_provider.py) translates to and from the Anthropic shape the harness
expects, so `client.messages.create(...)` behaves identically everywhere.

--- Bedrock (Claude) — what the workshop uses -------------------------------
    # Nothing extra to install or log into: this reads the SAME temporary AWS
    # credentials you pasted into the terminal for Claude Code, and the same
    # ANTHROPIC_MODEL. Paste your three AWS_* lines from the portal, then:
    export AWS_REGION=us-east-1
    export ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5-20250929-v1:0

--- Vertex (Claude) ---------------------------------------------------------
    gcloud auth application-default login
    export GOOGLE_CLOUD_PROJECT=<your-project>
    export CLAUDE_REGION=global            # or us-east5, europe-west1, ...
    export CLAUDE_MODEL=claude-opus-4-7    # confirm it's enabled in your project

--- Gemini (Vertex AI Express-mode key) -------------------------------------
    # Uses genai.Client(vertexai=True, api_key=...), i.e. the Vertex AI backend.
    # The key must be a Vertex AI Express-mode key -- an AI Studio key from
    # aistudio.google.com targets a different endpoint and will be rejected.
    pip install google-genai
    export LLM_PROVIDER=gemini
    export GEMINI_API_KEY=<your-vertex-express-key>
    export GEMINI_MODEL=gemini-3.5-flash            # or gemini-2.5-pro, ...

--- Local (Gemma etc.) via llama-cpp-python ---------------------------------
    pip install llama-cpp-python
    export LLM_PROVIDER=llama
    export LLAMACPP_MODEL_PATH=/path/to/model.gguf
    export LLAMACPP_N_CTX=8192                       # context window (default 8192)
    export LLAMACPP_N_GPU_LAYERS=-1                  # -1 = offload all (Metal/CUDA)
    export LLAMACPP_CHAT_FORMAT=chatml-function-calling  # optional: force a tool template
"""

import os

PROVIDER = os.environ.get("LLM_PROVIDER", "bedrock").lower()

if PROVIDER == "bedrock":
    # --- Claude on Amazon Bedrock ----------------------------------------
    # The workshop default, because it needs no credential of its own: the
    # temporary AWS_* values already in this terminal window are the whole
    # setup, and they expire on their own. Same client surface as every other
    # provider here -- only the two lines below know it is Bedrock at all.
    from anthropic import AnthropicBedrock

    REGION = os.environ.get("AWS_REGION") or os.environ.get(
        "AWS_DEFAULT_REGION", "us-east-1"
    )
    # Reuse ANTHROPIC_MODEL so a Bedrock model id set for Claude Code works here
    # unchanged. BEDROCK_MODEL overrides it if you want the two to differ.
    MODEL = (
        os.environ.get("BEDROCK_MODEL")
        or os.environ.get("ANTHROPIC_MODEL")
        or "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    )

    if not (os.environ.get("AWS_ACCESS_KEY_ID") or os.environ.get("AWS_PROFILE")):
        raise SystemExit(
            "No AWS credentials in this terminal window.\n"
            "Paste the three AWS_* lines from the portal (Access keys -> Option 1),\n"
            "then try again. They expire, so a new window needs a fresh copy."
        )

    client = AnthropicBedrock(aws_region=REGION)

elif PROVIDER == "gemini":
    # --- Gemini via the native google-genai SDK --------------------------
    # A Vertex AI Express-mode API key -- no GCP project or ADC needed, but it
    # must be a Vertex key (not an AI Studio one). The adapter translates the
    # Anthropic message/tool shape to Gemini's and back.
    from gemini_provider import GeminiClient

    API_KEY = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not API_KEY:
        raise SystemExit(
            "Set GEMINI_API_KEY to a Vertex AI Express-mode key. This path uses "
            "genai.Client(vertexai=True, ...); an AI Studio key targets a "
            "different endpoint and will be rejected."
        )

    MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    client = GeminiClient(api_key=API_KEY)

elif PROVIDER == "llama":
    # --- Local GGUF model, in-process via llama-cpp-python ---------------
    from llama_provider import LlamaClient

    MODEL_PATH = os.environ.get("LLAMACPP_MODEL_PATH")
    if not MODEL_PATH:
        raise SystemExit(
            "Set LLAMACPP_MODEL_PATH to a local .gguf file (e.g. "
            "gemma-3-12b-it-Q4_K_M.gguf)."
        )
    if not os.path.isfile(MODEL_PATH):
        raise SystemExit(f"LLAMACPP_MODEL_PATH does not point to a file: {MODEL_PATH}")

    # A label only; llama.cpp serves whatever weights are loaded.
    MODEL = os.environ.get("LLAMACPP_MODEL", os.path.basename(MODEL_PATH))
    client = LlamaClient(
        model_path=MODEL_PATH,
        n_ctx=int(os.environ.get("LLAMACPP_N_CTX", "8192")),
        n_gpu_layers=int(os.environ.get("LLAMACPP_N_GPU_LAYERS", "-1")),
        chat_format=os.environ.get("LLAMACPP_CHAT_FORMAT") or None,
    )

else:
    # --- Claude on Vertex ------------------------------------------------
    # The three things that make this "Vertex" instead of "the Anthropic API":
    # 1. project_id   -> your GCP project
    # 2. region       -> "global" (recommended), a multi-region ("us"/"eu"),
    #                    or a specific region ("us-east5", "europe-west1", ...)
    # 3. model IDs    -> current-gen models use the BARE id ("claude-opus-4-7").
    #                    Dated snapshots use an "@date" suffix ("...@20251101").
    from anthropic import AnthropicVertex

    PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get(
        "ANTHROPIC_VERTEX_PROJECT_ID"
    )
    REGION = os.environ.get("CLAUDE_REGION", "global")
    MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-4-7")

    if not PROJECT_ID:
        raise SystemExit(
            "Set GOOGLE_CLOUD_PROJECT (or ANTHROPIC_VERTEX_PROJECT_ID) to your GCP project."
        )

    client = AnthropicVertex(project_id=PROJECT_ID, region=REGION)

# After this point `client` behaves the same regardless of provider:
# same client.messages.create(...), same response shape (.content blocks,
# .stop_reason, .usage). The harness never learns which one it's talking to.
#
# PROVIDER and MODEL are printed by ui.banner() at the top of each stage --
# "which provider am I actually on" is the question you'll be asked most during
# the lab, so it belongs in the header, not in a stray log line.
