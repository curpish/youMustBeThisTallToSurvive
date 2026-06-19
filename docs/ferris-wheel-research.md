# Ferris Wheel Engineering & Failure — Research Reference

**Purpose:** Points-of-fact reference harvested from two research passes (how it
works / how it breaks). This is the *real* layer — the truthful anchor we dress our
invented mechanics on top of. Facts are real and sourced; treat flagged items as
approximate. See `design-mental-model.md` for how we turn this into gameplay.

> Reliability note: most facts cite a source. A "best-effort web harvest," not an
> engineering bible — items under **Uncertain** are inferred, not confirmed. Good
> enough for flavor and plausibility; don't quote it in a court of law.

---

## Part A — How a ferris wheel actually works

### Structure
- The central **spindle** (main shaft) does **not** rotate — it's fixed. The
  rotating **hub** turns around it on main bearings at each end.
- The wheel is a **bicycle wheel under tension**: pre-tensioned **spoke cables**
  run hub→rim. Pre-tension puts the whole structure into stiff equilibrium, far
  lighter than solid spokes. (London Eye: 64 spoke cables + 16 rim-rotation cables.)
- Big wheels use **locked-coil cables** (interlocking Z-shaped outer wires = smooth
  closed surface). High Roller: 112 cable spokes, 75 mm dia; rim = 28 bolted segments.
- **Stockbridge dampers** clamp to cables to kill **wind-induced (Aeolian)
  vibration** — tuned masses that dissipate oscillation.
- Scale reference: High Roller spindle assembly ≈ 555 tons.

### Main bearings
- Huge **spherical roller bearings** (double-row, self-aligning) at each end of the
  spindle carry the entire wheel load. High Roller's are among the largest SKF ever
  made (~8.8 t each, 2.3 m OD).
- Self-alignment tolerates shaft deflection under asymmetric wind/passenger load.
- A 40 m wheel can put ~200 tonnes through just two main bearings.

### Drive
- **Rim-friction drive** is the norm on big wheels: motor-spun **rubber drive tires**
  press radially against the rim/**bogie ring**; friction turns the wheel.
- Redundant by design: **London Eye = 16 drive units** (keeps running if 4 fail);
  **High Roller = 8 units × 4 tires**, ~1,000 HP total.
- A **PLC** controls each tire's speed independently to equalize torque; rim
  **runout** must stay within ±2 mm/rev for stable friction contact.
- **Speeds are slow.** Continuous-loading observation wheels: rim speed
  ~0.25–0.35 m/s, one revolution ≈ **30 minutes** (~0.033 RPM at the wheel). Drive
  *motors* spin fast (e.g. Vienna 720 RPM, 15 kW) through big gear reduction.

### Braking & holding
- Service braking = reduce hydraulic pressure/motor torque; drive tires slow the rim.
- Separate **failsafe disc brake**: **spring-applied, hydraulically released** —
  power loss = brake clamps ON. (Fail-safe by design.)
- **Holding brake** sized for worst case: one full gondola at the 3-o'clock position,
  all others empty = max unbalanced moment.
- Battery-backed emergency brake as last redundancy. Small wheels **index**
  (stop-start) to load each cabin; big wheels load while moving slowly.

### Gondolas
- Each cabin hangs on a horizontal-axis **pivot bearing** → swings freely, stays
  gravity-level at every wheel position.
- Pivot uses **self-aligning spherical bearings** or **bronze bushings**; endures
  full cabin weight + swing loads over millions of cycles.
- High Roller: 28 capsules, ~40 passengers / 12,000 lb each.

### Power & control
- Electric supply → **Hydraulic Power Units (HPUs)** → drive motors + brake calipers.
- Operator console: speed setpoint (often a single dial/lever), E-stop, per-drive
  enable/disable, brake-release interlock, gondola door interlock.
- **PLC** runs closed-loop speed, watches bearing/cable/position sensors, enforces
  interlocks (e.g. can't release brake unless all doors confirm closed).
- Power reaches the rotating wheel via **slip rings** on the hub (or trailing cables).

---

## Part B — How they break

### Mechanical failure points
- The **main center-shaft bearing** is the single most safety-critical part; some
  designs add **auxiliary bearings** to catch the load if it fails (USPTO 9669320).
- Maintenance limits (real): cabin pivot bearings inspected annually, wear limit
  ≤0.5% of component size; **center-shaft bearings replaced every 5 years**.
- **Fatigue cracking** of welds (spokes, pillars) from cyclic load — starts as
  microscopic **hairline cracks**, can go catastrophic.
- **Bolt/fastener ejection** under vibration is real (a bolt flew off a travelling
  wheel and injured a girl, Michigan 2012).
- **Radial runout** (wobble) must stay ≤ 1/1500 of wheel diameter; more = deformation
  or misalignment.
- **Internal corrosion** is a silent killer: water pools inside hollow beams →
  **wall-thickness reduction** → beam fails under normal load (cause of the 2017 Ohio
  State Fair Fire Ball collapse).

### Drive & brake failures
- Friction **drive tire wears** → traction drops → wheel **slips or stalls** under load.
- Motors **overheat** from poor lubrication or sustained overload; belts/gears fail.
- A **centrifugal governor** is a hardware overspeed cutoff independent of software;
  if it fails the wheel can **freewheel**.
- With no brake + seized/slipped drive, an **unevenly loaded wheel freewheels** —
  gravity imbalance accelerates the heavy side toward runaway rotation.

### Electrical & hydraulic
- Cable/control-panel/connector damage are listed inspection failure modes.
- Real incident: a worker **electrocuted** entangled in wiring during teardown.
- Sensor/interlock faults cause **unexpected stops** — riders stranded at height.

### Operational & maintenance (portable rides = the big one)
- Travelling carnival wheels are **assembled/disassembled constantly** — a huge real
  failure source. ≥12 carnival workers killed during assembly/disassembly since 1985
  (enthusiast-site figure, directionally accurate).
- **Improper torque** on re-assembly (over OR under) → fastener fatigue failure later.
- Corrosion attacks spokes/axles/tubes, worst in hollow sections (invisible to
  surface inspection).
- **Wind loading** is a primary design limit for temporary installs (New Delhi 2003:
  wheel collapsed in wind + rain, 12 killed).
- Human factor is a real category (operator charged with running a wheel intoxicated,
  Ohio 2005).

### Safety systems
- **Centrifugal governor** (overspeed cutoff), **E-stop** (cut power + brake),
  **restraint interlocks** (won't rotate unless lap bars/doors confirmed locked).
- **NDT inspection regime**: MT (magnetic particle, surface cracks), UT (ultrasonic,
  subsurface), PT (dye penetrant), ECT (eddy current), AET (acoustic emission, active
  crack growth), MFL (cable/rope). Plain **visual inspection still catches >90%** of
  defects and is the mandatory first step.
- Standards: **ASTM F24** (US), **EN 13814** (European travelling/fairground rides).

### What overheat / overspeed actually looks like
- **Bearing overheat sequence:** elevated temp → lubricant breakdown & discoloration
  → metal-to-metal contact, **spalling**, rapid heat spike → **seizure or fracture**
  (sequence from NTSB rail-bearing analysis, applies to large rotating shafts).
- **Warning signs:** grinding/rumbling noise (rises with speed), vibration through the
  structure, acrid burning-grease/scorched-metal smell, visible smoke/steam.
- **Overspeed symptoms:** centrifugal force throws gondolas outward (hang more
  horizontal), pitch of noise changes, vibration rises non-linearly, sway/resonance.
- A slipping/seizing drive tire = **burning rubber smell + smoke** before full failure.

---

## Glossary of real terms (the deadpan-jargon mine)

**Build / operate**
- **Spindle (main shaft)** — fixed central shaft the hub rotates around.
- **Hub** — rotating central casting linking spindle to spokes.
- **Spherical roller bearing** — self-aligning double-row bearing carrying wheel load.
- **Bogie ring** — outer rail on the rim that drive tires press against.
- **Rim-friction drive** — rubber tires pressed on the rim to rotate it.
- **Locked-coil cable** — smooth closed-surface wire rope used for spokes.
- **Spoke cables / rim-rotation cables** — tensioned cables giving rigidity (bicycle-wheel principle).
- **Stockbridge damper** — tuned mass on a cable that absorbs wind (Aeolian) vibration.
- **Pivot bearing** — horizontal-axis bearing keeping a gondola gravity-level.
- **HPU (Hydraulic Power Unit)** — pump/reservoir feeding drive motors + brakes.
- **PLC** — industrial computer running speed, sensors, interlocks, safety logic.
- **Slip ring** — rotating electrical contact feeding power to the moving wheel.
- **Runout** — deviation of rim from a true circle (±2 mm spec); also axial wobble.
- **Indexing / stop-start** — halt-at-each-cabin loading mode.

**Break / inspect**
- **Radial runout** — rim wobble/eccentricity; deformation or bearing wear.
- **Fatigue crack** — crack from cyclic stress, grows until fracture.
- **Spalling** — surface flaking of bearing races/gear teeth; precedes seizure.
- **Bearing seizure** — bearing locks up; can shear the shaft.
- **Friction drive / drive tire** — rubber wheel on the ring; wears, loses grip.
- **Centrifugal governor** — mechanical overspeed cutoff (spinning weights cut power).
- **E-stop** — immediate power cut + brake.
- **Freewheel** — uncontrolled rotation, no drive/brake; loaded wheel accelerates.
- **Wall-thickness reduction** — hidden internal corrosion lowering load capacity.
- **Torque spec** — required fastener tightening; wrong torque = fatigue failure.
- **Lap-bar interlock** — sensor blocking operation unless restraint is locked.
- **MT / UT / PT / ECT / AET / MFL** — NDT methods (surface, subsurface, dye, eddy
  current, acoustic emission, magnetic flux leakage).
- **ASTM F24 / EN 13814** — US / European amusement-ride safety standards.

---

## Uncertain / unconfirmed (treat as flavor, not fact)
- Exact brake type/location and holding-torque specs inferred, not primary-sourced.
- London Eye bearing dimensions not confirmed (source 403'd); High Roller figures solid.
- "Standard truck tires" for drive — likely custom polyurethane wheels in reality.
- Overspeed symptom specifics extrapolated from rail-bearing failures, not ride-specific reports.
- Hydraulic-specific failures less applicable to portable wheels (usually electric friction drive).
- "12 workers killed since 1985" from an enthusiast directory, not an official CPSC figure.

## Source list
- ObservationWheelDirectory — technology & accidents pages
- ENR — Las Vegas High Roller engineering
- NDT.net — London Eye cable-tension monitoring
- Wiener Riesenrad — technical data
- SKF/Evolution — High Roller bearings
- Carnee Rides — ferris wheel maintenance guide
- TechKnow Services / DRAS Safety — NDT of amusement rides
- CBS/NTSB — bearing overheat failure stages
- USPTO 9669320 — observation-wheel auxiliary bearings
- Firgelli Auto — ferris wheel mechanism
