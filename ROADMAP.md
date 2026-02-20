# ROADMAP

This repo currently has a working Zig + raylib game loop, a handcrafted archetype/SoA ECS, basic resource loading, level JSON spawning, simple collision (circle vs line), and a 2.5D experiment where a 3D model is rendered into a `RenderTexture` and composited into a 2D scene.

Target: a real fast top-down combat, controller-first, with eventual online co-op.

## Current State

- ECS: archetype storage + spawn/assign/unassign + `CommandBuffer.flush` into `World`.
- Game loop: input -> movement -> camera follow -> animation -> render; debug toggles and collider rendering exist.
- Rendering: 2D background + y-sorted renderables; 3D model rendered into a texture per entity.
- Levels: JSON-driven placement for images and polygon edges; edges used for collision checks.
- Collision: currently "block movement if any edge collision" (no sliding/response).
- Scheduling: per-step DAG ordering with labels and optional system IDs; topo-sort on `finalize`.

## Major Ambiguities / Decisions To Make

These choices affect architecture, performance, and how feasible online co-op is.

### 2.5D Rendering Direction

Option A: "True 3D world" (single 3D scene pass) with orthographic (or low-FOV) camera
- Pros: scales to many enemies/VFX; consistent lighting/VFX; simpler long-term; better for multiplayer separation (sim vs render).
- Cons: more 3D pipeline complexity; less aligned with sprite-heavy art pipelines.

Option B: "2D world + per-entity 3D -> RenderTexture" (current approach)
- Pros: easy 2D layering/y-sort; workable for a few 3D elements.
- Cons: per-entity 3D passes are expensive; VFX/lighting/compositing get messy; tends to couple presentation and gameplay.

Recommended default (given goals): move toward Option A, while keeping *gameplay simulation* 2D-on-a-plane if desired.

### Multiplayer Netcode Model

- Server-authoritative + client prediction/reconciliation (practical first online)
- Rollback netcode (needs strong determinism + fixed-step simulation discipline)

Either way: simulation must be cleanly separated from presentation; inputs should be recorded/serialized; simulation should run fixed timestep.

### Controller-First Details

- Independent aim (right stick) + move (left stick)?
- How much aim assist (cone, snap-to-target, stick deadzones)?
- UI navigation must be focus-based from day 1 (no mouse-only tools as the only option).

## Roadmap

### Milestone 0: Stabilize The Foundation (1-3 sessions)

- [x] Establish simulation tick discipline:
  - fixed timestep for simulation
  - variable timestep for rendering
- [x] DAG scheduler with labels + optional IDs:
  - per-step dependency graph + topo sort
  - early errors for cycles or missing required deps
- [X] Refactor and cleaning current plugins (components & systems)
  - well-defined compontents and resources
  - proper system dependencies

### Milestone 1: Room/Run Loop + Content Pipeline

Goal: author rooms quickly and iterate without code changes.

- [x] Data-driven prefabs: enemies/props defined by data (stats, animations, hitboxes, drops).
- [x] Room format (recommend: Tiled/LDtk): spawns, collision, waves, exits, rewards.
- [x] Room manager: load/unload room entities; transitions; keep player persistent.
- [X] Game object plugins: colliders, spawners, etc.
- [ ] Optional but high ROI: hot-reload JSON/data during runtime for fast iteration.

### Milestone 2: Netcode + Multiplayer

Goal: playable 2-4 player online co-op with acceptable latency and stable sync.

- [ ] Lock simulation to fixed step and make deterministic (no frame-time input, avoid non-deterministic iteration).
      ensure identical results across machines by using fixed dt and removing nondeterministic ordering/randomness.
- [ ] Input pipeline: per-player input struct, input buffer, resend window, replay on correction.
      record inputs with timestamps, keep a history, resend missed inputs, and re-simulate when corrections arrive.
- [ ] Serialize ECS state for snapshots (component registry, stable IDs, endian-safe encoding).
      define a stable component registry and endian-safe encoding so full/partial world states can be sent or restored.
- [ ] Networking layer: UDP + reliability for critical messages; basic connect/handshake.
      use UDP for low latency and add reliable delivery for handshakes, spawn/despawn, and session control.
- [ ] Client-side prediction + server reconciliation; interpolation for remote entities.
      predict local input immediately, accept server authority, and smooth remote motion with interpolation.
- [ ] Join/leave flows: late-join snapshot, entity ownership, and cleanup on disconnect.
      let new players sync from a snapshot and cleanly reclaim/erase entities on disconnect.
- [ ] Debug tooling: netgraph, ping/jitter display, desync logging with checksums.
      add visibility into network quality and detect divergence with periodic state hashes.


### Milestone 3: Playable game, attack, hitbox, etc

Goal: a short, complete playable loop with combat, feedback, and progression hooks.

- [ ] Core combat loop: basic weapon, attack input, and hit detection.
- [ ] Hitboxes and hurtboxes: authoring, visualization, and collision rules.
- [ ] Damage pipeline: health, invuln frames, knockback, death, respawn.
- [ ] Enemies: one melee and one ranged enemy with simple AI.
- [ ] Simple room objective: clear wave or defeat mini-boss to exit.
- [ ] Minimal UI: health bar, ammo/energy, and objective text.

## Next Questions To Unblock Work

- Visual direction: mostly-3D look (true 3D world) vs sprite-heavy?
