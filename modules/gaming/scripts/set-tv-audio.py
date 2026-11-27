#!/usr/bin/env python3
"""Switch PipeWire / WirePlumber audio output to the TV HDMI sink in Gamescope mode."""

import glob
import json
import subprocess
import sys
import time

GPU_CARD_NAME = "alsa_card.pci-0000_0d_00.1"
GPU_SINK_HINT = "pci-0000_0d_00.1"
DESKTOP_MONITOR_NAME = "LC49G95T"
TV_MONITOR_HINT = "HISENSE"


def pw_dump():
    proc = subprocess.run(["pw-dump"], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        return []
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []


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
                if mon_name and DESKTOP_MONITOR_NAME.lower() not in mon_name.lower():
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
    data = pw_dump()
    card = None
    for obj in data:
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

        if TV_MONITOR_HINT.lower() in prod:
            rank = 0
        elif DESKTOP_MONITOR_NAME.lower() not in prod:
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
        if GPU_SINK_HINT in name and "hdmi-stereo" in name:
            primary = (obj["id"], name)
            break
        if "hdmi-stereo" in name and fallback is None:
            fallback = (obj["id"], name)
    return primary or fallback


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

    sink_id, sink_name = sink
    subprocess.run(["wpctl", "set-default", str(sink_id)], check=True)
    print(f"Audio set to TV: {sink_name} (id {sink_id})")
    return True


def main() -> int:
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

    # Re-assert default sink once Steam UI finishes booting and opens its audio streams
    time.sleep(4.0)
    apply_tv_sink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
