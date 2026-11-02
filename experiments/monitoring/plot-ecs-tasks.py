"""Plot the ECS task-count samples collected by capture-ecs.ps1."""

import argparse
import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import matplotlib

matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt


def timestamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


parser = argparse.ArgumentParser()
parser.add_argument("input", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--start", required=True)
parser.add_argument("--end", required=True)
parser.add_argument("--event", help="UTC timestamp of a scaling action")
parser.add_argument("--title", default="ECS desired and running tasks")
args = parser.parse_args()

start, end = timestamp(args.start), timestamp(args.end)
samples = {"gateway": [], "backend": []}
for line in args.input.read_text(encoding="utf-8-sig").splitlines():
    row = json.loads(line)
    if row.get("service") not in samples:
        continue
    when = timestamp(row["timestamp_utc"])
    if start <= when <= end:
        samples[row["service"]].append((when, row["running"], row["desired"]))

if not any(samples.values()):
    raise SystemExit("No ECS task-count samples in the requested window")

local = ZoneInfo("America/New_York")
fig, ax = plt.subplots(figsize=(10, 4.8))
for service, color in (("gateway", "#1768ac"), ("backend", "#e07020")):
    rows = sorted(samples[service])
    if not rows:
        continue
    times = [row[0].astimezone(local) for row in rows]
    ax.step(times, [row[1] for row in rows], where="post", label=f"{service} running", color=color, linewidth=2)
    ax.step(times, [row[2] for row in rows], where="post", label=f"{service} desired", color=color, linewidth=1.5, linestyle="--", alpha=0.7)
if args.event:
    ax.axvline(timestamp(args.event).astimezone(local), color="#aa2222", linestyle=":", label="scale-out requested")
ax.set_title(args.title)
ax.set_ylabel("ECS task count")
ax.set_xlabel("Time (America/New_York)")
ax.set_ylim(0, 5)
ax.set_yticks(range(0, 6))
ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M", tz=local))
ax.grid(axis="y", alpha=0.25)
ax.legend(loc="upper left", ncol=2, fontsize=8)
fig.text(0.12, 0.01, "Source: ECS DescribeServices samples, approximately every 30 seconds.", fontsize=8)
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig(args.output, dpi=150)
