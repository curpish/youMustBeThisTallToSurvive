# Design Mental Model — Turning Real Engineering Into a Fun, Nerdy, Very Serious Game

**Purpose:** The bridge between `ferris-wheel-research.md` (what's true) and the
`GDD.md` (what we build). It sets the philosophy for using the research, the filter
for what earns a place in the game, and a concrete real→game mapping. When in doubt
about whether a mechanic belongs, this doc decides.

---

## 1. The core philosophy

> **Real engineering supplies texture and names. Fake engineering supplies the
> mechanics. The player never needs to learn anything true — they learn *our* system,
> dressed in true-sounding clothes.**

We are not building a ferris wheel simulator. We are building a *feeling*: that you
are operating a real, complicated, dangerous machine you only half-understand. Real
research buys that feeling cheaply (believability, vocabulary, legible failure
shapes). Invented mechanics provide the fun (whack-a-mole tension, escalation, the
fling payoff).

### The two-knob rule of plausibility
The comedy and the seriousness come from the **same** trick: put a real term next to
a fake one and make the player unable to tell which is which.

- Real: *spalling, runout, Stockbridge damper, locked-coil cable, spherical bearing.*
- Fake: *Lunar Waneshaft, stator caliper phase, cryoblaster, central-shaft underpinning tolerance.*

A player who can't tell "re-tension the rim-rotation cable" (real) from "re-phase the
Lunar Waneshaft" (fake) is exactly where we want them: taking it all seriously,
laughing at none of it on the surface, and operating purely by *felt consequence*.
**This ambiguity is the engine of both the humor and the "seriousness" score.**

---

## 2. The filter — what earns a place in the game

Every real failure point or system must pass all three to become a mechanic.
If it fails, demote it to **flavor only** (a label, a manual line, a gauge that does
nothing but look serious).

1. **Visible** — the player can *see/hear* it going wrong without reading a number.
   (Smoke, sparks, a wobble, a rising grind, a gondola hanging too horizontal.)
2. **Actionable** — it maps to **one clear control or fix**, resolvable in seconds.
   (Not "you should have inspected this three weeks ago.")
3. **Cascading or trade-off-y** — fixing it costs something, or it makes a second
   thing worse. Isolated problems are chores; interacting problems are *the game*.

> **The tie-breaker rule:** if reality says a failure is slow, boring, or invisible,
> **we lie.** Pacing (catastrophe possible inside a minute) beats accuracy every time.

---

## 3. Real → game mapping

Research systems sorted by what they become. "Hook" = the fun mechanic; "Dressing" =
real + fake names to wear.

| Real system (from research) | Passes filter? | Game hook | Name dressing (real / fake) |
|---|---|---|---|
| **Rim-friction drive tires** | ✅ core | The throttle. Worn tires slip → you lose speed and must compensate. | drive tire, bogie ring / "traction stator" |
| **Engine-order-telegraph-style speed setpoint** | ✅ core | The labeled-band throttle lever (see GDD §10). | speed setpoint, indexing / `LUNAR` band |
| **Main bearing overheat → spalling → seizure** | ✅ core | The heat system. Real, dramatic, visible (smoke, grind, smell→smoke). Climbs with speed. | spherical roller bearing, spalling / "cryoblaster" coolant |
| **Centrifugal governor (overspeed cutoff)** | ✅ core | The "safety feature that keeps trying to engage" Yam wanted — fights your high-speed runs; you override it to fling. | centrifugal governor, E-stop / "override interlock" |
| **Structural integrity: fatigue cracks, runout, freewheel** | ✅ core | The hard-fail meter. Over-speed/over-stress → wobble (runout) → crack → wheel breaks free. | radial runout, fatigue crack, freewheel |
| **Frayed/shorted wiring** | ✅ | Electrical fault → random input dropouts; fix with electrical tape (consumable). | control-panel connector fault / "frayed waneshaft loom" |
| **Bolt loosening from vibration** | ✅ | Periodic "re-torque this" micro-task at high vibration; ignore it and a part ejects. | torque spec, fastener fatigue |
| **Phase / alignment (invented, dressed real)** | ✅ | A clicky re-sync toggle at high RPM (drift you correct). Pure fun, real-sounding. | (fake) "Lunar Waneshaft phase alignment" |
| **Lubrication of moving parts** | ✅ | Stiff controls until greased; premium lube is a costed resource. | bearing lubrication / "expensive synthetic raceway grease" |
| **Hydraulic fluid leaks** | ⚠️ flavor+ | Visual spray for drama (per art notes); optionally a minor fix. | HPU, hydraulic caliper |
| **Wind / Aeolian vibration / Stockbridge dampers** | ⚠️ flavor / stretch | Possible random "gust" event that spikes vibration. Great name. | Stockbridge damper, Aeolian vibration |
| **Corrosion / wall-thickness reduction** | ⚠️ flavor | Too slow/invisible to play; perfect for the *backstory* and unhelpful manual. | wall-thickness reduction (the 30-yr-old inspection log) |
| **NDT (MT/UT/PT/ECT/AET)** | ⚠️ flavor | Pure jargon gold for the manual & menus; not a mechanic. | "magnetic-particle certified" stamp on a broken panel |
| **The goose** | ✅ (canon) | Random jam event; goose-ejector button. Not real, fully earned. | (fake) avian ingress |
| **Restraint / door interlocks** | ⚠️ flavor | Boarding gate sound/state; not a core skill mechanic. | lap-bar interlock |

---

## 4. Where this narrows our focus

The research **confirms** the systems already in the GDD — which is the signal we
should stop expanding and commit. The game is **five real systems and one goose**:

**The committed core (each = a gauge + a fix on the panel):**
1. **Speed** — telegraph throttle, banded, with momentum lag. *The intent.*
2. **Heat** — bearing overheat, climbs with speed, cool it or it eats integrity. *The clock.*
3. **Structural integrity** — runout→crack→freewheel→detach. *The hard fail.*
4. **Electrical** — random input dropouts; tape them. *The chaos.*
5. **The governor/safety** — keeps trying to slow you; override to reach fling speed. *The trade-off.*
   ...plus **the goose** as the comic random event.

Everything else from the research is **dressing**: names on gauges, lines in the
unhelpful manual, the dilapidated backstory (30-year-old inspection log, decapitated
height sign), the art's hydraulic spray and sparks. It makes the world *feel* deep
without costing us mechanics to build.

> **Scope discipline:** if a teammate proposes a new system, it must (a) pass the
> §2 filter and (b) replace something, not add to the five. The fun is in the
> *interaction* of a few well-tuned systems, not the *count* of them.

---

## 5. The "nerdy but serious" tone targets

- **The manual** (Pmayer): written like a real, terrifying, mostly-useless equipment
  manual. Real NDT/ASTM jargon + fake systems, deadpan. "Consult §7.3 before
  exceeding rated waneshaft phase. Good luck."
- **Gauge labels:** mix real (`RUNOUT`, `BEARING TEMP`, `RIM PSI`) and fake
  (`WANESHAFT PHASE`, `LUNAR DRIFT`) so the player can't sort them.
- **Failure feedback** uses real symptom language: grind that rises with speed,
  burning-grease smell cue (visual/text), gondolas hanging too horizontal at overspeed,
  hairline crack → wobble → CA-CHUNK → catastrophe.
- **Seriousness through gravitas, not jokes:** nothing winks at the camera. The riders
  loving it is the only "joke," and it's played straight.

---

## 6. One-line summary for the team

> Build **five real-feeling systems and a goose**, name them with a 50/50 blend of
> real and invented jargon, and make every failure *visible, fixable in seconds, and
> entangled with the others*. Truth is the costume; the fun is underneath.
