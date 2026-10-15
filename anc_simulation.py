"""Causal feedforward ANC teaching simulation for a phone and wired earphones.

Run: python anc_simulation.py --output results
The delays are illustrative assumptions, not measurements from a real handset.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
import numpy as np


FS = 8000
LEAD_MS = 5.0             # Outside noise reaches reference mic before ear.
SECONDARY_MS = 1.0        # Earphone/acoustic path after app output.
FILTER_TAPS = 64
EPS = 1e-9


def samples(ms: float) -> int:
    return int(round(ms * FS / 1000))


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x))))


def make_noise(n: int, seed: int) -> np.ndarray:
    """Repeatable 120 Hz tone plus correlated broadband noise at reference mic."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal(n)
    # A first-order low-pass noise component; no signal-processing package needed.
    colored = np.empty(n)
    colored[0] = white[0]
    for i in range(1, n):
        colored[i] = 0.83 * colored[i - 1] + 0.17 * white[i]
    t = np.arange(n) / FS
    x = 0.48 * np.sin(2 * np.pi * 120 * t) + 0.70 * colored
    return x / max(rms(x), EPS)


def delay(x: np.ndarray, count: int) -> np.ndarray:
    y = np.zeros_like(x)
    if count < len(x):
        y[count:] = x[:len(x) - count]
    return y


def simulate(x: np.ndarray, app_ms: float, mu: float = 0.01) -> dict:
    """Normalized filtered-x LMS with explicit app and acoustic delays.

    d[n] = primary acoustic noise at ear.
    u[n] = negative antinoise command made by app.
    y[n] = antinoise after app/output/earphone path.
    e[n] = d[n] + y[n], the remaining acoustic pressure at ear.
    """
    n = len(x)
    primary = samples(LEAD_MS)
    secondary = samples(SECONDARY_MS)
    app = samples(app_ms)
    # Mild two-tap primary and secondary paths, intentionally simple to explain.
    d = 0.85 * delay(x, primary) + 0.15 * delay(x, primary + 3)
    sec = np.array([0.92, 0.08])
    total = app + secondary
    xf = sec[0] * delay(x, total) + sec[1] * delay(x, total + 2)
    u = np.zeros(n)
    y = np.zeros(n)
    e = np.zeros(n)
    w = np.zeros(FILTER_TAPS)
    xp = np.pad(x, (FILTER_TAPS - 1, 0))
    xfp = np.pad(xf, (FILTER_TAPS - 1, 0))
    for k in range(n):
        xv = xp[k:k + FILTER_TAPS][::-1]
        fv = xfp[k:k + FILTER_TAPS][::-1]
        u[k] = -float(w @ xv)
        y[k] = (sec[0] * u[k - total] if k >= total else 0.0)
        if k >= total + 2:
            y[k] += sec[1] * u[k - total - 2]
        e[k] = d[k] + y[k]
        # Clipping models finite output headroom; it also avoids runaway plots.
        w += (mu * e[k] / (float(fv @ fv) + 0.05)) * fv
        np.clip(w, -2.0, 2.0, out=w)
    return {"app_ms": app_ms, "d": d, "u": u, "y": y, "e": e}


def reduction_db(before: np.ndarray, after: np.ndarray) -> float:
    return 20 * np.log10((rms(before) + EPS) / (rms(after) + EPS))


def moving_rms(x: np.ndarray, block: int = 800) -> tuple[np.ndarray, np.ndarray]:
    blocks = len(x) // block
    z = x[:blocks * block].reshape(blocks, block)
    return (np.arange(blocks) + 0.5) * block / FS, np.sqrt(np.mean(z * z, axis=1))


def style() -> None:
    plt.rcParams.update({"figure.facecolor": "#f6f8fc", "axes.facecolor": "#ffffff",
                         "axes.grid": True, "grid.alpha": 0.22, "font.size": 10,
                         "savefig.dpi": 160})


def architecture(out: Path) -> None:
    fig, ax = plt.subplots(figsize=(12, 3.4))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 3.4)
    ax.axis("off")
    boxes = [(0.3, 1.5, "Ambient noise\nsource"), (2.6, 2.35, "Phone mic\nreference x[n]"),
             (5.1, 2.35, "Phone app\nFxLMS + latency"), (8.0, 2.35, "Wired earphone\nsecondary path"),
             (2.6, 0.45, "Acoustic travel\nprimary path"), (10.4, 1.5, "Ear\nresidual e[n]")]
    for xx, yy, label in boxes:
        ax.text(xx, yy, label, ha="center", va="center", fontsize=9,
                bbox=dict(boxstyle="round,pad=0.45", fc="#e9f1ff", ec="#2464ad", lw=1.6))
    def arrow(x1, y1, x2, y2, color="#26364d"):
        ax.annotate("", (x2, y2), (x1, y1), arrowprops=dict(arrowstyle="->", lw=1.8, color=color))
    arrow(1.15, 1.85, 2.0, 2.35); arrow(3.6, 2.35, 4.0, 2.35)
    arrow(6.25, 2.35, 6.65, 2.35); arrow(9.15, 2.35, 9.35, 1.85)
    arrow(1.15, 1.15, 1.9, 0.5); arrow(3.7, 0.5, 9.45, 1.5)
    ax.text(7.0, 1.35, "At ear: residual = noise + antinoise", ha="center", color="#9b3043")
    ax.set_title("Software ANC concept: two paths must meet at the ear", weight="bold")
    fig.savefig(out / "01_signal_flow.png", bbox_inches="tight")
    plt.close(fig)


def plots(out: Path, x: np.ndarray, runs: list[dict], start_s: float) -> None:
    colors = ["#176db5", "#cf4c4c"]
    fig, axs = plt.subplots(2, 1, figsize=(11, 7), constrained_layout=True)
    lo, hi = int(start_s * FS), int((start_s + 0.06) * FS)
    time_ms = (np.arange(lo, hi) - lo) * 1000 / FS
    d = runs[0]["d"]
    axs[0].plot(time_ms, d[lo:hi], color="#303d52", lw=1.5, label="Noise at ear without ANC")
    for run, c in zip(runs, colors):
        axs[0].plot(time_ms, run["e"][lo:hi], color=c, lw=1.3,
                    label=f"Residual: app latency {run['app_ms']:g} ms")
    axs[0].set(xlabel="Time in selected window (ms)", ylabel="Normalized acoustic pressure",
               title="Waveform after adaptation: cancellation occurs at the ear")
    axs[0].legend(loc="upper right", fontsize=9)
    t, base = moving_rms(d)
    axs[1].plot(t, base, color="#303d52", label="Without ANC")
    for run, c in zip(runs, colors):
        _, curve = moving_rms(run["e"])
        axs[1].plot(t, curve, color=c, label=f"With ANC, {run['app_ms']:g} ms app latency")
    axs[1].axvline(1, color="#888", ls="--", lw=1)
    axs[1].set(xlabel="Simulation time (s)", ylabel="RMS pressure (0.1 s windows)",
               title="Adaptation over time")
    axs[1].legend()
    fig.savefig(out / "02_waveform_and_learning.png")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(9, 4.6), constrained_layout=True)
    f = np.linspace(20, 1000, 800)
    for ms, c in [(0.25, "#176db5"), (1.0, "#e08b2d"), (3.0, "#cf4c4c")]:
        residual = np.maximum(2 * np.abs(np.sin(np.pi * f * ms / 1000)), 1e-3)
        ax.plot(f, -20 * np.log10(residual), color=c, label=f"Timing error {ms:g} ms")
    ax.axhline(0, color="#444", lw=0.9)
    ax.set(xlim=(20, 1000), ylim=(-10, 32), xlabel="Noise frequency (Hz)",
           ylabel="Idealized cancellation (dB)",
           title="Sensitivity to phase/timing error for a single tone")
    ax.legend()
    ax.text(0.02, 0.04, "Assumes equal antinoise amplitude; illustrative analytical curve",
            transform=ax.transAxes, fontsize=8, color="#555")
    fig.savefig(out / "03_timing_sensitivity.png")
    plt.close(fig)


def animation(out: Path, runs: list[dict], start_s: float) -> None:
    # A short moving window makes the interfering waves and boxed system readable.
    low = runs[0]
    nframes, width = 56, samples(50)
    begin = int(start_s * FS)
    fig = plt.figure(figsize=(10, 5.8), facecolor="#f6f8fc")
    gs = fig.add_gridspec(2, 1, height_ratios=[1, 2], hspace=0.32)
    top = fig.add_subplot(gs[0]); ax = fig.add_subplot(gs[1])
    top.axis("off"); top.set_xlim(0, 1); top.set_ylim(0, 1)
    items = [(0.12, "Ambient noise"), (0.37, "Phone mic + app"),
             (0.64, "Earphone output"), (0.89, "Ear: sum")]
    for pos, label in items:
        top.text(pos, 0.55, label, ha="center", va="center", fontsize=9,
                 bbox=dict(boxstyle="round,pad=0.5", fc="#e9f1ff", ec="#2464ad", lw=1.5))
    for a, b in zip(items[:-1], items[1:]):
        top.annotate("", (b[0] - 0.10, 0.55), (a[0] + 0.10, 0.55),
                     arrowprops=dict(arrowstyle="->", color="#26364d", lw=1.5))
    lines = [ax.plot([], [], lw=1.7, color=c, label=label)[0] for c, label in
             [("#303d52", "Noise at ear"), ("#e09a2d", "Antinoise at ear"),
              ("#176db5", "Residual at ear")]]
    ax.set(xlim=(0, 50), ylim=(-2.8, 2.8), xlabel="Time in moving window (ms)",
           ylabel="Normalized acoustic pressure")
    ax.legend(loc="upper right", fontsize=8)
    title = ax.set_title("")
    def update(frame: int):
        i = begin + frame * samples(8)
        j = i + width
        tt = np.arange(width) * 1000 / FS
        for line, signal in zip(lines, (low["d"], low["y"], low["e"])):
            line.set_data(tt, signal[i:j])
        title.set_text(f"Wave interference at ear | app latency {low['app_ms']:g} ms | t = {i / FS:.2f} s")
        return [*lines, title]
    ani = FuncAnimation(fig, update, frames=nframes, interval=90, blit=False)
    ani.save(out / "04_anc_animation.gif", writer=PillowWriter(fps=11))
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("results"))
    parser.add_argument("--duration", type=float, default=4.0)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--low-latency", type=float, default=2.0)
    parser.add_argument("--high-latency", type=float, default=20.0)
    args = parser.parse_args()
    if args.duration < 2.5:
        parser.error("--duration must be at least 2.5 s for learning and animation")
    args.output.mkdir(parents=True, exist_ok=True)
    style()
    x = make_noise(int(args.duration * FS), args.seed)
    runs = [simulate(x, args.low_latency), simulate(x, args.high_latency)]
    evaluation = slice(int(args.duration * 0.5 * FS), None)
    with (args.output / "metrics.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["scenario", "app_latency_ms", "primary_lead_ms", "secondary_delay_ms",
                         "noise_rms", "residual_rms", "reduction_db"])
        for run in runs:
            before, after = run["d"][evaluation], run["e"][evaluation]
            row = [f"app_{run['app_ms']:g}ms", run["app_ms"], LEAD_MS, SECONDARY_MS,
                   f"{rms(before):.6f}", f"{rms(after):.6f}", f"{reduction_db(before, after):.3f}"]
            writer.writerow(row)
            print(f"{row[0]}: {row[-1]} dB reduction (second half)")
    architecture(args.output)
    plots(args.output, x, runs, start_s=min(2.0, args.duration - 0.6))
    animation(args.output, runs, start_s=min(2.0, args.duration - 0.6))
    print(f"Saved plots, animation and metrics to {args.output.resolve()}")


if __name__ == "__main__":
    main()
