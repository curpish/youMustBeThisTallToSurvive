# You Must Be This Tall to Survive

**Team:** Weird Birds
**Jam:** The Very Serious Juniper Dev Game Jam (theme: *Spin to Win*)
**Engine:** Godot 4.7 · **Target:** HTML5 web build, 16:9, KBM-first
**Deadline:** submit by June 26 · rate by July 5
**Status:** Living document — updated as concepts are fed in.

---

## 1. One-sentence pitch

You are the lone operator of a massively overpowered, criminally under-maintained
ferris wheel; spin it well enough to thrill the riders, and — if you're *really*
good — launch them screaming into the stratosphere (which, it turns out, they love).

## 2. Theme justification ("Spin to Win")

Spinning is *literally* the core mechanic **and** the win condition: the ferris
wheel is the thing that spins, the player's whole job is governing that spin, and
"winning" is spinning hard enough to fling riders into orbit. Theme is the game,
not a skin. We touch two of Juniper's three lanes: **spin-as-mechanic** (the wheel)
and **spin-as-spectacle/escalation** (faster = bigger payoff = more risk).

## 3. Tone & "Seriousness"

The jam is a deadpan bit, so we commit to the bit with a **straight face**:

- Seriousness is carried by **pseudo-engineering gravitas**, not gore. Controls and
  manual text reference real-sounding systems ("the stator calipers", "Lunar
  Waneshaft phase alignment", "central shaft underpinning tolerances") that the
  player will never fully understand but learns to *operate*.
- It is **life-or-death** in-fiction — a rider flung from a basket is, we assume,
  gone — but the riders treat it as the best ride of their lives. The dissonance is
  the comedy.
- **"This is business."** The satisfaction/closure fail-state (§9) is played as
  grim corporate bureaucracy — you don't just blow up, you can get *shut down* for
  poor guest satisfaction. Deadpan paperwork energy.
- Visual register: silly-but-believable. Riders land like beanbags, bounce once,
  cheer, get back in the queue. No squishy gore (harder to sell as "serious," less
  broadly appealing, more work).
- The operator (player avatar) emotes through audio: random grunts, huffs, groans
  between interactions.

## 4. Core loop (30-second version)

1. Riders **board and pay**; they need **~N spins** (N≈3, tune in MVP) before they're
   done and **auto-vanish**, freeing their gondola.
2. You engage the throttle; the wheel spins up. **Speed = throughput:** faster spins =
   riders finish sooner = you clear the queue and collect the next fares faster.
3. Speed generates problems — heat, electrical faults, structural stress, the
   governor fighting you, the occasional goose.
4. You firefight those problems on the **control panel** to *sustain* speed.
5. **Fling** a rider who has ridden → big **reputation** spike + bonus payout + an
   instantly freed gondola. (Flinging is the jackpot accelerant, not a requirement.)
6. **The flywheel & its governor:** reputation ↑ → the queue **spawns faster** →
   riders **wait longer** → **impatience** ↑ → impatient riders board at a risky
   moment and get flung **before paying/riding** → **satisfaction** ↓. Your own hype
   can overwhelm you.
7. Between **days**, spend earnings on **draft upgrades** (pick 1 of N). Each day
   escalates.
8. You lose when the **wheel tears itself apart** (mechanical) **or satisfaction
   drops too low and the ride is closed** (business).

> **The one sentence that explains the whole game:** *Speed is the universal
> currency — it clears the queue, powers the flings, and grows the park — and it is
> also exactly what cooks the machine. Greed accelerates you toward both more money
> and more catastrophe.*

## 5. Where the challenge lives

> **The ride is the clock. The controls are the game.**

- **Ride (background, ~30% attention):** largely automated pressure engine. Has
  momentum, heats up, accrues load and structural stress, drifts toward failure.
  The player almost never touches it directly — only *through* the panel.
- **Control panel (foreground, ~70% attention):** where 100% of player skill lives.
  Every problem the ride generates surfaces as a fiddly, degrading control to
  operate well. This is the WarioWare / Papers-Please layer.

This split also lets the team build in parallel: one ride-simulation system, many
independently buildable panel widgets, with audio/art hanging off emitted signals.

## 6. Pacing, run structure & progression (the WarioWare promise)

Target run length: **3–4 minutes** at mastery. Design intent:

- **Structure: one run, carved into escalating DAYS.** A "day" is the difficulty/
  escalation unit (not a persistent calendar). Each day the systems get more
  resistant and fail in new, *interesting* ways. **~Day 4 is where most players wash
  out** — that's the intended skill wall. Death resets the run; **restart is instant**
  ("one more go"). No save system.
- **Progression: draft upgrades between days.** Between days you spend the day's
  earnings on a **draft — pick 1 of N from a rotating pool**, so no run sees
  everything and builds diverge. Upgrades reset on death.
  - Design bar (from the team): effects must be **legible/clearly communicated**, the
    path should spark **curiosity**, there should be **many viable strategies** (tuned
    via group playtesting), and **no single obvious dominant** build.
- **Fail fast, learn fast.** A new player likely loses inside the **first minute** —
  catastrophic failure is always on the table. Losing teaches the mechanic; no
  tutorial wall.
- **Felt growth.** By the 2nd–3rd attempt the player reaches a moderately successful
  run. The skill learned is *sustaining* speed while juggling failing controls and
  the queue. Upgrades let you snowball hard once stable.
- **Day → night lighting** (nice-to-have) tracks escalation: the scene darkens /
  reddens as days climb — a free tension ramp.
- **Catastrophic failure stays possible** at every tier — the higher you climb, the
  more violently it comes apart.

## 7. The player limiter

**Speed is free to *want* but expensive to *hold*.** Cranking the throttle
simultaneously raises heat, structural stress, power draw, and degrades every
control faster — spawning multiple problems to firefight at once. You can't just
pin it to max:

- Some riders only fling **below** a speed and won't fling above it → you must
  modulate into specific speed bands, not just floor it.
- Tougher riders have higher tolerance; their tolerance also **wears down over
  time**, so patience is a valid (slower) strategy.

The core tension is now **three-way**: **go fast** (throughput, flings, money) vs.
**slow down** (keep the machine alive) vs. **manage the hype** (don't let reputation
flood the queue and tank satisfaction). Speed serves the first, threatens the second
and third.

## 8. Systems & tracked state

Centralized in a `RideState` autoload/resource that emits signals on threshold
crossings (audio + animation hook off signals, never off logic internals).

> **Scope source of truth:** `design-mental-model.md` §4 commits the game to **five
> systems + the goose**: **Speed, Heat, Structural, Electrical, Governor** (+ Goose).
> Speed/Heat/Structural are tracked in §8.1; Electrical/Governor/Goose are the
> interactive fixes in §8.2. Lubrication, rust, and phase-alignment are **swap/day-2**
> candidates (build only after the five are fun, or to replace one that plays dull) —
> see mental-model §3.

### 8.1 Ride state — pressure engine (background, mostly auto)

| Variable | Range | Drives | Player reads via | Fail edge |
|---|---|---|---|---|
| `angular_velocity` (RPM) | 0 → max | core feel; everything | RPM readout on panel + motion blur | — |
| `target_rpm` | float | throttle lerps toward this | throttle lever position | — |
| `heat` | 0–100 | friction from speed/time; damages integrity | **diegetic only** — glow, shaking, smoke on the ride itself | fire / structural event |
| `structural_integrity` | 100→0 | global health; stressed by RPM × heat | shake, creaks, popping bolts | wheel detaches → hard fail |

> **Heat is read on the ride, not a gauge.** The player has reason to watch the
> wheel (not just the panel) because that's where heat lives. A basic UI gauge is an
> acceptable fallback during prototyping to tune thresholds, but the target is
> diegetic-only. Load/weight and power-draw tracking are cut — too many data points
> dilute the readable ones.
>
> Movement model: **no true physics.** A float `angular_velocity` lerps toward
> `target_rpm`; a fixed tick rate (e.g. 60 ticks/s, FPS-independent) feeds a
> per-tick update so momentum *feels* real. Visual rotation = accumulate angle from
> velocity. (Confirm tick approach with PCPuppet.)
>
> **Dual-value RPM model (decided):** the panel shows two values — `target_rpm`
> (desired, set by lever position) and `angular_velocity` (actual, lagging toward
> target). The gap between them *is* the readout. The throttle is an engine order
> telegraph (see `reference/image.png`): player swings the brass handle to a discrete
> labeled band; that sets `target_rpm`. The instrument has two needles: **commanded**
> pointer and a **lagging "actual" needle**. Every notch lands with a CA-CHUNK.

### 8.2 Control / condition state — your tools degrade too (foreground)

**Three-core committed build (MVP):**

| Subsystem | Degrades from | Symptom when bad | Player fix |
|---|---|---|---|
| **Speed lever (lube)** | time + use | lever sticky / slow to respond; hesitation or full stick | apply lube to the main lever |
| **Heat (on the ride)** | high RPM + time | ride glows, shakes, smokes — visible on the wheel | modulate speed down; watch the ride |
| **Fault buttons + mode select** | events triggered by speed/heat/time | indicator lights (🟢/🟡/🔴) appear on panel buttons | press the button in the matching mode to clear |

**Fault / Damage system (Yam's model — committed):**
Faults themselves are not permanently detrimental — they are *problems to clear*. However, the number of **uncleared faults at the moment you press Big Stop** determines how much **damage** is dealt. Damage is a session-total meter on the panel; it cannot be repaired mid-session. When `damage` hits max → day is over (mechanical-business hybrid fail).

**Big Stop (committed):**
Stops the wheel. Any riders currently under the fling-speed threshold are flung; satisfied guests earn score. Faults present at the moment of stop deal damage. Tactically: a clean stop (few faults, riders ridden) is the safe cash-out; a dirty stop (many faults, impatient boarders) burns damage for a quick seat clear.

**Governor override (committed):**
A **screwdriver jammed into the safety interlock** — boolean gate, implemented. Jiggling/holding it prevents the governor from auto-throttling the wheel back below fling speed. Satisfying to slam off; violent deceleration on release. Big risk, big reward, awful sounds.

**Mode Select (committed):**
A selector on the panel that corresponds to fault light colors. Green indicator lights can only be cleared in Mode 1, yellow in Mode 2, red in Mode 3, etc. Adds a cognitive layer to the QTE without new mechanics.

**Swap / Nice-to-Have (build only after the three core are fun):**

| Subsystem | Degrades from | Symptom when bad | Player fix |
|---|---|---|---|
| Frayed wires | vibration, heat | erratic speed/wobble | open service compartment; rewrap with electrical tape |
| The goose | random event | honking, jammed mechanism | goose-ejector button |
| Rust / polish | time, heat | switches stick, intermittent input | scrape / polish action |
| Phase alignment (Lunar Waneshafts) | high RPM | drift you must re-sync | clicky toggle to re-phase |
| Tapes | time/neglect | guests get bored of same lights/theme | swap tape in slot from pile on top |
| Load imbalance → freewheel | uneven rider load | heavy side runs away on its own | rebalance / counter |

> **Wire repair detail (Coopy):** wires sprawl out of a service compartment when opened.
> One tape is easy; multiple tapes make a chaotic, escalating visual. Random roll for
> which wire needs taping; unique positions per event. Good escalation candidate for
> later days.

Design rule for controls: **the result must be unmistakable regardless of what the
label claims.** The button may say "disengage stator calipers" — what the player
learns is "the wheel cools down, that's what I care about."

### 8.3 Meta / scoring

Money and economy are **cut** — too much overhead, dilutes the readable feedback. Scoring is direct and reflects player performance.

| Variable | Purpose |
|---|---|
| `score` | primary counter — incremented by flings and by clearing faults cleanly; the brag stat |
| `fling_count` | sub-counter; milestone tracker and spectacle read |
| `damage` | session health meter (see §8.2); un-repairable, drives the fail state |
| `day` | escalation unit; difficulty ramp |
| rider `tolerance` (per guest) | speed needed to fling; wears down over time |
| `spins_required` (per rider) | spins before a rider is "done" and auto-vanishes (N≈3) |

**Upgrade system demoted to nice-to-have.** If scope allows after the three-core systems are fun, a lightweight draft (pick 1 of N between days) can layer on top. It should not block the submission build. No upgrade pool designed until the core loop is stable.

### 8.4 Guest pressure — the excitement flywheel (2nd pillar)

Simplified from the money-economy model. The flywheel still exists but drives **score pressure and risk**, not cash.

| Variable | Range | Drives | Player reads via | Fail edge |
|---|---|---|---|---|
| `excitement` | float | **queue spawn rate** — rises fast on flings | crowd size/energy visible in queue | — (double-edged buff) |
| `queue_length` | int | how many waiting; long queue → impatience | visible line of RCT2-people | — |
| rider `impatience` | per rider, ↑ with wait | impatient riders try to board at a **risky moment** | fidgeting / agitation anim | — |

**Satisfaction and business-fail are cut** from the core MVP. The single fail path is the **damage meter** (§8.2). If scope allows, satisfaction can return as a second fail axis in a later pass.

**The loop (simplified):** `fling (ridden rider)` → `excitement`↑ → `queue` spawns faster → more riders waiting → more impatient boarders → risky flings → damage accumulates faster. Your own success accelerates the chaos.

**Start small:** a few riders to start; queue grows as you fling more. Hilarious and self-evident escalation without any tutorial text.

> **Boarding model (decided):** *no hard speed gate* — riders can board at any speed.
> Impatience drives the risky timing, not a gate. Same visual event (fling), opposite
> meaning by timing — ridden rider flung = score; impatient boarder flung early = damage.

## 9. Failure model

- **Soft fails (frequent, early):** fault lights appear; uncleared faults on Big Stop
  deal damage. These are the moment-to-moment WarioWare beats.
- **Core hard fail (MVP):**
  - **Damage** — `damage` meter fills from dirty Big Stops (many uncleared faults at
    stop time). When it maxes out, the day ends / the machine gives up. Slower and
    more strategic than a sudden blowup — you feel it coming.
- **Stretch hard fail:**
  - **Mechanical** — `structural_integrity` hits zero → wheel tears free. Spectacular,
    earned, sudden. Add once damage meter is balanced and fun.
  - **Business / satisfaction** — ride closed by poor guest handling. Add last if at
    all; cut for scope.

> **MVP simplification:** one fail axis (damage) is enough to teach the loop and
> create tension. Two or three fail axes return as escalation levers once the core
> is solid.

## 10. Visual direction

> **References:** `reference/IMG_0342.png` (artist's framing sketch) ·
> `reference/image.png` (engine order telegraph that inspires the throttle).

- **Overall register: old-Flash-game / Newgrounds-era**, RCT2-simple attendees (no
  detail needed), carnival props for personality-at-a-distance (Eggs).
- **Art cohesion (decided): "diorama" of two registers.** Foreground = **real keyed
  video/stills of Dan's hands** + a detailed panel (sharp, textured). Background =
  cartoon wheel + RCT2 people (stylized, "over there"). Depth-of-field / vignette /
  lighting separate the planes so the clash reads as deliberate layering, not
  unfinished. **Start with raw footage**; a cel/outline **shader pass is optional
  later polish** (§13 stretch), not on the critical path.
- **Layout (per artist sketch):** control console **foreground-left** (dials + the
  telegraph lever), ferris wheel **dominating the background**, the operator a small
  silhouette at the base of the wheel — deliberately dwarfed by it, selling "this
  machine is far more powerful than you." Carnival grounds around it; dilapidated
  signpost/logo top-left (decapitated height sign on the menu). Perspective TBD
  (iso / ground / slightly aerial) — prototype to decide.
- **The throttle = engine order telegraph** with cartoony-but-explanatory bands that
  double as the tutorial (no text tutorial needed). Each band = word + icon +
  backlight color, climbing in danger:

  | Band (low→high) | Label | Icon | Teaches |
  |---|---|---|---|
  | 0 | `LOADING` | person stepping in | riders board, you get paid |
  | low | `SCENIC` | smiley rider | safe, low earnings |
  | mid | `BRISK` / `QUEASY` | green-faced rider | fun zone; some riders begin to fling |
  | high | `FLING` / `ESCAPE VELOCITY` | rider launching | payoff band — flings + bonus |
  | max | `LUNAR` ("TO THE MOON") | rider + moon / skull | danger: structural stress spikes |

  Backlight tracks the band green→amber→red, strobing red in `LUNAR`.
- **Side view of the wheel** communicates how badly it's going: straining arm on the
  lever, sweat, sparks, hydraulic fluid spraying from connections, a CA-CHUNK on
  first engagement, subtle **motion blur** at high speed to signal "this is special."
- **Gondola swing = the primary speed read (no gauge needed).** Real wheels: cabins
  hang gravity-level at rest and swing *outward toward horizontal* as RPM climbs. We
  lean on this hard — the angle of the cabins is the player's instant, tutorial-free
  read on "am I near fling speed?" Cabins near horizontal = the `FLING` band is close.
  This is a free, physical, legible feedback channel; treat it as a first-class signal.
- **Modular assets** (PCPuppet): modular characters, modular ferris wheel —
  frame / carts / center spinning hub as separate objects so carts can detach.
  Small total asset count.
- Panel has **backlighting** — use color / intensity / strobe to relay state info.
- Animation triggers off `RideState` values (e.g. airborne + height ⇒ "wee, I'm
  flying" animation; landing ⇒ beanbag bounce → cheer → re-queue).

## 11. Controls & input scheme

**Decided: hybrid two-hands.** Fixed-view game; both of the operator's hands are on
screen (real keyed video of Dan's hands — see §10).

- **Right hand = the speed lever (mouse).** Player click-drags the engine-order
  telegraph handle between bands. The right-hand video tracks the mouse: grab → sweep
  3→9 o'clock. Deliberate, tactile, the one reliable instrument in a failing machine.
- **Left hand = the panel buttons/switches (hotkeys).** Each committed fix is a key
  mapped to a panel button (fault clear, mode select, governor override, Big Stop).
  The left-hand video animates on keypress (anticipate → press → recoil). Fast,
  mashable — this is where the WarioWare panic lives.
- **Keyboard layout (to prototype — two candidates):**
  - Option A: `Q W E R` — ergonomic row, intuitive, easy to learn
  - Option B: `E D C V` — diagonal column, stranger, more "dystopian machine operator"
  - Test both; the stranger layout may better sell the tone.
- **Reuse:** takes can be **flipped horizontally** to cover both sides / extra poses.
- **Touch/mobile later:** the hotkey half is the porting cost; KBM 16:9 first.

**Dan's hand + vocal shot list** (green-screen, open-mic, get frustrated/huffy —
"this machine is my lifelong enemy"; operator character is Dan's interpretation):
- Right hand: idle-on-lever; **grab + sweep 3→9 o'clock** and back; + **straining /
  angry** variants.
- Left hand, per button: **anticipate → press → recoil**; + frustrated/slam variants.
- Vocals: huffs, grunts, groans, muttered cursing at the machine, the occasional
  satisfied grunt — rolled from arrays at interaction moments (audio edited later).

## 12. Audio direction

- Spin SFX scaling with RPM; CA-CHUNK engage; creaks/strain tied to integrity.
- Operator vocal barks (grunts/huffs/groans) rolled from arrays between interactions.
- Per-control tactile SFX (clicky switches, sticky levers, tape, grease pump, goose
  honk, goose-ejector).
- Fling stingers + crowd cheers; escalating musical intensity with speed/score.
- **Satisfaction comes from audio timing married to animation timing** — this is a
  first-class design concern, not polish.

## 13. Scope tiers

> The exact one-day MVP cut-line is **deferred** (team's call). The team's read is
> that the business-pillar code (reputation-scaled spawn + impatience) is *trivial*,
> so both pillars may land early; the tiers below are a guide, not a contract.

- **MVP (ugly but complete):** wheel spins via telegraph; lever lube degrades (sticky
  handle); heat visible on ride (glow/shake/smoke); fault buttons with indicator
  lights + mode select; Big Stop; damage meter; a small queue that grows as you fling.
  *The sensation that the wheel spins, faults appear, and a dirty stop costs you.*
- **Target (submission):** the full excitement flywheel (queue grows with flings →
  impatience → risky boarders → damage pressure); governor override (screwdriver);
  day escalation; full audio/art pass (real keyed hands, RCT2 people); deadpan
  manual + jargon; web build deployed. Structural integrity fail state added if time
  allows.
- **Nice-to-have (if target is solid):** draft upgrades between days; wires/tape
  service compartment; goose; satisfaction / business fail-state; keyboard layout
  polish.
- **Stretch:** day→night lighting, cel/outline shader pass on the hands, swap control
  systems (phase alignment, tapes, bolt re-torque), more rider archetypes, mobile
  layout.

> **Visual flavor to test (§16 tech):** the intended aesthetic is PS1/PS2-era crunchy
> lo-fi — low-poly models, low-res textures scaled up with nearest-neighbor filtering
> (no bilinear smoothing). In Godot 4.7 this is implemented via a `SubViewport` running
> at a low internal resolution (e.g. 320×180) displayed as a `TextureRect` with
> `TEXTURE_FILTER_NEAREST`, plus global nearest-neighbor texture filtering in project
> settings. All art assets should be imported with Filter and Mipmaps **off**. The
> dystopian eerie feel pairs well with this — test early once the Main scene exists to
> confirm it reads correctly before committing art pipeline to it.

## 14. Team & ownership

| Name | Responsibility |
|---|---|
| Trine | Music, mixing, audio engineering |
| Dan | Foley / voice, writing |
| Pmayer | QA, testing, documentation (ride-operator domain knowledge) |
| Eggs | Modeling, programming, general |
| PCPuppet | Programming, design, general (modular models; movement math) |
| Yam | Artist, 2D/3D, world art |
| Coopy | Programming, design, ui, audio engineering, general (state machine + variables) |

**Parallelization plan:** Coopy/PCPuppet own `RideState` + the spin model and
publish the signal/variable contract early; Eggs + PCPuppet build modular wheel/
characters; panel widgets are split per-control across programmers; Yam dresses the
scene; Trine/Dan provide music and audio assets; Pmayer drives QA + the (unhelpful) in-game
manual.

## 15. Open questions / forks

**Resolved (this round):**
- [x] **Controls** — hybrid two-hands (mouse lever + hotkey buttons). §11.
- [x] **Run structure** — single run of escalating days; instant restart; no save. §6.
- [x] **Fling role** — risk-accelerant on the excitement flywheel, not a quota. §8.4.
- [x] **Boarding model** — no hard speed gate; impatience drives risky boarding. §8.4.
- [x] **Art cohesion** — raw keyed video first (diorama), shaders later. §10.
- [x] **Throttle metaphor** — engine order telegraph, dual-value RPM model. §8.1 / §10.
- [x] **Economy** — money cut; simple score/fling count is the player feedback metric. §8.3.
- [x] **Core systems (MVP)** — three only: lever (lube), heat (diegetic), fault buttons
      (indicator lights + mode select). All others swap/nice-to-have. §8.2.
- [x] **Fail state (MVP)** — damage meter from dirty Big Stops. Mechanical/business
      fails are stretch. §9.
- [x] **Heat readout** — diegetic on the ride (glow/shake/smoke); no dedicated gauge
      required. §8.1.
- [x] **Throttle wrestle** — struggle lives on the lever (lube = sticky handle) and the
      fault buttons; the telegraph itself is clean and tactile. §8.2.
- [x] **Governor override** — screwdriver-in-interlock implemented (boolean gate);
      violent deceleration on release. §8.2.
- [x] **Progression** — draft upgrades demoted to nice-to-have, not core. §8.3.

**Still open:**
- [ ] **Keyboard layout** — `Q W E R` vs `E D C V`; prototype both for tone. §11.
- [ ] **Throughput math** — `spins_required` per rider vs. damage thresholds; tune in MVP.
- [ ] **Fault event triggers** — what conditions spawn green/yellow/red lights? Rate?
      Design once the three-core loop is wired.
- [ ] **Big Stop timing rules** — exactly which riders count as "satisfied" at stop
      time vs. which deal damage. Needs tuning pass.
- [ ] **One-day MVP cut-line** — *deferred, team's call.*
- [ ] Perspective for the wheel (iso vs ground vs aerial).
- [ ] Park name, color scheme — team crowdsourcing / Yam.
- [ ] Operator personality — Dan's interpretation, discovered in performance.

## 16. Tech notes

- Godot 4.7, GL Compatibility renderer (web-friendly).
- FPS-independent fixed-tick update for the spin model.
- Keep it light → fast web build; consider a
  vertical/mobile layout later, but **KBM 16:9 first**.
- Eligible for the CrazyGames "best web game" bonus — keep the build lean and
  browser-playable.

## 17. Title

**You Must Be This Tall to Survive** (working, repo-confirmed).
Menu backdrop idea: a ticket booth at a dilapidated carnival; the height-requirement
sign is decapitated.
