#!/usr/bin/env python3
"""Unified PipeWire / WirePlumber audio switcher for Desktop (soundbar) and TV (HDMI) modes.

Usage:
  audio-switch desktop
  audio-switch tv
"""

import glob
import json
import os
import subprocess
import sys
import time

GPU_CARD_NAME = os.environ["GPU_AUDIO_CARD"]
GPU_SINK_MATCH = os.environ["GPU_SINK_MATCH"]
SOUNDBAR_SINK_MATCH = os.environ["SOUNDBAR_SINK_MATCH"]
DESKTOP_EDID_NAME = os.environ["DESKTOP_EDID_NAME"]
TV_EDID_NAME = os.environ["TV_EDID_NAME"]


def pw_dump() -> list[dict]:
    proc = subprocess.run(["pw-dump"], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        return []
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []


def set_default_sink(sink_id: int, sink_name: str, label: str) -> None:
    subprocess.run(["wpctl", "set-default", str(sink_id)], check=True)
    print(f"Audio set to {label}: {sink_name} (id {sink_id})")


# -----------------------------------------------------------------------------
# Desktop Mode (Soundbar)
# -----------------------------------------------------------------------------
def find_soundbar_sink():
    for obj in pw_dump():
        props = (obj.get("info") or {}).get("props") or {}
        if props.get("media.class") == "Audio/Sink":
            name = props.get("node.name") or ""
            if SOUNDBAR_SINK_MATCH in name:
                return obj["id"], name
    return None


def switch_to_desktop() -> int:
    sink = None
    for _ in range(10):
        sink = find_soundbar_sink()
        if sink:
            break
        time.sleep(0.5)

    if not sink:
        print(f"Error: Soundbar (*{SOUNDBAR_SINK_MATCH}*) not found in PipeWire.", file=sys.stderr)
        return 1

    set_default_sink(sink[0], sink[1], "soundbar")
    return 0


# -----------------------------------------------------------------------------
# TV Mode (HDMI)
# -----------------------------------------------------------------------------
def wait_for_tv_eld(timeout_s: float = 25.0):
    """Wait until ALSA reports a valid HDMI ELD for the TV (ignoring the desktop monitor)."""
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        for path in sorted(glob.glob("/proc/asound/card*/eld*")):
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    fields = {}
                    for line in f:
                        parts = line.strip().split(None, 1)
                        if len(parts) == 2:
                            fields[parts[0]] = parts[1].strip()
            except OSError:
                continue

            if fields.get("monitor_present") == "1" and fields.get("eld_valid") == "1":
                mon_name = fields.get("monitor_name", "")
                if mon_name and DESKTOP_EDID_NAME.lower() not in mon_name.lower():
                    return path, mon_name
        time.sleep(0.5)
    return None


def parse_route_info(info) -> dict[str, str]:
    result: dict[str, str] = {}
    if isinstance(info, list) and len(info) > 1:
        items = info[1:]
        for i in range(0, len(items) - 1, 2):
            result[str(items[i])] = str(items[i + 1])
    return result


def switch_gpu_card_profile() -> None:
    """Ensure the AMD GPU audio device uses the active TV HDMI stereo profile."""
    card = None
    for obj in pw_dump():
        props = (obj.get("info") or {}).get("props") or {}
        if props.get("device.name") == GPU_CARD_NAME:
            card = obj
            break
    if not card:
        return

    params = (card.get("info") or {}).get("params") or {}
    cur_profiles = params.get("Profile") or []
    cur_idx = cur_profiles[0].get("index", -1) if cur_profiles else -1

    enum_profiles = {p["index"]: p for p in (params.get("EnumProfile") or []) if "index" in p}
    enum_routes = params.get("EnumRoute") or []

    candidates = []
    for route in enum_routes:
        if route.get("direction") != "Output" or route.get("available") != "yes":
            continue
        rinfo = parse_route_info(route.get("info"))
        prod = rinfo.get("device.product.name", "").lower()

        if TV_EDID_NAME.lower() in prod:
            rank = 0
        elif DESKTOP_EDID_NAME.lower() not in prod:
            rank = 1
        else:
            rank = 2

        for pidx in route.get("profiles") or []:
            prof = enum_profiles.get(pidx)
            if prof and (prof.get("name") or "").startswith("output:hdmi-stereo"):
                candidates.append((rank, pidx, prof["name"]))
                break

    if not candidates:
        return

    candidates.sort(key=lambda item: item[0])
    _, target_idx, target_name = candidates[0]
    if target_idx != cur_idx:
        print(f"Switching GPU audio device {card['id']} to profile {target_idx} ({target_name})")
        subprocess.run(["wpctl", "set-profile", str(card["id"]), str(target_idx)], check=True)
        time.sleep(0.5)


def find_tv_sink():
    primary = None
    fallback = None
    for obj in pw_dump():
        props = (obj.get("info") or {}).get("props") or {}
        if props.get("media.class") != "Audio/Sink":
            continue
        name = props.get("node.name") or ""
        if GPU_SINK_MATCH in name and "hdmi-stereo" in name:
            primary = (obj["id"], name)
            break
        if "hdmi-stereo" in name and fallback is None:
            fallback = (obj["id"], name)
    return primary or fallback


def is_steam_client_connected() -> bool:
    for obj in pw_dump():
        if obj.get("type") != "PipeWire:Interface:Client":
            continue
        props = (obj.get("info") or {}).get("props") or {}
        app_name = (props.get("application.name") or "").lower()
        proc_bin = (props.get("application.process.binary") or "").lower()
        if "steam" in app_name or "steam" in proc_bin:
            return True
    return False


def wait_for_steam_client(timeout_s: float = 12.0) -> bool:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if is_steam_client_connected():
            return True
        time.sleep(0.5)
    return False


def apply_tv_sink() -> bool:
    sink = None
    for _ in range(20):
        sink = find_tv_sink()
        if sink:
            break
        time.sleep(0.5)

    if not sink:
        print("Error: TV audio output (*hdmi-stereo) not found in PipeWire.", file=sys.stderr)
        return False

    set_default_sink(sink[0], sink[1], "TV")
    return True


def switch_to_tv() -> int:
    eld = wait_for_tv_eld(timeout_s=25.0)
    if eld:
        print(f"Detected TV HDMI ELD: {eld[0]} ({eld[1]})")
    else:
        print(
            "Warning: Timed out waiting for TV ELD; attempting PipeWire HDMI card detection anyway.",
            file=sys.stderr,
        )

    switch_gpu_card_profile()

    if not apply_tv_sink():
        return 1

    # Wait until Steam connects to PipeWire, then re-assert the TV default sink
    if wait_for_steam_client(timeout_s=12.0):
        apply_tv_sink()
    return 0


def main() -> int:
    target = sys.argv[1] if len(sys.argv) > 1 else ""
    if target == "desktop":
        return switch_to_desktop()
    if target == "tv":
        return switch_to_tv()

    print("Usage: audio-switch {desktop|tv}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
