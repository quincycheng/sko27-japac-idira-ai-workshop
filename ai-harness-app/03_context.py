"""LESSON 03 — Context engineering: everything the model sees, and who decided.

The model has one input: a flat stream of tokens. This lesson puts three things
into that stream on purpose and watches what each one costs.

    1. RULES        prompts/system.md  -- who the agent is, and how it should work
    2. OUTPUT STYLE styles/*.md        -- how the answer should be written
    3. HISTORY      the transcript     -- lesson 02, still running

All three are files or lists WE control. None of them are properties of the model.
Together they are "context engineering", and the gauge at the bottom of every
answer is the bill.

Two things this lesson exists to show:

  * THE DUMB ZONE. As the window fills, answers get worse -- less precise, more
    forgetful of their own earlier claims -- and nothing in the output announces
    it. The gauge turns amber at 50% to make an invisible failure visible. That
    threshold is a teaching device, not a published number.

  * THE WALL. Keep going and the request stops fitting entirely. It does not
    degrade; it fails. `/compact` folds the middle of the conversation into a
    note and buys the room back.

    Talking your way to the wall on this model takes about twenty turns, at
    roughly five percent a turn. If you do not have twenty turns, `/fill`
    pads the transcript with clearly-labelled filler and puts the wall one
    question away. The filler is fake; everything that then happens to it --
    the tokens, the cost, the refusal from Bedrock -- is not.

  * HISTORY OUTWEIGHS INSTRUCTIONS. Switch to `/style eli5` after three long
    answers and you get a shorter answer -- but still with the headings and
    bullets the style forbids, because the model is copying the three examples
    in front of it rather than obeying the file. `/reset` first and the same
    style produces 139 output tokens against deep-dive's 397. Measured on this
    model, this week; the ratio will differ, the effect will not.

    That is worth more than the token count. An instruction competes with
    everything else in the window, and it does not automatically win. Anyone
    planning to control an agent by wording its prompt more firmly should watch
    this happen once.

One thing to notice about WHERE the instructions go. This model does have a
system role, so they travel in the API's `system` field, which sounds like a
boundary and is not one: by the time the model reads them they are tokens in the
same single stream as your question. `/system` shows you the text; the footer
shows you what it cost. Point a lesson at Mistral 7B instead (see config.py) and
the harness has to prepend the same text into your first message, because that
model has no system field at all -- same tokens, same effect, and the pretence of
a boundary drops away entirely.

Everything a tool returns will land in that same undivided stream in lesson 04,
which is why lesson 05 happens.

Run it:
    python 03_context.py
    python 03_context.py eli5        # start on the short style instead
"""

import sys

import session
import ui

# Three questions that each pull a long answer, so the gauge moves visibly
# within a minute rather than over twenty. On the deep-dive style these run
# several hundred tokens each.
QUESTIONS = [
    "What is an AI agent, and how is it different from a chatbot?",
    "Why is a long conversation a security problem as well as a cost problem?",
    "What could go wrong if an agent can read files and also read its own instructions?",
]


def main() -> None:
    style = sys.argv[1] if len(sys.argv) > 1 else "deep-dive"

    chat = session.Session(
        tier="legacy",
        remember=True,
        system=session.read_prompt("system"),
        style=style,
        max_tokens=600,
    )

    ui.banner("Lesson 03 — context engineering", chat.model_id, chat.caps)
    ui.system_view(chat.system_prompt, chat.style_text, chat.caps.system)

    for question in QUESTIONS:
        ui.task(question)
        if chat.send(question) is None:
            # Hit the wall mid-script. That is a fine place to stop -- it is the
            # lesson, and the panel just printed says what to do about it.
            break

    ui.note("Now: /style eli5 — then ask the same question again.")
    ui.note("Shorter, but still bulleted: it is copying the answers above it.")
    ui.note("Now /reset and ask once more. 139 tokens, not 397. Prose costs money.")
    ui.note("Then /fill 60 for the dumb zone, or /fill to stand at the wall.")
    ui.note("At the wall, ask one more question — then /compact and ask it again.")

    session.chat(chat)


if __name__ == "__main__":
    main()
