"""Render a presentation image from LTspice's binary .raw and .log results.

Run LTspice on phone_anc_timing.asc first, then run this file. Requires the
numpy and matplotlib packages listed in the repository's requirements.txt.
"""

from pathlib import Path
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


HERE = Path(__file__).resolve().parent
raw = (HERE / "phone_anc_timing.raw").read_bytes()
marker = "Binary:\n".encode("utf-16le")
cut = raw.index(marker)
header = raw[:cut].decode("utf-16le")
points = int(re.search(r"No\. Points:\s*(\d+)", header).group(1))
variables = re.findall(r"^\s*\d+\s+(\S+)\s+\S+", header, flags=re.M)
dtype = np.dtype([("time", "<f8"), ("values", "<f4", (len(variables) - 1,))])
data = np.frombuffer(raw, dtype=dtype, offset=cut + len(marker), count=points)
assert len(data) == points
breaks = np.r_[0, np.where(np.diff(data["time"]) < 0)[0] + 1, points]
assert len(breaks) == 3, "Expected two stepped simulations"

log = (HERE / "phone_anc_timing.log").read_text(errors="replace")
section = log.split("Measurement: reduction_db", 1)[1]
reductions = [float(x) for x in re.findall(r"^\s*[12]\s+(-?\d+(?:\.\d+)?)", section, re.M)[:2]]
assert len(reductions) == 2

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                     "figure.facecolor": "#f5f8fc", "axes.facecolor": "white",
                     "axes.grid": True, "grid.alpha": 0.18})
fig = plt.figure(figsize=(12, 7.3))
fig.suptitle("LTspice | Phone ANC timing experiment", x=0.06, y=0.975,
             ha="left", weight="bold", fontsize=19, color="#17335a")
fig.text(0.06, 0.925, "Electrical voltage represents normalized sound pressure at the ear",
         color="#54657a", fontsize=10)

for idx, (start, stop, app_ms) in enumerate(zip(breaks[:-1], breaks[1:], (2, 20))):
    ax = fig.add_axes([0.08, 0.56 - idx * 0.45, 0.71, 0.30])
    part = data[start:stop]
    time_ms = part["time"] * 1000
    take = time_ms >= 60
    for name, color, width, label in [
        ("V(noise)", "#374357", 1.65, "Noise at ear"),
        ("V(anti)", "#e89a35", 1.55, "Antinoise at ear"),
        ("V(residual)", "#1680bd" if idx == 0 else "#d54a50", 2.2, "Residual")
    ]:
        values = part["values"][:, variables.index(name) - 1]
        ax.plot(time_ms[take], values[take], color=color, lw=width, label=label)
    ax.set(xlim=(60, 100), ylim=(-2.3, 2.3), ylabel="Normalized pressure",
           xlabel="Simulation time (ms)")
    ax.set_title(f"App delay {app_ms} ms  |  acoustic mic lead 5 ms  |  earphone delay 1 ms",
                 loc="left", weight="bold", color="#243650", pad=9)
    ax.legend(loc="upper left", ncol=3, frameon=False, fontsize=9)
    fig.text(0.885, 0.71 - idx * 0.45,
             f"{reductions[idx]:+.1f} dB\n" + ("reduction" if reductions[idx] > 0 else "amplification"),
             ha="center", va="center", fontsize=15, weight="bold",
             color="#126c9e" if reductions[idx] > 0 else "#bd3b44",
             bbox=dict(boxstyle="round,pad=0.7", fc="white", ec="#cdd9e7"))

fig.text(0.06, 0.015,
         "LTspice behavioral acoustic-path model with a real RC mic input; simulated values, not phone measurements.",
         color="#57677b", fontsize=9)
target = HERE / "phone_anc_preview.png"
fig.savefig(target, dpi=175)
plt.close(fig)
print(target)
