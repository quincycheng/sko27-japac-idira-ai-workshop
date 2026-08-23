<!-- The Idira thread through the whole lab: one entry per lesson, plus one
     record per product.

     WHY THIS FILE EXISTS
     Every lesson ends by naming the risk it just demonstrated and the Idira
     products that answer it. Written by hand that is the same mapping in fifteen
     places, and product positioning drifts faster than code does: a product gets
     renamed and now six lessons are quietly wrong in front of an audience that
     sells it for a living.

     So it lives here once. build-lab-code.py generates the block in each lesson
     from these entries, the same way it generates the source listings from
     lab/annotations/*.md. The product records below feed the idira-table marker,
     which no page carries at the moment.

     FORMAT — two kinds of section, no library, same parser style as the
     annotations.

     A lesson entry:

         ## 01                            the lesson number
         risk:    one sentence            what the lesson just showed you
         product: Name -- one sentence    a product, and what it does about it
         say:     one sentence            what you say to a customer

     `risk` and `say` appear once. `product` appears as many times as the lesson
     needs, in the order they should be read — the first one is the answer an
     attendee just watched work, the rest are what the same conversation opens up.

     A product record, which fills one row of the reference page's table:

         ## product: Secure Cloud Access
         tag:      four or five words     the sublabel under the product name
         risk:     one sentence           the risk it answers
         controls: one sentence           what it ACTUALLY controls
         met:      01, 02                 lessons where it is named
         hands-on: 09                     lessons where it is run  (optional)

     `met` and `hands-on` are lesson numbers — 00 is the setup page — and the
     generator turns them into links by reading the PAGES array out of
     assets/lab.js, so there is no second copy of the page list. Every product
     named by a lesson entry must have a record here; the build fails if one does
     not, which is the whole point of the file.

     Keep every line to a single sentence. The full treatment belongs on the
     reference page; this is the thread, not the documentation. `inline code` and
     **bold** work anywhere.
-->

## 01

risk: An agent inherits whatever identity the process it runs in has.

product: Secure Cloud Access -- Issues cloud access on request and expires it. Nothing you ran in this lesson needed a stored credential.

product: Secrets Manager SaaS -- Holds and rotates the secrets an app needs at runtime, so no key has to sit in your code.

product: Secrets Hub -- Brings secrets already in stores such as AWS Secrets Manager under the same policy and rotation. The app does not change.

say: Before you secure the agent, look at what it can already reach. Take the standing credential away first.


## 02

risk: Everything you type is re-sent on every turn. The conversation is a payload that leaves your network again and again.

product: Prism AIRS -- Inspects prompts and responses in flight, so you can see that growing context and apply policy to it.

say: Your agent re-sends the whole conversation every time it speaks. Ask where that traffic goes, and who may read it.


## 03

risk: The model's behaviour is set by text you can fill up and overrun. A rule pushed out of the window is gone.

product: Prism AIRS -- Applies controls outside the context window, so a limit still holds when the window fills up.

say: Anything you enforce with words in a prompt has a size limit, and the conversation competes for it.


## 04

risk: Once the model can call tools, it is a process that reads files and runs commands for you.

product: Secure Workload Access -- Gives the workload its own identity and scoped, expiring access. Policy decides what the agent can reach.

say: Once it has tools, ask what the tools can reach and who authorised them.


## 05

risk: A finished harness has seven parts: rules, skills, style, MCP, an LSP, subagents and hooks. Five are only text the model reads.

product: Securing AI Agents -- Puts enforcement in the path of the call, not in the wording of a request. A refusal becomes a control.

product: Identity Security Platform -- Brokers the identity behind every part and audits what each one did, so "who was the agent acting as" has an answer.

say: You have seen the whole box. Ask any AI vendor which parts are controls, and which are only requests.


## 06

risk: Sixty agents ran in this room, and nobody can say how many there were, whose they were, or what they did.

product: Securing AI Agents -- Discovers and centrally manages agents, brokers their access with least privilege, and audits what each one did.

product: Identity Security Platform -- Gives each agent an identity of its own, which is the only thing anyone can later revoke.

product: Endpoint Privilege Manager -- Governs which programs may start on a managed laptop, so an unregistered agent has somewhere it can be stopped.

say: You cannot govern agents you cannot list. Discovery, identity and audit go in before the first agent runs, not after.


## 07

risk: The agent you just started holds your terminal's credentials and your file access. It inherited them from you.

product: Secure Cloud Access -- Issues the AWS credentials the agent inherits and expires them on a clock, not when somebody remembers to rotate a key.

product: Endpoint Privilege Manager -- Decides which programs may start on a managed laptop, so "installed" and "allowed to run" stay two different answers.

say: Before you ask what an agent can be talked into, ask whose identity it holds and when that identity expires.


## 08

risk: Four credentials sat in the application's source. An agent read all of them out in under a minute.

product: Secrets Manager SaaS -- Holds and rotates the secrets that must exist, so the ones you cannot delete are fetched per request.

product: Secrets Hub -- Brings secrets already in cloud stores under the same policy and rotation, without touching the application.

product: Prism AIRS -- Inspects what the agent sends onward. That matters once its context holds four credentials it just read out.

say: Finding secrets is the easy half. Ask which of them needed to exist at all.


## 09

risk: The elevation worked because a **skill** told the agent which commands to run. A Markdown file ended in a privileged CLI running.

product: Secure Cloud Access -- Issues the AWS access on request and expires it soon after, so the key in the sandbox app needs no replacement.

product: Endpoint Privilege Manager -- Governs which programs may run, and with what privilege. A skill is only a document until it runs `idsec`.

say: Zero standing privileges is not a stricter key. It is no key at all, and access you ask for every time.


## 10

risk: An agent reached a system you hold no credential for, and was refused the next tool it asked for. Both attempts were written down, and the credential lives somewhere the agent cannot read or print.

product: Securing AI Agents -- The **Idira AI Agent Identity Broker** registers the MCP servers and authorises each agent per tool. It brokers the credential and keeps one audit trail.

product: Identity Security Platform -- Issues the agent its own identity and token, so you can name who it acted as and kill the token.

say: Ask who authorised the tool, whose token was on the call, and where you switch it off.


## 11

risk: An agent asked to build from nothing makes every security decision you did not specify. Its default is a credential in the repository.

product: Secrets Manager SaaS -- Gives the generated application somewhere to fetch its secret from, instead of committing it.

product: Secure Cloud Access -- Removes the need for the credential. No code generator reaches for that answer on its own.

say: Every AI-written codebase arrives with its author's defaults. Read what it chose before you read what it built.


## 12

risk: You wrote a file that tells a model which commands to run. Anyone who can edit that file can change what your agent does.

product: Endpoint Privilege Manager -- Governs which commands may actually run on the endpoint, underneath every skill anybody writes.

product: Identity Security Platform -- Decides whose identity the skill's commands run as, and records what that identity did with them.

say: Ask who can write the skills your agents load, and what stops one of them running something nobody approved.


## 13

risk: Nobody watches an AFK harness work. Every control it relies on has to hold without you in the room.

product: Securing AI Agents -- Keeps authorisation and audit in the path of every tool call, which still works while you are away from the keyboard.

product: Endpoint Privilege Manager -- Bounds what the unattended agent's commands can start on the endpoint, regardless of what the tickets told it to do.

product: Prism AIRS -- Watches the traffic in both directions, so an unattended run still leaves something you can review.

say: Away from the keyboard, "we told it not to" is not a plan. Only the controls that run every time are on duty.


## 14

risk: One of the four secrets could be removed and three could not. "We moved it to an environment variable" closes the ticket and leaves the risk open.

product: Secure Cloud Access -- Makes elimination possible: the application asks for access when it runs, instead of holding a key that still works tomorrow.

product: Secrets Manager SaaS -- Is where the three you could not eliminate belong, with rotation and an audit trail instead of a config file.

product: Secrets Hub -- Covers the case where those three already live in a cloud store and nobody will rewrite the application to move them.

say: Eliminate first, vault what is left, and say how many are still there. The number is the finding.


## 15

risk: An agent read the corporate directory. Two users with the same directory role got different answers, and nothing in the directory decided that.

product: Securing AI Agents -- Registers the external MCP server, holds its OAuth secret, and authorises each user per tool through one registered agent.

product: Identity Security Platform -- Federates the client's own Entra ID users in, so the audit record names a person the client already knows.

say: Your directory is the crown jewels. Ask who decided an agent could read it, and where that decision is written down.


## 16

risk: An agent reached a system you hold no credential for. The credential lives somewhere the agent cannot read or print.

product: Securing AI Agents -- The **Idira AI Agent Identity Broker** registers the MCP servers and authorises each agent per tool. It brokers the credential and keeps one audit trail.

product: Identity Security Platform -- Issues the agent its own identity and token, so you can name who it acted as and kill the token.

say: Ask who authorised the tool, whose token was on the call, and where you switch it off.


<!-- ===== product records: one per row of an idira-table block ===== -->
## product: Secure Cloud Access

tag: ZSP for cloud consoles and CLIs

risk: The agent runs as you, and you hold a long-lived cloud key.

controls: Issues **expiring** AWS credentials on request, so there is no standing key on the laptop to steal.

met: 01, 07, 11, 14

hands-on: 09


## product: Secrets Manager SaaS

tag: vaulted, rotated runtime secrets

risk: Some secrets cannot be eliminated. Those end up in a config file or an environment variable.

controls: Holds and **rotates** what an application needs at runtime, and hands it over per request.

met: 01, 08, 11

hands-on: 14


## product: Secrets Hub

tag: policy over cloud-native stores

risk: The secrets are already in AWS Secrets Manager, and nobody will rewrite the application to move them.

controls: Brings existing cloud stores under **one policy and rotation**. The application reads from where it already reads.

met: 01, 08

hands-on: 14


## product: Prism AIRS

tag: AI runtime security

risk: Everything in the window is sent to a model provider on every turn, and hostile content comes back.

controls: Inspects prompts and content **inbound**, model output and tool traffic **outbound**, and raises events on both.

met: 02, 03, 08, 13


## product: Secure Workload Access

tag: SPIFFE/SVID identity for workloads

risk: An agent running as a workload authenticates with a secret it can read, and therefore leak.

controls: Gives the workload a **cryptographic identity** (an SVID) on Kubernetes instead of a shared secret in a config file.

met: 04


## product: Identity Security Platform

tag: OIDC / OAuth identity for agents

risk: "The agent did it" is a shrug, because the agent had no identity of its own.

controls: Issues agents their **own** identity and scoped tokens, and audits what each part of the harness did with them.

met: 05, 06, 10, 12, 15

hands-on: 10, 15


## product: Securing AI Agents

<!-- Sources for the claims below. Kept here rather than on an attendee page: the
     room needs the sentence, and whoever edits the sentence needs the page it came
     from.

     The three pillars named on lesson 06 (discover and centrally manage agents;
     control agent access and enforce least privilege; govern and audit agent
     actions to support compliance) come from
     https://www.paloaltonetworks.com/idira/agentic

     Registered MCP servers, per-agent authorisation, brokered credentials and one
     audit trail come from the Secure AI Agents documentation:
     https://docs.cyberark.com/manage/latest/en/content/secureai/secureaimcpintro.htm

     STILL TO ADD: the release highlights from
     https://docs.cyberark.com/whats-new/latest/en/index.html?service=secure-ai-agents
     Both docs.cyberark.com links above returned 404 to a plain HTTP client when
     this file was last edited, so nothing from them is quoted here. Open them in a
     browser, then add the feature list to lesson 06's Idira section. -->

tag: the Idira AI Agent Identity Broker

risk: Anyone can point an agent at an MCP server by URL, and that server's tools and text enter your context.

controls: Sits **in front of** MCP services: registered servers, brokered credentials, per-agent authorisation, one audit trail.

met: 05, 10, 13, 15

hands-on: 10, 15


## product: Endpoint Privilege Manager

tag: EPM, application control

risk: A "skill" is a document until it runs a command. Then it is a process on a managed laptop.

controls: Governs **which programs and commands** may run, and with what privilege, on the endpoint the agent lives on.

met: 00, 06, 07, 09, 12, 13
