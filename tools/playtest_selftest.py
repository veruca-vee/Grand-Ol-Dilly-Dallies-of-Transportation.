#!/usr/bin/env python3
"""Self-test for tools/playtest_digest.py — written BEFORE the
parser, per METHOD.md (this file's first run is the parser's RED).

Builds two fake playtest sessions:

* PLANTED — a session with exactly four anomalies, one per
  digest rule (on-foot position jump > 25 u, y out of
  [-5, 30], fps < 20 sustained >= 3 s, NaN), plus a MARKER
  event and three fake frames. The y anomaly is a RUN of
  three consecutive out-of-range snapshots: the digest must
  group consecutive same-rule anomalies into ONE entry with
  a t-range and a count (the 2026-11-01 live fall produced
  22 y lines for a single fall). One frame uses the new
  session-stamped name (frame-<yyyymmdd-hhmmss>-<t>.png);
  the others use the old name — both must parse.
* CLEAN — a session that must produce ZERO anomalies,
  including the traps: a brief 1 s fps dip (not sustained),
  and a 30 u position jump while in_car=true (the jump rule
  is on-foot only).

Run:  python3 tools/playtest_selftest.py
Exit 0 + "PARSER SELFTEST PASS" line when the parser flags
exactly the planted set and nothing in the clean session.
"""

import importlib.util
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PARSER_PATH = os.path.join(HERE, "playtest_digest.py")

SNAP = ("t={t:.2f} SNAPSHOT pos={x:.2f},{y:.2f},{z:.2f} "
        "vy=-0.50 fps={fps} wanted=0.00 in_car={car} "
        "hp={hp} cash=0")


def snap(t, x=0.0, y=0.20, z=0.0, fps=60, car="false", hp="100.0"):
    return SNAP.format(t=t, x=x, y=y, z=z, fps=fps, car=car, hp=hp)


def planted_lines():
    lines = [
        "# GODOT-TELEMETRY v1 build=FAKE-PLANTED godot=4.3-stable "
        "started=2026-11-01T00:00:00",
        "t=0.00 EVENT SESSION_START build=FAKE-PLANTED",
        snap(0.00, x=0.0),
        snap(0.50, x=1.0),
        snap(1.00, x=40.0),          # PLANTED jump: 39 u on foot
        snap(1.50, x=41.0),
        snap(2.00, x=41.0, y=-9.0),  # PLANTED y run (1 of 3)
        snap(2.50, x=41.0, y=-30.0, fps=10),  # y run (2 of 3); fps run starts (7 x 0.5 s)
        snap(3.00, x=41.0, y=-80.0, fps=10),  # y run (3 of 3)
        snap(3.50, x=41.0, fps=10),
        snap(4.00, x=41.0, fps=10),
        snap(4.50, x=41.0, fps=10),
        snap(5.00, x=41.0, fps=10),
        snap(5.50, x=41.0, fps=10),  # PLANTED fps < 20 for 3.0 s
        snap(6.00, x=41.0, hp="nan"),  # PLANTED NaN
        "t=6.50 EVENT MARKER",
        "t=7.00 EVENT BUSTED score=10 cash=5",
    ]
    return lines


def clean_lines():
    lines = [
        "# GODOT-TELEMETRY v1 build=FAKE-CLEAN godot=4.3-stable "
        "started=2026-11-01T01:00:00",
        "t=0.00 EVENT SESSION_START build=FAKE-CLEAN",
    ]
    # gentle on-foot walk, 2 u per snapshot
    for i in range(8):
        lines.append(snap(0.50 * i, x=2.0 * i))
    # brief fps dip: 2 snapshots = 0.5 s span, NOT sustained
    lines.append(snap(4.00, x=16.0, fps=15))
    lines.append(snap(4.50, x=18.0, fps=15))
    lines.append(snap(5.00, x=20.0, fps=60))
    # in a car now: a 30 u jump between snapshots must NOT flag
    lines.append(snap(5.50, x=20.0, car="true"))
    lines.append(snap(6.00, x=50.0, car="true"))
    lines.append("t=6.50 EVENT PICKUP kind=cash")
    lines.append("t=7.00 EVENT MARKER")
    return lines


def write_session(root, name, lines, frame_names):
    d = os.path.join(root, name)
    os.makedirs(d)
    with open(os.path.join(d, "session-20261101-000000.log"),
              "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    for fn in frame_names:
        with open(os.path.join(d, fn), "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\nfake")
    return d


def main():
    failures = []

    if not os.path.exists(PARSER_PATH):
        print("PARSER SELFTEST FAIL: tools/playtest_digest.py "
              "does not exist yet (parser not written)")
        return 1
    spec = importlib.util.spec_from_file_location(
        "playtest_digest", PARSER_PATH)
    digest = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(digest)

    root = tempfile.mkdtemp(prefix="playtest_selftest_")
    try:
        planted = write_session(
            root, "planted", planted_lines(),
            ["frame-0.00.png", "frame-20261101-000000-5.75.png",
             "frame-20.00.png"])
        clean = write_session(
            root, "clean", clean_lines(),
            ["frame-0.00.png", "frame-9.50.png"])

        p = digest.analyze_session(planted)
        got = sorted((a["rule"], a["t"]) for a in p["anomalies"])
        want = sorted([
            ("position_jump", 1.00),
            ("y_out_of_range", 2.00),
            ("fps_sustained", 2.50),
            ("nan", 6.00),
        ])
        if got != want:
            failures.append(
                "planted anomalies %s != expected %s" % (got, want))
        if p["snapshot_count"] != 13:
            failures.append("planted snapshot_count %d != 13"
                            % p["snapshot_count"])
        if abs(p["duration"] - 7.00) > 0.001:
            failures.append("planted duration %s != 7.00"
                            % p["duration"])
        if p["event_tallies"].get("BUSTED") != 1:
            failures.append("planted BUSTED tally %s != 1"
                            % p["event_tallies"].get("BUSTED"))
        if len(p["markers"]) != 1:
            failures.append("planted markers %s != 1 entry"
                            % p["markers"])
        elif p["markers"][0].get("nearest_frame") \
                != "frame-20261101-000000-5.75.png":
            failures.append(
                "marker at t=6.50 nearest frame is %s, "
                "expected frame-20261101-000000-5.75.png"
                % p["markers"][0].get("nearest_frame"))
        # grouping: the 3-snapshot y run is ONE entry, count 3,
        # spanning t=2.00..3.00 (not three separate anomalies)
        y_entries = [a for a in p["anomalies"]
                     if a["rule"] == "y_out_of_range"]
        if len(y_entries) != 1:
            failures.append(
                "planted y run produced %d entries, expected "
                "1 grouped entry" % len(y_entries))
        else:
            ye = y_entries[0]
            if ye.get("count") != 3:
                failures.append(
                    "grouped y entry count %s != 3"
                    % ye.get("count"))
            if abs(ye.get("t_end", -1) - 3.00) > 0.001:
                failures.append(
                    "grouped y entry t_end %s != 3.00"
                    % ye.get("t_end"))
        if len(p["frames"]) != 3:
            failures.append("planted frames %s != 3" % p["frames"])
        for a in p["anomalies"]:
            if "nearest_frame" not in a:
                failures.append("anomaly %s has no nearest_frame"
                                % a)

        c = digest.analyze_session(clean)
        if c["anomalies"]:
            failures.append("clean session flagged anomalies: %s"
                            % c["anomalies"])
        if c["event_tallies"].get("PICKUP") != 1:
            failures.append("clean PICKUP tally %s != 1"
                            % c["event_tallies"].get("PICKUP"))
    finally:
        shutil.rmtree(root, ignore_errors=True)

    if failures:
        for f in failures:
            print("PARSER SELFTEST FAIL: " + f)
        return 1
    print("PARSER SELFTEST PASS: planted_exact clean_zero "
          "marker_nearest_frame grouped_anomalies")
    return 0


if __name__ == "__main__":
    sys.exit(main())
