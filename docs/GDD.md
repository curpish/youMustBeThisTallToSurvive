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
| `angular_velocity` (RPM) | 0 → max | core feel; everything | tachometer + motion blur | — |
| `target_rpm` | float | throttle lerps toward this | throttle lever position | — |
| `heat` | 0–100 | friction from speed/time; damages integrity | temp gauge, glow, smoke | fire event |
| `structural_integrity` | 100→0 | global health; stressed by RPM × load × heat | shake, creaks, popping bolts | wheel detaches → hard fail |
| `load` / `weight` | Σ riders | raises stress & power draw; shifts balance | wheel sag, strain audio | — |
| `power_draw` vs `supply` | watts | overdraw trips breakers | flickering backlight | brownout (controls die briefly) |

> Movement model: **no true physics.** A float `angular_velocity` lerps toward
> `target_rpm`; a fixed tick rate (e.g. 60 ticks/s, FPS-independent) feeds a
> per-tick update so momentum *feels* real. Visual rotation = accumulate angle from
> velocity. (Confirm tick approach with PCPuppet.)
>
> **The throttle is an engine order telegraph** (see `reference/image.png`). The
> player swings a brass handle to a discrete, labeled speed band; that sets
> `target_rpm`. The instrument has two needles: the **commanded** pointer (where you
> set the handle) and a **lagging "actual" needle** that chases it = live
> `angular_velocity`. The momentum lerp is therefore *the* readout — the player
> watches the gap close. Discrete bands (not a raw slider) make "modulate into the
> right band to fling this rider" legible, and every notch lands with a CA-CHUNK.

### 8.2 Control / condition state — your tools degrade too (foreground)

**Committed (the build list):**

| Subsystem | Degrades from | Symptom when bad | Player fix |
|---|---|---|---|
| Cooling (cryoblasters / stator calipers) | heat (the §8.1 `heat` fix) | nothing — until fire | engage coolant (cost + cooldown) |
| Electrical (frayed wires) | overdraw, vibration | random input dropouts, sparks | slap on electrical tape (consumable) |
| Governor override (safety cutoff) | always fighting you at high RPM | auto-throttles you down below fling speed | hold/override the interlock to reach `FLING`/`LUNAR` — the core trade-off |
| The goose | random event | honking, jammed mechanism | goose-ejector button |

> **Override flavor (Yam's idea — addition):** the governor override is physically a
> **screwdriver jammed into the safety interlock** to stop it disengaging. Dilapidated,
> dangerous, perfectly on-tone — the player wedges/holds it to keep flinging. Great
> visual for "this machine should not be running." Strong candidate for *the* override
> interaction; capture it here so we don't lose it.

**Swap / Day-2 (do not start before the five are fun — mental-model §3):**

| Subsystem | Degrades from | Symptom when bad | Player fix |
|---|---|---|---|
| Lubrication | time, use | levers stiff / slow to respond | pump grease / apply premium lube (resource) |
| Rust / polish | time, heat | switches stick, intermittent input | scrape / polish action |
| Phase alignment (Lunar Waneshafts) | high RPM | drift you must re-sync | clicky toggle to re-phase |
| Bolt re-torque | vibration | a part rattles, then ejects | re-torque micro-task |
| Load imbalance → freewheel | uneven rider load | heavy side runs away on its own | rebalance / counter (strongest swap for Electrical) |

Design rule for controls: **the result must be unmistakable regardless of what the
label claims.** The button may say "disengage stator calipers" — what the player
learns is "the wheel cools down, that's what I care about."

### 8.3 Meta / economy / scoring

| Variable | Purpose |
|---|---|
| `money` | spent on draft upgrades; earned per rider **boarding/paying** + bonus per **fling** |
| `score` / `fling_height` | brag stat; pin a high-marker on the UI |
| `day` | escalation unit; difficulty + lighting ramp |
| `upgrades` (this run) | drafted between days; reset on death |
| rider `tolerance` (per guest) | speed needed to fling; wears down over time |
| `spins_required` (per rider) | spins before a rider is "done" and auto-vanishes (N≈3) |

### 8.4 Business pillar — the reputation flywheel (the 2nd pillar)

The economic engine that ties flinging to consequence. All trivially implementable
(a spawn timer scaled by a float, plus per-rider impatience timers); the *tuning* is
the work, not the code.

| Variable | Range | Drives | Player reads via | Fail edge |
|---|---|---|---|---|
| `reputation` / `excitement` | float | **queue spawn rate** — rises fast on flings | crowd size/energy, a hype meter | — (it's a double-edged buff) |
| `queue_length` | int | how many are waiting; long queue → impatience | the visible line of RCT2-people | — |
| rider `impatience` | per rider, ↑ with wait | impatient riders try to board at a **risky moment** | fidgeting / agitation anim | — |
| `satisfaction` | 100→0 | the business health bar | a park-satisfaction gauge | **too low → RIDE CLOSED (business fail)** |

**The loop:** `fling (ridden rider)` → `reputation`↑ → `queue` spawns faster →
`impatience`↑ → impatient rider boards mid-speed → flung **before paying/riding** →
`satisfaction`↓. Push hype too hard and your own success closes you down.

**The emergent, untaught distinction:** flinging a rider who **rode** = good
(reputation + cash + freed gondola); losing a rider who **never boarded** = bad
(satisfaction hit + lost fare). Same visual event, opposite meaning by timing.

> **Boarding model (decided):** *no hard speed gate* — riders can board at any speed.
> The pressure is soft: impatience makes them board at dangerous moments, and that's
> where pre-pay flings (and satisfaction loss) come from.

## 9. Failure model

- **Soft fails (frequent, early):** breakdowns cost time and money while you fix
  them. These are the moment-to-moment WarioWare beats.
- **Two hard fails (run over):**
  1. **Mechanical** — `structural_integrity` hits zero → wheel tears free of the
     mechanism. Spectacular, earned, the reason to respect speed.
  2. **Business** — `satisfaction` hits zero → **the ride is closed / you're shut
     down**. This is what earns the "this is *business*, this is life or death"
     framing. Quieter, bureaucratic, deadpan-serious.

Two different deaths from the two pillars: you can blow up, or you can get shut down.

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
  (e.g. coolant, tape wires, governor override, goose-ejector). The left-hand video
  animates on keypress (anticipate → press → recoil). Fast, mashable — this is where
  the WarioWare panic lives.
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

- **MVP (ugly but complete):** one wheel you spin via the telegraph; tachometer +
  heat + electrical; manual fixes; riders board/pay + auto-vanish after N spins;
  flinging; you can lose mechanically. *The sensation that the wheel spins and you
  can mismanage it.*
- **Target (submission):** the full two-pillar loop — flinging → reputation flywheel
  → queue/impatience → satisfaction + the business fail-state; the committed five
  systems + goose; draft upgrades between days; day escalation; full audio/art pass
  (real keyed hands, RCT2 people); deadpan manual + jargon; web build deployed.
- **Stretch:** day→night lighting, cel/outline shader pass on the hands, swap/day-2
  control systems, taller/bigger-wheel scaling, more rider archetypes, more upgrade
  pool depth, mobile-vertical layout.

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
- [x] **Progression** — draft upgrades (1 of N) between days, reset on death. §6.
- [x] **Fling role** — risk-accelerant on the reputation flywheel, not a quota. §8.4.
- [x] **Two fail states** — mechanical collapse + business closure. §9.
- [x] **Boarding model** — no hard speed gate; impatience drives risky boarding. §8.4.
- [x] **Art cohesion** — raw keyed video first (diorama), shaders later. §10.
- [x] **Throttle metaphor** — engine order telegraph. §8.1 / §10.

**Still open:**
- [ ] **Throttle wrestle** — does the moment-to-moment struggle live on the telegraph
      (sticky/drifting handle) or the fix-it controls? *Lean: clean lever, wrestle in
      the fixes.* Pmayer to prototype.
- [ ] **One-day MVP cut-line** — *deferred, team's call.*
- [ ] **Upgrade pool** — what the actual draft options are (the design bar is set in
      §6; the list isn't drafted yet).
- [ ] **Throughput math** — `spins_required` per rider vs. fail thresholds; tune in MVP.
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
