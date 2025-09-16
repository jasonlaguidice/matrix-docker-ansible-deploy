<!--
SPDX-FileCopyrightText: 2023 Johan Swetzén
SPDX-FileCopyrightText: 2023 Slavi Pantaleev
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Mautrix wsproxy for bridging Android SMS or Apple iMessage (optional)

<sup>Refer the common guide for configuring mautrix bridges: [Setting up a Generic Mautrix Bridge](configuring-playbook-bridge-mautrix-bridges.md)</sup>

The playbook can install and configure [mautrix-wsproxy](https://github.com/mautrix/wsproxy) for you.

See the project's [documentation](https://github.com/mautrix/wsproxy/blob/master/README.md) to learn what it does and why it might be useful to you.

## Adjusting DNS records

By default, this playbook installs wsproxy on the `wsproxy.` subdomain (`wsproxy.example.com`) and requires you to create a CNAME record for `wsproxy`, which targets `matrix.example.com`.

When setting, replace `example.com` with your own.

## Adjusting the playbook configuration

To enable the bridge, add the following configuration to your `inventory/host_vars/matrix.example.com/vars.yml` file:

```yaml
matrix_mautrix_wsproxy_enabled: true

matrix_mautrix_androidsms_appservice_token: 'secret token from bridge'
matrix_mautrix_androidsms_homeserver_token: 'secret token from bridge'
matrix_mautrix_imessage_appservice_token: 'secret token from bridge'
matrix_mautrix_imessage_homeserver_token: 'secret token from bridge'
matrix_mautrix_wsproxy_syncproxy_shared_secret: 'secret token from bridge'
```

Note that the tokens must match what is compiled into the [mautrix-imessage](https://github.com/mautrix/imessage) bridge running on your Mac or Android device.

### Multiple Bridge Instances (Advanced)

For users who want to run multiple instances of the same bridge type (e.g., multiple iMessage bridges for different Apple IDs, or multiple Android SMS bridges for different devices), you can extend the configuration:

```yaml
matrix_mautrix_wsproxy_enabled: true

# Configure default instances (required - these use the standard variables)
matrix_mautrix_androidsms_appservice_token: 'primary-android-token'
matrix_mautrix_androidsms_homeserver_token: 'primary-android-hs-token'
matrix_mautrix_imessage_appservice_token: 'primary-imessage-token'
matrix_mautrix_imessage_homeserver_token: 'primary-imessage-hs-token'
matrix_mautrix_wsproxy_syncproxy_shared_secret: 'shared-secret'

# Add additional bridge instances
matrix_mautrix_wsproxy_appservices_additional:
  - id: imessage2
    type: imessage
    as_token: 'imessage2-as-token'
    hs_token: 'imessage2-hs-token'
    bot_username: 'imessage2_bot'
    namespace_prefix: 'imessage2'

  - id: androidsms_secondary
    type: androidsms
    as_token: 'secondary-android-as-token'
    hs_token: 'secondary-android-hs-token'
    bot_username: 'androidsms_secondary_bot'
    namespace_prefix: 'androidsms_secondary'
```

#### Configuration Parameters

Each appservice entry supports the following parameters:

- `id`: Unique identifier for the appservice (required)
- `type`: Bridge type (`imessage` or `androidsms`) (required)
- `as_token`: Application service token from your bridge client (required)
- `hs_token`: Homeserver token for the appservice (required)
- `bot_username`: Username for the bridge bot (required)
- `namespace_prefix`: Prefix for user namespaces (required, must be unique)

#### Important Notes

1. **Token Management**: Each bridge instance must have unique tokens that match your device configuration
2. **Unique Identifiers**: All `id`, `bot_username`, and `namespace_prefix` values must be unique across all appservices

### Adjusting the wsproxy URL (optional)

By tweaking the `matrix_mautrix_wsproxy_hostname` variable, you can easily make the service available at a **different hostname** than the default one.

Example additional configuration for your `vars.yml` file:

```yaml
# Change the default hostname
matrix_mautrix_wsproxy_hostname: ws.example.com
```

After changing the domain, **you may need to adjust your DNS** records to point the wsproxy domain to the Matrix server.

### Extending the configuration

There are some additional things you may wish to configure about the bridge.

See [this section](configuring-playbook-bridge-mautrix-bridges.md#extending-the-configuration) on the [common guide for configuring mautrix bridges](configuring-playbook-bridge-mautrix-bridges.md) for details about variables that you can customize and the bridge's default configuration, including [bridge permissions](configuring-playbook-bridge-mautrix-bridges.md#configure-bridge-permissions-optional), [encryption support](configuring-playbook-bridge-mautrix-bridges.md#enable-encryption-optional), [relay mode](configuring-playbook-bridge-mautrix-bridges.md#enable-relay-mode-optional), [bot's username](configuring-playbook-bridge-mautrix-bridges.md#set-the-bots-username-optional), etc.

## Installing

After configuring the playbook and potentially [adjusting your DNS records](#adjusting-dns-records), run the playbook with [playbook tags](playbook-tags.md) as below:

<!-- NOTE: let this conservative command run (instead of install-all) to make it clear that failure of the command means something is clearly broken. -->
```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

The shortcut commands with the [`just` program](just.md) are also available: `just install-all` or `just setup-all`

`just install-all` is useful for maintaining your setup quickly ([2x-5x faster](../CHANGELOG.md#2x-5x-performance-improvements-in-playbook-runtime) than `just setup-all`) when its components remain unchanged. If you adjust your `vars.yml` to remove other components, you'd need to run `just setup-all`, or these components will still remain installed. Note these shortcuts run the `ensure-matrix-users-created` tag too.

## Usage

Follow the [mautrix-imessage documentation](https://docs.mau.fi/bridges/go/imessage/index.html) for running `android-sms` and/or `matrix-imessage` on your device(s).

## Troubleshooting

As with all other services, you can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu matrix-mautrix-wsproxy`.
