# MVP — Step 0: "Does the wheel feel good to spin?"

**The narrowest possible foundation.** No queue, no riders, no upgrades, no failures,
nothing reactive. Just: a foreground/background layered scene where the player drags a
handle and the wheel spins up/down with believable momentum, and a gauge reflects it.
This is the spike we scale out from over the next couple of days — see GDD §6/§8 for
where it grows.

> **Definition of done:** you can drag the handle, watch the wheel accelerate and coast
> with inertia (not snap), read the RPM on a gauge, with the panel layered in front of
> the wheel, locked to 16:9. That's the whole bar. If you can *feel the spin*, Step 0
> is done.

---

## The one shared spine (all three disciplines build against this)

Everything keys off a single AutoLoad singleton, `RideState`. It is the contract. Lock
these names now; every future system reads or writes them, so nothing here gets
rewritten later — it only gets *added to*.

| Field | Meaning | Who writes it | Who reads it |
|---|---|---|---|
| `target_rpm` | where the handle is set (0..`MAX_RPM`) | the handle | the spin model |
| `angular_velocity` | actual current rpm (chases target with inertia) | the spin model | gauge, audio, (later) every system |
| `wheel_angle` | accumulated rotation, radians | the spin model | the wheel mesh |

Tunables on the same singleton: `MAX_RPM`, `SPIN_UP_ACCEL`, `SPIN_DOWN_ACCEL`.

**Spin model (the feel), in plain terms:**
- Run it on the fixed physics tick (60 Hz) so it's frame-rate independent.
- Each tick, move `angular_velocity` *toward* `target_rpm` by an acceleration limit —
  **not** an instant jump. Use a smaller accel when speeding up (heavy, slow to start)
  than when slowing down, or vice-versa — this asymmetry *is* the momentum feel; tune
  by hand.
- Accumulate `wheel_angle` from `angular_velocity` each tick (rpm → rad/sec =
  `rpm/60 * TAU`), wrapped to 0..TAU.

That's the entire logic of Step 0. Continuous drag now; **discrete telegraph bands +
CA-CHUNK are the very next step, not this one.**

---

## 1. Technical side

**Owner:** Coopy / PCPuppet.

**Scene structure (one 3D scene, one camera — the simplest layering):**

```
Main (Node3D)
├─ Camera3D                      # panel near, wheel far → instant fore/back depth
├─ DirectionalLight3D
├─ Background (Node3D)
│   └─ Wheel                     # PCPuppet's model; reads wheel_angle on its spin axis
└─ UILayer (CanvasLayer)         # draws on top, screen-anchored
    ├─ Handle                    # drag → writes target_rpm
    └─ Gauge                     # reads angular_velocity
```

**Tasks:**
- [ ] `RideState` AutoLoad with the three fields + tunables + the fixed-tick spin model.
- [ ] Wheel node reads `wheel_angle` → spins on the hub's real axis (confirm Z vs X
      from PCPuppet's export; placeholder primitive is fine until the model lands).
- [ ] Handle: drag maps 0..1 → `target_rpm` (Control/Area for hit-testing; move the
      visual to match for feedback). Continuous, no bands yet.
- [ ] Gauge: a Label showing rounded `angular_velocity` (swap for Coopy's whirring
      counter later).
- [ ] `project.godot`: register the AutoLoad, set `Main` as main scene, viewport
      1920×1080, stretch `canvas_items` / `keep` for 16:9.

**Done check:** drag → inertial spin-up/coast-down, gauge tracks it, panel over wheel,
16:9. **Out of scope:** literally everything reactive.

**On-ramp (do NOT build in Step 0 — shows the spine scales):**
1. Snap handle to discrete telegraph bands + CA-CHUNK + backlight colors.
2. Decorative riders on gondolas + swing-outward-with-RPM visual (reads
   `angular_velocity`, still no gameplay).
3. First reactive bit: fling a rider when `angular_velocity` crosses a threshold.
4. First firefight system: heat. (Then the rest of GDD §8.)

---

## 2. Art side

**Owner:** Yam (foreground + scene), PCPuppet (wheel), Eggs (props, later).

**Goal for Step 0:** establish the **diorama layering** and get the real models reading
the contract — *not* a finished look.

**Tasks:**
- [ ] **Wheel model** (PCPuppet): import, confirm scale + spin axis, sit it in
      `Background`, far from camera. Frame / carts / hub separable (per existing plan)
      but only the hub needs to spin for Step 0.
- [ ] **Foreground panel** (Yam): the early panel model placed close to camera, with a
      clear spot for the handle. Detailed lever can come later — Step 0 just needs the
      plane to exist so layering reads.
- [ ] **Camera + composition:** one camera, panel near / wheel far; rough framing per
      `reference/IMG_0342.png` (operator dwarfed by the wheel).
- [ ] **16:9** framing confirmed.

**Explicitly deferred (GDD §10 / §13 stretch):** textures/materials polish, depth-of-
field + `WorldEnvironment` diorama blur, day→night lighting, cel/outline shader pass,
Dan's keyed-hand overlay, RCT2 attendees. Raw/placeholder is correct for Step 0.

**Art cohesion reminder:** raw keyed video/stills first; real sharp foreground vs.
cartoon background separated by depth — shaders are later polish, not the critical path.

---

## 3. Audio side

**Owner:** Trine (music/mix), Dan (foley/voice).

**Reality of Step 0:** there's no gameplay to score yet, so audio is minimal — but ONE
sound makes the spike feel alive and proves the audio→contract hookup pattern.

**Tasks (now):**
- [ ] **One motor/whir loop** whose **pitch and volume track `angular_velocity`**
      (read the contract, map rpm → pitch_scale + db). This single hook validates how
      *all* future audio attaches to the sim, and instantly makes the spin satisfying.

**Tasks (record now, integrate later — Dan is already shooting these):**
- [ ] Operator **vocal barks** (huffs, grunts, groans, muttered cursing, the odd
      satisfied grunt) — open-mic during the hand takes. Played from arrays at
      interaction moments *once there are interactions*. Character = Dan's call.
- [ ] **CA-CHUNK** lever engage + per-band clunk (for the bands step next).
- [ ] Per-control tactile SFX (tape, coolant, goose honk/ejector) — for when those
      systems exist.

**Explicitly deferred (GDD §11/§12):** music tracks + escalating intensity, fling
stingers + crowd cheers, structural creaks/strain, full mix. The audio↔animation
timing marriage is a first-class concern *later*; Step 0 only needs the motor whir.

---

## Why Step 0 is the right foundation

- **The contract is the whole game's spine.** `target_rpm` / `angular_velocity` /
  `wheel_angle` are what every future system and every discipline reads. Lock them now,
  rewrite nothing later.
- **Placeholders don't lock anyone out.** 2D/primitive stand-ins swap for real models,
  the whirring counter, keyed hands, and real audio — all against the same three fields.
- **All seven unblock at once,** each building their slice against one stable API
  instead of waiting on each other.
