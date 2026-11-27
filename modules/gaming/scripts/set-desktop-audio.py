#!/usr/bin/env python3
"""Switch PipeWire default audio sink to the desktop soundbar (*iec958-stereo)."""

import json
import subprocess
import sys
import time


def find_soundbar_sink():
    proc = subprocess.run(["pw-dump"], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None

    for obj in data:
        props = (obj.get("info") or {}).get("props") or {}
        if props.get("media.class") == "Audio/Sink":
            name = props.get("node.name") or ""
            if "iec958-stereo" in name:
                return obj["id"], name
    return None


def main() -> int:
    # Wait up to 5s for PipeWire to expose the soundbar Audio/Sink
    sink = None
    for _ in range(10):
        sink = find_soundbar_sink()
        if sink:
            break
        time.sleep(0.5)

    if not sink:
        print("Error: Soundbar (*iec958-stereo) not found in PipeWire.", file=sys.stderr)
        return 1

    sink_id, sink_name = sink
    subprocess.run(["wpctl", "set-default", str(sink_id)], check=True)
    print(f"Audio set to soundbar: {sink_name} (id {sink_id})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
