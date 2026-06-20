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

> **The physics are fantasy; only the parts and failures are real.** Real wheels turn
> at ~0.033 RPM (one revolution per *~30 minutes*) and could never fling anyone. Our
> speeds, forces, and the fling itself are pure invention — that absurdity *is* the
> comedy. Borrow real **part names and failure flavors**; never sacrifice fun to make
> the spin "realistic." If it feels like operating heavy machinery, it's working — it
> does not need to *be* a ferris wheel.

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

**Tier legend:**
- **✅ CORE** — one of the committed five (see §4). Build these.
- **🔄 SWAP / DAY-2** — passes the filter and would work, but is *not* in the five.
  Only enters by replacing a core system that playtests dull, or as a post-MVP
  addition if time allows. Do **not** start these before the five are fun.
- **⚠️ FLAVOR** — does not earn a mechanic; lives as a label, manual line, or art cue.

| Real system (from research) | Tier | Game hook | Name dressing (real / fake) |
|---|---|---|---|
| **Rim-friction drive tires** | ✅ CORE (Speed) | The throttle. Worn tires slip → you lose speed and must compensate. | drive tire, bogie ring / "traction stator" |
| **Engine-order-telegraph-style speed setpoint** | ✅ CORE (Speed) | The labeled-band throttle lever (see GDD §10). | speed setpoint, indexing / `LUNAR` band |
| **Main bearing overheat → spalling → seizure** | ✅ CORE (Heat) | The heat system. Real, dramatic, visible (smoke, grind, smell→smoke). Climbs with speed. | spherical roller bearing, spalling / "cryoblaster" coolant |
| **Centrifugal governor (overspeed cutoff)** | ✅ CORE (Governor) | The "safety feature that keeps trying to engage" Yam wanted — fights your high-speed runs; you override it to fling. | centrifugal governor, E-stop / "override interlock" |
| **Structural integrity: fatigue cracks, runout, freewheel** | ✅ CORE (Structural) | The hard-fail meter. Over-speed/over-stress → wobble (runout) → crack → wheel breaks free. | radial runout, fatigue crack, freewheel |
| **Frayed/shorted wiring** | ✅ CORE (Electrical) | Electrical fault → random input dropouts; fix with electrical tape (consumable). | control-panel connector fault / "frayed waneshaft loom" |
| **Bolt loosening from vibration** | 🔄 SWAP / DAY-2 | Periodic "re-torque this" micro-task at high vibration; ignore it and a part ejects. | torque spec, fastener fatigue |
| **Phase / alignment (invented, dressed real)** | 🔄 SWAP / DAY-2 | A clicky re-sync toggle at high RPM (drift you correct). Pure fun, real-sounding. | (fake) "Lunar Waneshaft phase alignment" |
| **Lubrication of moving parts** | 🔄 SWAP / DAY-2 | Stiff controls until greased; premium lube is a costed resource. | bearing lubrication / "expensive synthetic raceway grease" |
| **Load imbalance → freewheel runaway** | 🔄 SWAP / DAY-2 | Heavy side accelerates on its own; you counter-spin/rebalance. Strongest swap for Electrical if it plays dull. | unbalanced moment, freewheel |
| **Hydraulic fluid leaks** | ⚠️ FLAVOR+ | Visual spray for drama (per art notes); optionally a minor fix. | HPU, hydraulic caliper |
| **Wind / Aeolian vibration / Stockbridge dampers** | ⚠️ FLAVOR | Possible random "gust" event that spikes vibration. Great name. | Stockbridge damper, Aeolian vibration |
| **Corrosion / wall-thickness reduction** | ⚠️ FLAVOR | Too slow/invisible to play; perfect for the *backstory* and unhelpful manual. | wall-thickness reduction (the 30-yr-old inspection log) |
| **NDT (MT/UT/PT/ECT/AET)** | ⚠️ FLAVOR | Pure jargon gold for the manual & menus; not a mechanic. | "magnetic-particle certified" stamp on a broken panel |
| **The goose** | ✅ CORE (Goose) | Random jam event; goose-ejector button. Not real, fully earned. | (fake) avian ingress |
| **Restraint / door interlocks** | ⚠️ FLAVOR | Boarding gate sound/state; not a core skill mechanic. | lap-bar interlock |

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

> **Scope discipline:** if a teammate proposes a new MECHANICAL system, it must
> (a) pass the §2 filter and (b) replace something, not add to the five. The fun is
> in the *interaction* of a few well-tuned systems, not the *count* of them.

---

## 4b. The second pillar — the reputation/business loop

The five-systems rule above governs the **MECHANICAL pillar** (the machine you fight).
Design has since grown a deliberate **second pillar — the business/reputation loop**
(GDD §8.4). This is *not* a violation of scope discipline; it's a distinct, parallel
layer the team judged cheap to build (a spawn timer scaled by a `reputation` float +
per-rider impatience timers). It exists to give **flinging consequence** and to earn
the jam's "this is *business*, this is life or death" framing.

- **The flywheel:** fling a *ridden* rider → `reputation`↑ → queue spawns faster →
  `impatience`↑ → impatient riders board at a risky moment → flung *before paying* →
  `satisfaction`↓ → at zero, **the ride is closed** (the second hard-fail).
- **Why it's good design, not bloat:** it's a *self-governing* loop (success raises
  its own stakes), it's emergent/untaught, and it adds a second death (shut-down)
  that contrasts the first (blow-up). The two pillars share ONE currency — **speed** —
  so they entangle instead of competing for attention.
- **Same scope discipline applies within it:** keep it to reputation → queue →
  impatience → satisfaction. Resist adding sub-economies (ticket pricing tiers,
  staff, multiple rides) unless one *replaces* a part of this.
- **Tuning, not code, is the risk.** The flywheel must feel *fair* — never a death
  spiral the player can't read or recover from. That's a playtest job, flagged here.

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

> Build **five real-feeling machine systems and a goose** (the mechanical pillar) and
> **one self-governing reputation loop** (the business pillar), bound together by the
> single shared currency of **speed**. Name everything with a 50/50 blend of real and
> invented jargon, and make every failure *visible, fixable in seconds, and entangled
> with the others*. Truth is the costume; the fun is underneath.
