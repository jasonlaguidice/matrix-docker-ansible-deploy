# Setting up Nether Voice Bridge (optional)

The playbook can install and configure [nether-voicebridge](https://nether.codes/dark/nether-voicebridge), a bridge that connects Discord voice channels to Matrix [Element Call](https://element.io/element-call) rooms.

Unlike text bridges, this bridge does not relay chat messages — it bridges **audio only**, making Discord voice participants audible inside an Element Call session and vice versa.

## Prerequisites

Before enabling this bridge you must have:

1. **matrix-livekit-jwt-service enabled** (`matrix_livekit_jwt_service_enabled: true`). The bridge auto-discovers the lk-jwt endpoint from your homeserver's `.well-known/matrix/client`. The playbook will error during deploy if this is not enabled.

2. **One or more Discord puppet bot tokens.** Each token is a separate Discord application created at [discord.com/developers/applications](https://discord.com/developers/applications). For each bot:
   - Create a new application and enable the **Bot** feature.
   - Enable the **Server Members Intent** and **Voice Activity** permissions.
   - Generate and copy the bot token.
   - Invite the bot to every Discord server (guild) it will bridge, with permissions: **Connect**, **Speak**, **Use Voice Activity**, **Change Nickname**.

3. **One or more bridged room pairs.** For each Discord voice channel you want to bridge:
   - A Discord guild ID (right-click server icon → *Copy Server ID*, requires Developer Mode).
   - A Discord channel ID (right-click voice channel → *Copy Channel ID*).
   - A Matrix room with Element Call enabled. The room's power levels must allow level-0 users to send `org.matrix.msc3401.call.member` state events. Starting an Element Call session in the room sets this automatically.
   - The internal Matrix room ID in `!roomid:domain` form (fetching varies based on your Matrix client).

## Adjusting the playbook configuration

Add the following to your `vars.yml` configuration file:

```yaml
matrix_nether_voicebridge_enabled: true

# One or more Discord bot tokens (the shared puppet pool)
matrix_nether_voicebridge_puppet_tokens:
  - "YOUR_DISCORD_BOT_TOKEN_1"
  - "YOUR_DISCORD_BOT_TOKEN_2"

# One or more Discord channel ↔ Matrix room mappings
matrix_nether_voicebridge_bridges:
  - name: "lobby"
    discord_guild_id: "YOUR_DISCORD_SERVER_ID"
    discord_channel_id: "YOUR_DISCORD_VOICE_CHANNEL_ID"
    matrix_room_id: "!yourroomid:example.com"
```

## How the puppet pool works

The bridge allocates puppet bots dynamically. Each active Discord channel reserves one bot as a capture anchor. Additional bots become individually-named voice participants for Matrix speakers. More simultaneous Matrix speakers across all bridged channels requires more bots in the pool.

As a rule of thumb: pool size ≥ (number of active channels) + (max simultaneous Matrix speakers you expect).

If more Discord puppets are required than are available, the last one to join the room will be named "Overflow". Puppets may be subtracted from other rooms to cover needs.

## Ghost nickname prefix

Discord users will see Matrix participants identified by a prefix on their voice channel nickname. The default is `[Matrix] `. To change it:

```yaml
matrix_nether_voicebridge_puppet_nickname_prefix: "[Matrix] "
```

## Multiple guilds and channels

Add more entries to `matrix_nether_voicebridge_bridges` to bridge additional channel pairs from the same process. All bridges share the puppet token pool — invite all bots to all guilds you plan to bridge. If bridging multiple channels within the same guild, repeat the full pattern (including re-using the guild ID) for each channel to be bridged.

```yaml
matrix_nether_voicebridge_bridges:
  - name: "lobby"
    discord_guild_id: "111111111111111111"
    discord_channel_id: "222222222222222222"
    matrix_room_id: "!abc:example.com"
  - name: "gaming"
    discord_guild_id: "111111111111111111"
    discord_channel_id: "333333333333333333"
    matrix_room_id: "!xyz:example.com"
```

## Advanced configuration

To override lk-jwt or LiveKit SFU endpoints, or force media E2EE on or off for specific bridges, use the extension variable:

```yaml
matrix_nether_voicebridge_configuration_extension_toml: |
  # Any valid TOML appended verbatim to config.toml
```

For verbose logging during troubleshooting:

```yaml
matrix_nether_voicebridge_rust_log: "nether_voicebridge=debug,nvb_discord=debug"
```

## Self-building the container image

The prebuilt image from `nether.codes/dark/nether-voicebridge` is used by default. To build from source instead:

```yaml
matrix_nether_voicebridge_container_image_self_build: true
```

Note: self-build requires `cmake`, `clang`, `libopus-dev`, `protobuf-compiler`, and `libssl-dev` on the build host, and will take significantly longer due to WebRTC C++ compilation.

## Installing

After configuring, run the playbook:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-matrix-nether-voicebridge,start
```

Or as part of a full install:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```
