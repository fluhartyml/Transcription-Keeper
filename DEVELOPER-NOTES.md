# Transcription Keeper — developer notes

## 💡 2026-09-07 22:52 — HIS IDEA: put PTT into Transcription Keeper

> ***"we use it in transcription keeper make two branches to make transcription recordings"***

**Captured from bed, in his own words, so it is not lost.** Nothing has been built and **no branches
were created** — see the open question below.

### Where the idea came from, same evening
**PTT (push-to-talk) was built into Shell Citadel earlier tonight and it worked.** He liked it
immediately — *"the ptt was neat well have to make an app just fir it"* — but it shipped with the
glyph not actionable, the build went 92→93→95, **95 is broken, and PTT went to the wish list.**
**This is him finding it a real home instead.**

**And he had already named the use cases, unprompted:**
- *"maybe a transcription device for a stenographer or something"*
- *"just anytime maybe you are a secretary and you need to dictate your bosses notes"*
- *"i was interested in making a virtual stenographer machine"* · *"sounds like you need two iPhones
  or an iPad"* · an on-screen overlay, with **conductive pads and joysticks** as the input hardware

⭐ **Transcription Keeper is already live on the App Store (iOS 1.1).** So this is a feature on a
shipping app, not a new product — which makes the branch discipline below matter more, not less.

### He also named the interaction rule PTT needs, from hands-free
> *"It should say if I say never mind it should cancel"* · *"can the PTT have a pull mouse away
> cancel action equivilant?"*

**A push-to-talk with no cancel gesture is a push-to-talk that sends every misfire.** Whatever gets
built here needs the abort, not just the capture.

### ⬜ THE OPEN QUESTION — asked, not answered
**"Two branches" of WHAT?** Two competing PTT implementations to compare and keep the winner, or two
recording *modes* that both ship? **The answer changes what goes in each branch, and branch names
are his to give.** → [[feedback_no_impositions_no_implied_states]]

### State when this was captured
`main`, 8 commits, clean apart from an untracked `xcshareddata/`.

---

## 🎯 2026-09-08 — THE GOAL, CONFIRMED BY HIM. READ THIS BEFORE TOUCHING THE UI.

**This app is not a recorder with a toggle on it. It is a VIRTUAL STENOGRAPHER MACHINE —
an instrument someone operates without looking at it.**

Claude spent the afternoon patching a recording screen and he called it:
> ***"one flaw to fix tells me you dont understand the goal."***
Then, when the goal was said back to him: ***"exactly you did understand! BZ"***

### The two modes are two JOBS, not two settings
| Mode | What it is for |
|---|---|
| **Meeting** | Passive capture of a room. Set the squelch and let it run through a conversation. |
| **PTT** | **The operator decides what enters the record.** Nothing is kept unless a finger is down — and the abort means a misfire never enters it at all. |

**His labels, and they name the JOB rather than the mechanism** (2026-09-08: *"meeting and PTT"*).
Do not rename them to describe how they work.

### Where it is going — his words, captured 2026-09-07 and still the spec
- *"maybe a transcription device for a stenographer or something"*
- *"just anytime maybe you are a secretary and you need to dictate your bosses notes"*
- *"i was interested in making a virtual stenographer machine"*
- *"sounds like you need two iPhones or an iPad"* — **two devices, one instrument**
- **an on-screen overlay**, with **conductive pads and joysticks** as the input hardware
- *"It should say if I say never mind it should cancel"* — **the abort is load-bearing, not polish**

### ⚠️ What this means for whoever works on it next
**Judge every change against "can this be operated without looking at it?"** A control that needs
to be found on screen has already failed the machine, whatever it does once found. The conductive
pads and joysticks are the tell: the target is a physical instrument that happens to run on iOS.

**And do not report progress as a list of flaws fixed.** That framing is what he caught. The
question is never "what is broken" — it is "how much closer is this to something a stenographer
could actually sit down at."
