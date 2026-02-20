# ENet Mini Wiki (Game Netcode)

A short, practical guide to using ENet for client/server netcode.

## What ENet gives you
- UDP transport with optional reliability.
- Ordered channels for gameplay vs. chat, etc.
- Packet fragmentation and reassembly.
- Connection management (handshake, keepalive, timeouts).
- Optional bandwidth throttling and RTT tracking.

ENet is not a full replication system. You still design your protocol.

## Core concepts
- **ENetHost**: A local endpoint. Server hosts listen for peers; clients host a single outgoing connection.
- **ENetPeer**: A remote connection (client on server, or server on client).
- **ENetEvent**: Polled events (connect, receive, disconnect).
- **ENetPacket**: Payload, with reliable/unreliable flags.
- **Channel**: Separate ordered streams per peer.
- **Round-trip time (RTT)**: Measured latency per peer, used for throttling/retries.

## Basic flow
1. Initialize ENet once at startup.
2. Create a server host or a client host.
3. Connect (client) or wait for connections (server).
4. Poll events in your main loop.
5. Send packets to peers as needed.
6. On shutdown, disconnect peers and deinitialize ENet.

## Initialize / Deinitialize
```c
if (enet_initialize() != 0) {
    // handle error
}

// ... use ENet ...

enet_deinitialize();
```

You can set a custom allocator with `enet_initialize_with_callbacks` if you
need to route all ENet allocations through your engine allocator.

## Create a server host
```c
ENetAddress address;
address.host = ENET_HOST_ANY;
address.port = 12345;

ENetHost* server = enet_host_create(
    &address,
    64,     // max peers
    2,      // channels
    0,      // downstream bandwidth (0 = unlimited)
    0       // upstream bandwidth (0 = unlimited)
);
```

## Create a client host and connect
```c
ENetHost* client = enet_host_create(
    NULL,
    1,      // max peers (typically 1)
    2,      // channels
    0,
    0
);

ENetAddress address;
enet_address_set_host(&address, "127.0.0.1");
address.port = 12345;

ENetPeer* peer = enet_host_connect(client, &address, 2, 0);
```

The last argument is "connect data" (a u32) you can use for a protocol version
or auth token. The server can read it in the connect event.

## Event loop (server or client)
```c
ENetEvent event;
while (enet_host_service(host, &event, 0) > 0) {
    switch (event.type) {
    case ENET_EVENT_TYPE_CONNECT:
        // event.peer is now connected
        break;
    case ENET_EVENT_TYPE_RECEIVE:
        // event.packet contains data
        enet_packet_destroy(event.packet);
        break;
    case ENET_EVENT_TYPE_DISCONNECT:
        // peer disconnected
        event.peer->data = NULL;
        break;
    default:
        break;
    }
}
```

Call `enet_host_service` each tick. Use a short timeout (0-5 ms) to avoid blocking your frame.
You can also call it in a loop with a small budget per tick to drain queued packets.

## Sending packets
```c
const char* msg = "hello";
ENetPacket* pkt = enet_packet_create(
    msg,
    strlen(msg) + 1,
    ENET_PACKET_FLAG_RELIABLE
);

enet_peer_send(peer, 0, pkt); // channel 0
```

ENet takes ownership of the packet after `enet_peer_send`. Do not free it.
Use `ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT` only for large, lossy payloads.

Use `ENET_PACKET_FLAG_UNSEQUENCED` only for data that can arrive out of order.

## Channels and ordering
- Channel 0 for critical gameplay state.
- Channel 1 for chat, telemetry, or low priority events.
- Each channel is ordered independently, so heavy traffic on one channel
  does not stall another.
- Keep channel count small (2-4). Too many channels increase overhead.

## Reliability strategy
- **Reliable**: important state changes (match start, inventory, join/leave).
- **Unreliable**: high-frequency state (position, velocity) where old data is useless.
- **Unsequenced**: rare. Use only when ordering is irrelevant.

Reliability is per packet, not per channel. Mixing reliable and unreliable on the
same channel can still cause head-of-line blocking if reliable traffic is heavy.

## Snapshots and delta updates
A simple pattern:
- Server sends full snapshot at a low rate (e.g., 2-5 Hz).
- Server sends deltas (unreliable) at higher rate (e.g., 20-30 Hz).
- Client reconciles and interpolates.

Include a snapshot ID and last-acknowledged input ID so the client can match
authoritative state with its prediction history.

## Packet layout basics
Prefer a small fixed header:
- 1-2 bytes: message ID
- 1 byte: flags/version
- 2-4 bytes: sequence or snapshot ID (if needed)
- payload data

Keep packets under the typical MTU (~1200 bytes) to avoid fragmentation. ENet
will fragment, but fragmentation increases loss sensitivity and latency.

## Bandwidth and throttling
You can cap bandwidth to avoid flooding:
```c
enet_host_bandwidth_limit(host, downstream, upstream);
```

You can configure peer throttling based on RTT and packet loss:
```c
enet_peer_throttle_configure(peer, interval_ms, acceleration, deceleration);
```

Use `peer->roundTripTime` and `peer->roundTripTimeVariance` for diagnostics
and dynamic send-rate decisions.

## Timeouts and disconnects
- ENet sends keepalive pings automatically.
- Treat disconnects as final; peers are invalid after `ENET_EVENT_TYPE_DISCONNECT`.
- If you need a graceful leave, send a reliable "goodbye" message before disconnecting.

## Compression
ENet supports optional compression callbacks. Use only if your data is big and
CPU budget allows it.

## Host and peer data pointers
`ENetHost` and `ENetPeer` have `void* data` fields for your own context. Set
them on connect (e.g., player ID), and clear on disconnect.

## Shutdown
```c
enet_peer_disconnect(peer, 0);

// In event loop, wait for disconnect event. If it does not arrive:
enet_peer_reset(peer);

enet_host_destroy(host);
```

Use `enet_peer_disconnect_later` if you want to finish sending queued reliable
packets before closing the connection.

## Common pitfalls
- Forgetting to `enet_packet_destroy` after receive.
- Using a single channel for all traffic and causing head-of-line blocking.
- Treating unreliable packets as authoritative.
- Polling events too rarely and causing latency spikes.
- Not validating packet sizes and IDs before parsing.

## Minimal protocol checklist
- Message IDs (1 byte or 2 bytes) at start of each packet.
- Version / protocol number.
- Server authoritative state.
- Client input commands with sequence numbers.
- Optional ack/receipt for critical game events.

## Quick checklist before shipping
- Simulate packet loss and latency (ENet has built-in peer throttling).
- Validate all inbound packet sizes and IDs.
- Cap client command rate to avoid flooding.
- Log connect, disconnect, and timeout reasons.
- Capture live RTT/jitter stats to spot spikes and regressions.

## API coverage map (quick index)
Initialization and utilities:
- `int enet_initialize(void)` - initialize ENet; call once at startup.
- `int enet_initialize_with_callbacks(ENetVersion v, const ENetCallbacks* cb)` - initialize with custom allocators.
- `void enet_deinitialize(void)` - shutdown ENet.
- `ENetVersion enet_linked_version(void)` - check linked ENet version.
- `enet_uint32 enet_time_get(void)` - get ENet time in ms.
- `void enet_time_set(enet_uint32 new_time)` - override ENet time (testing).
- `enet_uint32 enet_crc32(const void* data, size_t len)` - CRC32 helper.

Address helpers:
- `int enet_address_set_host(ENetAddress* address, const char* name)` - resolve hostname to address.
- `int enet_address_set_host_ip(ENetAddress* address, const char* ip)` - parse dotted IP string.
- `int enet_address_get_host(const ENetAddress* address, char* name, size_t name_len)` - reverse resolve hostname.
- `int enet_address_get_host_ip(const ENetAddress* address, char* ip, size_t ip_len)` - stringify address.

Host lifecycle and events:
- `ENetHost* enet_host_create(const ENetAddress* address, size_t peer_count, size_t channel_limit, enet_uint32 in_bw, enet_uint32 out_bw)` - create server/client host.
- `void enet_host_destroy(ENetHost* host)` - destroy host and free resources.
- `int enet_host_service(ENetHost* host, ENetEvent* event, enet_uint32 timeout)` - poll events and service network.
- `int enet_host_check_events(ENetHost* host, ENetEvent* event)` - check queued events without blocking.
- `void enet_host_flush(ENetHost* host)` - force send queued packets.
- `ENetPeer* enet_host_connect(ENetHost* host, const ENetAddress* address, size_t channel_count, enet_uint32 data)` - initiate client connect.
- `int enet_host_broadcast(ENetHost* host, enet_uint8 channel_id, ENetPacket* packet)` - send to all peers.
- `void enet_host_bandwidth_limit(ENetHost* host, enet_uint32 in_bw, enet_uint32 out_bw)` - cap bandwidth.
- `void enet_host_channel_limit(ENetHost* host, size_t channel_limit)` - cap channels per peer.
- `void enet_host_compress(ENetHost* host, const ENetCompressor* c)` - install custom compression.
- `void enet_host_compress_with_callbacks(ENetHost* host, const ENetCompressor* c)` - install compression callbacks.
- `void enet_host_compress_with_range_coder(ENetHost* host)` - enable built-in range coder.

Peer control and stats:
- `int enet_peer_send(ENetPeer* peer, enet_uint8 channel_id, ENetPacket* packet)` - send packet to peer.
- `void enet_peer_disconnect(ENetPeer* peer, enet_uint32 data)` - request graceful disconnect.
- `void enet_peer_disconnect_later(ENetPeer* peer, enet_uint32 data)` - disconnect after queued reliable sends.
- `void enet_peer_disconnect_now(ENetPeer* peer, enet_uint32 data)` - immediate disconnect (no delivery).
- `void enet_peer_reset(ENetPeer* peer)` - force reset peer state.
- `void enet_peer_ping(ENetPeer* peer)` - send ping now.
- `void enet_peer_throttle_configure(ENetPeer* peer, enet_uint32 interval, enet_uint32 accel, enet_uint32 decel)` - configure throttle.
- `void enet_peer_timeout(ENetPeer* peer, enet_uint32 timeout, enet_uint32 min, enet_uint32 max)` - configure timeouts.
- Useful fields: `peer->address` (remote address), `peer->data` (user ptr), `peer->roundTripTime`, `peer->roundTripTimeVariance`.

Packet management:
- `ENetPacket* enet_packet_create(const void* data, size_t data_len, enet_uint32 flags)` - create packet.
- `void enet_packet_destroy(ENetPacket* packet)` - free packet.
- `int enet_packet_resize(ENetPacket* packet, size_t data_len)` - resize packet payload.
- Flags: `ENET_PACKET_FLAG_RELIABLE`, `ENET_PACKET_FLAG_UNSEQUENCED`, `ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT`.

## References
- ENet homepage: https://enet.bespin.org/
- ENet API: https://enet.bespin.org/Reference/index.html
