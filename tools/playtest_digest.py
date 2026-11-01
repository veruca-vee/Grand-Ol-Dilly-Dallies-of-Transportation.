#!/usr/bin/env python3
"""Playtest telemetry digest — stdlib only, not shipped in the
game export.

Reads a playtest session dir (as written by core DebugLog:
session-<yyyymmdd-hhmmss>.log + frame-<t>.png files beside it)
and prints a Markdown digest per session log: duration,
snapshot/event counts, event tallies, an ANOMALIES list, the
frame index, and the nearest frame to every marker/anomaly.

Anomaly rules (TELEMETRY_SPEC statement 6, exactly):
  * position jump > 25 u between consecutive snapshots while
    on foot (in_car=false on both)
  * y < -5 or y > 30
  * fps < 20 sustained >= 3 s (one anomaly per low-fps run)
  * NaN anywhere in a log line

Usage: python3 tools/playtest_digest.py <session-dir>
"""

import glob
import math
import os
import re
import sys

SNAP_RE = re.compile(
    r"^t=(\S+) SNAPSHOT pos=(\S+?),(\S+?),(\S+?) vy=(\S+) "
    r"fps=(\S+) wanted=(\S+) in_car=(\S+) hp=(\S+) cash=(\S+)")
EVENT_RE = re.compile(r"^t=(\S+) EVENT (\S+)(?:\s+(.*))?$")
FRAME_RE = re.compile(r"^frame-(\d+(?:\.\d+)?)(?:-\d+)?\.png$")
T_RE = re.compile(r"^t=(\S+)")
JUMP_LIMIT = 25.0
Y_MIN, Y_MAX = -5.0, 30.0
FPS_LIMIT = 20
FPS_SUSTAIN_S = 3.0


def _float(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def _line_has_nan(line):
    """True if any k=v token (or comma-part of one) is NaN."""
    for tok in line.split():
        if "=" not in tok:
            continue
        for part in tok.split("=", 1)[1].split(","):
            v = _float(part)
            if v is not None and math.isnan(v):
                return True
            if part.lower() == "nan":
                return True
    return False


def _line_t(line):
    m = T_RE.match(line)
    if not m:
        return None
    return _float(m.group(1))


def list_frames(session_dir):
    frames = []
    for path in sorted(glob.glob(os.path.join(session_dir,
                                              "frame-*.png"))):
        m = FRAME_RE.match(os.path.basename(path))
        if m:
            frames.append({"t": float(m.group(1)),
                           "name": os.path.basename(path)})
    frames.sort(key=lambda f: f["t"])
    return frames


def _nearest_frame(frames, t):
    if not frames or t is None:
        return None
    return min(frames, key=lambda f: abs(f["t"] - t))["name"]


def analyze_log(log_path, frames):
    """Parse one session log; frames is the dir's frame index."""
    build = None
    duration = 0.0
    snapshots = []          # parsed snapshot dicts, in order
    snapshot_count = 0
    tallies = {}
    pickup_kinds = {}
    markers = []
    anomalies = []
    fps_run_start = None
    fps_run_last = None

    def close_fps_run():
        nonlocal fps_run_start, fps_run_last
        if fps_run_start is not None:
            span = fps_run_last - fps_run_start
            if span >= FPS_SUSTAIN_S - 1e-9:
                anomalies.append({
                    "rule": "fps_sustained",
                    "t": fps_run_start,
                    "detail": "fps < %d for %.1f s (t=%.2f..%.2f)"
                              % (FPS_LIMIT, span, fps_run_start,
                                 fps_run_last),
                })
        fps_run_start = None
        fps_run_last = None

    with open(log_path, "r", encoding="utf-8",
              errors="replace") as f:
        lines = f.read().splitlines()

    for line in lines:
        if line.startswith("#"):
            m = re.search(r"build=(\S+)", line)
            if m:
                build = m.group(1)
            continue
        t = _line_t(line)
        if t is None:
            continue
        duration = max(duration, t)

        if _line_has_nan(line):
            anomalies.append({
                "rule": "nan", "t": t,
                "detail": "NaN in line: %s" % line.strip()[:100],
            })

        em = EVENT_RE.match(line)
        if em:
            name = em.group(2)
            tallies[name] = tallies.get(name, 0) + 1
            rest = em.group(3) or ""
            if name == "PICKUP":
                km = re.search(r"kind=(\S+)", rest)
                if km:
                    k = km.group(1)
                    pickup_kinds[k] = pickup_kinds.get(k, 0) + 1
            if name == "MARKER":
                markers.append({"t": t})
            continue

        sm = SNAP_RE.match(line)
        if not sm:
            continue
        # groups: 1 t, 2-4 pos, 5 vy, 6 fps, 7 wanted, 8 in_car
        # (bool string), 9 hp, 10 cash
        nums = [_float(sm.group(i)) for i in (1, 2, 3, 4, 5, 6, 7, 9)]
        if any(v is None for v in nums):
            continue
        cur = {
            "t": nums[0], "x": nums[1], "y": nums[2],
            "z": nums[3], "vy": nums[4], "fps": nums[5],
            "wanted": nums[6], "hp": nums[7],
            "in_car": sm.group(8) == "true",
        }
        snapshot_count += 1

        if cur["y"] is not None and (cur["y"] < Y_MIN
                                     or cur["y"] > Y_MAX):
            anomalies.append({
                "rule": "y_out_of_range", "t": cur["t"],
                "detail": "y=%.2f outside [%.0f, %.0f]"
                          % (cur["y"], Y_MIN, Y_MAX),
            })

        if snapshots:
            prev = snapshots[-1]
            if not prev["in_car"] and not cur["in_car"]:
                d = math.hypot(cur["x"] - prev["x"],
                               cur["z"] - prev["z"])
                if d > JUMP_LIMIT:
                    anomalies.append({
                        "rule": "position_jump", "t": cur["t"],
                        "detail": "moved %.1f u on foot in %.2f s "
                                  "(t=%.2f -> t=%.2f)"
                                  % (d, cur["t"] - prev["t"],
                                     prev["t"], cur["t"]),
                    })
        snapshots.append(cur)

        fps = cur["fps"]
        if fps is not None and fps < FPS_LIMIT:
            if fps_run_start is None:
                fps_run_start = cur["t"]
            fps_run_last = cur["t"]
        else:
            close_fps_run()
    close_fps_run()

    anomalies.sort(key=lambda a: a["t"])
    for a in anomalies:
        a["nearest_frame"] = _nearest_frame(frames, a["t"])
    for mk in markers:
        mk["nearest_frame"] = _nearest_frame(frames, mk["t"])

    return {
        "file": os.path.basename(log_path),
        "build": build,
        "duration": duration,
        "snapshot_count": snapshot_count,
        "event_tallies": tallies,
        "pickup_kinds": pickup_kinds,
        "anomalies": anomalies,
        "frames": frames,
        "markers": markers,
    }


def analyze_session(session_dir):
    """Digest the newest session log in a session dir."""
    logs = sorted(glob.glob(os.path.join(session_dir,
                                         "session-*.log")))
    if not logs:
        raise FileNotFoundError(
            "no session-*.log in %s" % session_dir)
    return analyze_log(logs[-1], list_frames(session_dir))


def format_digest(session_dir):
    logs = sorted(glob.glob(os.path.join(session_dir,
                                         "session-*.log")))
    if not logs:
        return "# Playtest digest\n\nNo session-*.log in `%s`.\n" \
            % session_dir
    frames = list_frames(session_dir)
    out = ["# Playtest digest — %s" % session_dir, ""]
    for log_path in logs:
        d = analyze_log(log_path, frames)
        out.append("## Session %s" % d["file"])
        out.append("")
        tally_str = ", ".join(
            "%s×%d" % (k, d["event_tallies"][k])
            for k in sorted(d["event_tallies"])) or "none"
        out.append("- build: %s · duration: %.1f s · snapshots: "
                   "%d · events: %s"
                   % (d["build"] or "?", d["duration"],
                      d["snapshot_count"], tally_str))
        if d["pickup_kinds"]:
            pk = ", ".join("%s×%d" % (k, d["pickup_kinds"][k])
                           for k in sorted(d["pickup_kinds"]))
            out.append("- pickups: %s" % pk)
        out.append("")
        out.append("### Anomalies (%d)" % len(d["anomalies"]))
        out.append("")
        if d["anomalies"]:
            for a in d["anomalies"]:
                nf = a.get("nearest_frame") or "none"
                out.append("- t=%.2f [%s] %s (nearest frame: %s)"
                           % (a["t"], a["rule"], a["detail"], nf))
        else:
            out.append("None.")
        out.append("")
        out.append("### Markers (%d)" % len(d["markers"]))
        out.append("")
        if d["markers"]:
            for mk in d["markers"]:
                out.append("- t=%.2f → nearest frame: %s"
                           % (mk["t"],
                              mk.get("nearest_frame") or "none"))
        else:
            out.append("None.")
        out.append("")
        out.append("### Frames (%d)" % len(frames))
        out.append("")
        if frames:
            for fr in frames:
                out.append("- t=%.2f %s" % (fr["t"], fr["name"]))
        else:
            out.append("None.")
        out.append("")
    return "\n".join(out)


def main(argv):
    if len(argv) != 2:
        print("usage: playtest_digest.py <session-dir>",
              file=sys.stderr)
        return 2
    target = argv[1]
    session_dir = target if os.path.isdir(target) \
        else os.path.dirname(os.path.abspath(target))
    print(format_digest(session_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
