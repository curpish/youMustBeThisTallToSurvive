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
- Visual register: silly-but-believable. Riders land like beanbags, bounce once,
  cheer, get back in the queue. No squishy gore (harder to sell as "serious," less
  broadly appealing, more work).
- The operator (player avatar) emotes through audio: random grunts, huffs, groans
  between interactions.

## 4. Core loop (30-second version)

1. Riders board (you get paid for each one boarding).
2. You engage the throttle; the wheel spins up.
3. Speed generates problems — heat, electrical faults, phase drift, structural
   stress, the occasional goose.
4. You firefight those problems on the **control panel** to *sustain* speed.
5. Hit a rider's fling threshold → they launch → bonus payout + score.
6. Money buys upgrades that raise the ceiling (faster spin, taller wheel, more
   fling potential) → loop escalates.
7. You clear the queue, or the wheel tears itself apart.

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

## 6. Pacing & difficulty (the WarioWare promise)

Target run length: **3–4 minutes** at mastery. Design intent:

- **Fail fast, learn fast.** A new player likely loses inside the **first minute** —
  catastrophic failure is always on the table. Losing teaches the mechanic; no
  tutorial wall.
- **Felt growth across attempts.** By the 2nd–3rd attempt the player has a
  moderately successful run. The skill being learned is *sustaining* speed by
  juggling failing controls.
- **Exponential growth within a successful run.** Once stable, money → upgrades →
  higher ceiling → more flings → more money. A good player snowballs hard and fast.
- **Catastrophic failure stays possible** at every tier — the higher you climb, the
  more violently it can come apart.

Run is short and restart is instant. Think "one more go."

## 7. The player limiter

**Speed is free to *want* but expensive to *hold*.** Cranking the throttle
simultaneously raises heat, structural stress, power draw, and degrades every
control faster — spawning multiple problems to firefight at once. You can't just
pin it to max:

- Some riders only fling **below** a speed and won't fling above it → you must
  modulate into specific speed bands, not just floor it.
- Tougher riders have higher tolerance; their tolerance also **wears down over
  time**, so patience is a valid (slower) strategy.

The core tension: **go fast** (flings, money) vs. **slow down** (keep it alive) vs.
**hit the right band** (this rider).

## 8. Systems & tracked state

Centralized in a `RideState` autoload/resource that emits signals on threshold
crossings (audio + animation hook off signals, never off logic internals).

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

| Subsystem | Degrades from | Symptom when bad | Player fix |
|---|---|---|---|
| Lubrication | time, use | levers stiff / slow to respond | pump grease / apply premium lube (resource) |
| Rust / polish | time, heat | switches stick, intermittent input | scrape / polish action |
| Electrical (frayed wires) | overdraw, vibration | random input dropouts, sparks | slap on electrical tape (consumable) |
| Phase alignment (Lunar Waneshafts) | high RPM | drift you must re-sync | clicky toggle to re-phase |
| Cooling (cryoblasters / stator calipers) | heat | nothing — until fire | engage coolant (cost + cooldown) |
| The goose | random event | honking, jammed mechanism | goose-ejector button |

Design rule for controls: **the result must be unmistakable regardless of what the
label claims.** The button may say "disengage stator calipers" — what the player
learns is "the wheel cools down, that's what I care about."

### 8.3 Meta / economy / scoring

| Variable | Purpose |
|---|---|
| `money` | upgrades; earned per rider boarding + bonus per fling |
| `score` / `fling_height` | brag stat; pin a high-marker on the UI |
| `riders_processed` / `queue` | day progress; lemming queue refills (riders board mid-spin — funny) |
| `day` / `shift_timer` | win condition (survive the shift / clear the queue) |
| `upgrades` owned | faster spin, taller/bigger wheel, more fling potential |
| rider `tolerance` (per guest) | speed needed to fling; wears down over time |

## 9. Failure model

- **Soft fails (frequent, early):** breakdowns cost time and money while you fix
  them. These are the moment-to-moment WarioWare beats.
- **Hard fail (the big one):** `structural_integrity` hits zero → wheel tears free
  of the mechanism → run over. Spectacular, earned, and the reason to respect speed.

*(Open: confirm we want exactly one hard-fail state. Current lean: yes — soft fails
keep runs alive long enough to reach the 3–4 min mastery window.)*

## 10. Visual direction

> **References:** `reference/IMG_0342.png` (artist's framing sketch) ·
> `reference/image.png` (engine order telegraph that inspires the throttle).

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
- **Modular assets** (PCPuppet): modular characters, modular ferris wheel —
  frame / carts / center spinning hub as separate objects so carts can detach.
  Small total asset count.
- Panel has **backlighting** — use color / intensity / strobe to relay state info.
- Animation triggers off `RideState` values (e.g. airborne + height ⇒ "wee, I'm
  flying" animation; landing ⇒ beanbag bounce → cheer → re-queue).

## 11. Audio direction

- Spin SFX scaling with RPM; CA-CHUNK engage; creaks/strain tied to integrity.
- Operator vocal barks (grunts/huffs/groans) rolled from arrays between interactions.
- Per-control tactile SFX (clicky switches, sticky levers, tape, grease pump, goose
  honk, goose-ejector).
- Fling stingers + crowd cheers; escalating musical intensity with speed/score.
- **Satisfaction comes from audio timing married to animation timing** — this is a
  first-class design concern, not polish.

## 12. Scope tiers

- **MVP (Day ~3, ugly but complete):** one wheel you spin via throttle; tachometer
  + one or two failure systems (heat + electrical); manual fixes on the panel; you
  can lose. *The sensation that the wheel spins and you can mismanage it.*
- **Target (submission):** riders board/fling with tolerances + payouts; 4–6 control
  subsystems; money + a small upgrade tree; one hard-fail; full audio/art pass;
  deadpan manual + jargon; web build deployed.
- **Stretch:** taller/bigger-wheel scaling, the goose, more rider archetypes, more
  upgrades, additional carnival rides as extra minigames, mobile-vertical layout.

## 13. Team & ownership

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

## 14. Open questions / forks

- [ ] Perspective for the wheel (iso vs ground vs aerial)?
- [ ] Confirm single hard-fail vs. multiple game-over states.
- [x] Throttle metaphor: **engine order telegraph** (discrete labeled speed bands +
      commanded/lagging needle). Remaining question — where does the *moment-to-moment
      wrestle* live: on the telegraph itself (sticky/drifting handle you fight to
      hold in a band), on the fix-it controls (telegraph stays clean, struggle is the
      firefighting), or both? Pmayer to prototype. Current lean: telegraph is
      satisfying-but-clean to set; the WarioWare wrestle lives in the fix-it controls.
- [ ] How many control subsystems make the MVP vs. Target?
- [ ] Upgrade tree shape — linear escalation vs. branching choices.

## 15. Tech notes

- Godot 4.7, GL Compatibility renderer (web-friendly).
- FPS-independent fixed-tick update for the spin model.
- Keep it light → fast web build; consider a
  vertical/mobile layout later, but **KBM 16:9 first**.
- Eligible for the CrazyGames "best web game" bonus — keep the build lean and
  browser-playable.

## 16. Title

**You Must Be This Tall to Survive** (working, repo-confirmed).
Menu backdrop idea: a ticket booth at a dilapidated carnival; the height-requirement
sign is decapitated.
