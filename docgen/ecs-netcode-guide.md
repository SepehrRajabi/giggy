# ECS Netcode Guide

A practical, engine-agnostic guide to building netcode around an ECS.

## Goals and constraints
- Server authoritative simulation.
- Clients send inputs, not state.
- Deterministic-ish update with reconciliation.
- Component-level replication for relevant entities.
- Minimal bandwidth with clear ownership rules.

## Core architecture

### Roles
- **Server**: Owns truth, runs full simulation, resolves conflicts.
- **Client**: Predicts locally, reconciles to server state.

### Data streams
- **Client -> Server**: input commands + timestamps/sequence.
- **Server -> Client**: snapshots (full/delta) + acks.

## ECS split: local vs. replicated
Define which components are:
- **Replicated**: state sent to clients (transform, health, animation).
- **Authoritative-only**: server-only data (AI, collision cache).
- **Client-only**: camera, UI, prediction buffers.

A good rule: if a component affects other players, it must be server authoritative.

## Entity identity
You need stable identifiers across network:
- **NetEntityId**: 32-bit or 64-bit ID, unique per session.
- **Entity mapping**: server maps NetEntityId -> local ECS entity.
- **Spawn/Despawn messages**: define who creates/destroys entities.

## Replication strategy

### Snapshot model
- Send periodic world snapshots from server.
- Use delta compression against last acknowledged snapshot.
- Include a snapshot sequence number.

### Interest management
- Per-client visibility filter to reduce bandwidth.
- Example filters: distance, team, zone, visibility flags.

### Component granularity
- Replicate only components marked as net-relevant.
- Use bitmasks per entity to indicate which components are present.
- When a component is removed, send an explicit remove flag.

## Client prediction and reconciliation

### Client-side prediction
- Client applies its own inputs locally each tick.
- Server applies inputs authoritatively.
- Client rewinds to last confirmed state and replays inputs.

### Reconciliation loop
1. Receive snapshot `S` with tick `T` and state for entity `E`.
2. If `E` is the local player, compare local predicted state to server state.
3. If error > tolerance, snap or smooth-correct.
4. Reapply saved inputs from tick `T+1` to current.

### Smoothing remote entities
- Interpolate between buffered snapshots.
- Use a small render delay (e.g., 100-200 ms).

## Server tick model
- Fixed tick (e.g., 60 Hz).
- Deterministic systems first (movement, physics, combat).
- Replication system runs at lower rate (e.g., 10-20 Hz).

## Messaging and protocol

### Message types
- `HELLO` / `WELCOME` (handshake, version check)
- `SPAWN` / `DESPAWN`
- `INPUT` (client -> server)
- `SNAPSHOT` (server -> client)
- `ACK` (client -> server)
- `PING` / `PONG` (latency measurement)

### Input packet
- client_id
- tick
- sequence
- input bits/axes

### Snapshot packet
- tick
- last_input_ack
- entity_count
- per-entity: id + component bitmask + component payloads

## ECS integration pattern

### Systems layout
- **InputSystem**: collects input; queues net input command.
- **PredictionSystem**: applies input to local simulation.
- **NetReceiveSystem**: decodes packets into events.
- **SnapshotApplySystem**: applies replicated state.
- **NetSendSystem**: encodes and sends packets.
- **ReplicationSystem (server)**: builds snapshots/deltas.

### Component change tracking
- Dirty flags per component or per entity.
- Server clears dirty flag after including in a snapshot.
- Use a ring buffer of snapshots per client for delta compute.

## Data encoding tips
- Use packed structs with explicit endianness.
- Quantize floats (e.g., 16-bit for positions).
- Use fixed-point for predictable size.
- Validate packet sizes and component payload lengths.

## Conflict rules
- Server authoritative for all replicated components.
- Client authoritative only for cosmetic-only components.
- For client-owned transient entities (e.g., bullets), server verifies.

## Minimal implementation checklist
- Stable NetEntityId + entity mapping.
- Snapshot + delta encoding.
- Client prediction with input buffer.
- Reconciliation for local player.
- Interpolation for remote entities.
- Interest management.

## Debugging and validation
- Log tick numbers on both sides.
- Inject artificial latency and packet loss.
- Visualize prediction error (position delta).
- Ensure all replicated components have deterministic serialize/deserialize.

## Common pitfalls
- Replicating too frequently without interest management.
- Using unreliable inputs without sequencing.
- Applying snapshots out of order.
- Forgetting to remove components on clients when server removed them.

## Suggested ECS component tags
- `NetId` (NetEntityId)
- `NetOwner` (server/client ownership)
- `NetDirty` (changed since last snapshot)
- `NetGhost` (client proxy entity)
- `NetPredicted` (client-predicted entity)

