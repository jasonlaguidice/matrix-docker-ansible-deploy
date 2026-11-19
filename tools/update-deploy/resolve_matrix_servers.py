#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Jason Laguidice
#
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Resolves the known conflict between the snapchat-bridge and nether-voicebridge branches.

Both branches add their entries at the same places in group_vars/matrix_servers, so the second one merged
conflicts in 6 hunks. Each hunk is "keep both": snapchat first, then voicebridge, joined the way the surrounding
Jinja list expects. A hunk that does not look exactly like a known one aborts without writing anything.
"""
import sys

SNAP, VOICE = "snapchat", "nether_voicebridge"
RULE = "#" * 70
STEAM_RESULT = "      ([matrix_bridge_steam_registration_result | default({})] if matrix_bridge_steam_enabled else [])\n      +\n"
VOICE_RESULT = "      ([matrix_nether_voicebridge_registration_result | default({})] if matrix_nether_voicebridge_enabled else [])\n      +\n"


def side_is_snapchat(lines):
    text = "\n".join(lines)
    return SNAP in text and VOICE not in text and "voicebridge" not in text


def resolve_hunk(ours, theirs):
    if side_is_snapchat(ours):
        snap, voice = ours, theirs
    elif side_is_snapchat(theirs):
        snap, voice = theirs, ours
    else:
        raise ValueError("hunk is not snapchat-vs-voicebridge")
    if not snap or not voice:
        raise ValueError("empty side")
    first = snap[0]
    if "registration.yaml,dst=" in first:  # extra mounts of the homeserver container
        return snap + ["    +"] + voice
    if first.startswith("    (['/matrix-snapchat"):  # app_service_config_files; the rest of snap is a later variable
        if len(voice) != 1:
            raise ValueError("unexpected registration list hunk")
        return snap[:1] + ["    +"] + voice + snap[1:]
    if first.strip().startswith("'name': 'matrix-snapchat-bridge.service'"):  # systemd service list items
        return snap + ["    +", "    ([{"] + voice
    if first.strip().startswith("'^@'"):  # bridge user regexes
        return snap + ["    +", "    (["] + voice
    if first == "# matrix-bridge-snapchat":  # section header: voicebridge gets its own header in the next hunk
        return snap
    if first == "matrix_bridge_snapchat_enabled: false":  # the two variable sections
        header = ["#", RULE, "", RULE, "#", "# matrix-bridge-nether-voicebridge", "#", RULE, "",
                  "# We don't enable bridges by default."]
        return snap + ["#", RULE, ""] + header[3:] + voice
    raise ValueError("unknown hunk starting with: " + first[:80])


def main(path):
    lines = open(path).read().split("\n")
    out, i, hunks = [], 0, 0
    while i < len(lines):
        if lines[i].startswith("<<<<<<< "):
            mid = lines.index("=======", i)
            end = next(k for k in range(mid, len(lines)) if lines[k].startswith(">>>>>>> "))
            out += resolve_hunk(lines[i + 1:mid], lines[mid + 1:end])
            hunks += 1
            i = end + 1
        else:
            out.append(lines[i])
            i += 1
    text = "\n".join(out)
    if VOICE_RESULT not in text:  # make the homeserver restart when the voicebridge registration changes
        if text.count(STEAM_RESULT) != 1:
            raise ValueError("cannot place the voicebridge registration_result entry")
        text = text.replace(STEAM_RESULT, STEAM_RESULT + VOICE_RESULT)
    open(path, "w").write(text)
    print("resolved %d hunk(s)" % hunks)


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except ValueError as e:
        print("resolver: " + str(e), file=sys.stderr)
        sys.exit(1)
