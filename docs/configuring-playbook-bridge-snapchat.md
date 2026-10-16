<!--
SPDX-FileCopyrightText: 2026 MDAD project contributors
SPDX-FileCopyrightText: 2026 Jason LaGuidice

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Snapchat bridging (optional)

The playbook can install and configure [matrix-snapchat-bridge](https://github.com/jasonlaguidice/matrix-snapchat-bridge) for you.

See the project's [documentation](https://github.com/jasonlaguidice/matrix-snapchat-bridge/blob/main/README.md) to learn what it does, which features are supported and why it might be useful to you.

**Note**: Snapchat has no public API and works to break third-party clients, so this bridge may stop working or put your account at risk. Consider using a throwaway account.

## Adjusting the playbook configuration

To enable the [Snapchat](https://www.snapchat.com/) bridge, add the following configuration to your `inventory/host_vars/matrix.example.com/vars.yml` file:

```yaml
matrix_bridge_snapchat_enabled: true
```

## Installing

After configuring the playbook, run it with [playbook tags](playbook-tags.md) as below:

<!-- NOTE: let this conservative command run (instead of install-all) to make it clear that failure of the command means something is clearly broken. -->
```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

The shortcut commands with the [`just` program](just.md) are also available: `just install-all` and `just setup-all`

`just install-all` is useful for maintaining your setup quickly ([2x-5x faster](../CHANGELOG.md#2x-5x-performance-improvements-in-playbook-runtime) than `just setup-all`) when its components remain unchanged. If you adjust your `vars.yml` to remove other components, you'd need to run `just setup-all`, or these components will still remain installed. Note these shortcuts run the `ensure-matrix-users-created` tag too.

The tag for `just` commands for this bridge is `matrix-snapchat-bridge` - for example: `just install-service matrix-snapchat-bridge`

## Usage

To use the bridge, you need to start a chat with `Snapchat bridge bot` with the handle `@snapchatbot:example.com` (where `example.com` is your base domain, not the `matrix.` domain).

Send `help` to the bot to see the available commands, and `login` to log in. See the bridge's [documentation](https://github.com/jasonlaguidice/matrix-snapchat-bridge/blob/main/README.md) for the supported login method.

## Notable Configuration Options

- End-to-bridge encryption is allowed and enabled by default for new portals, following the playbook-wide `matrix_bridges_encryption_enabled` and `matrix_bridges_encryption_default` settings.
- The bridge keeps its private Snapchat identity keys (and downloaded Snapchat web assets) in `/matrix/matrix-snapchat-bridge/data/talkcore-data`. Treat this directory as secret and keep it out of shared backups.
- This bridge does not support metrics.
