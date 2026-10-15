# LTspice ANC timing demonstration

Open `phone_anc_timing.asc` in LTspice and click **Run**. The saved plot settings in `phone_anc_timing.plt` display noise and antinoise in the upper pane and the remaining pressure at the ear in the lower pane. LTspice runs two steps: `AppDelay=2m` and `AppDelay=20m`.

The microphone reference contains a 100 Hz tone plus a smaller 430 Hz tone. `Cmic=1 uF` and `Rbias=33 kΩ` form a real analog high-pass input stage (cutoff about 4.8 Hz). The following behavioral blocks represent acoustic travel, an idealized inverting gain stage, the phone plus earphone delay, and the sum at the ear. **One circuit volt represents one unit of normalized acoustic pressure.** These blocks explain the timing requirement; they are not a proposed modification to phone hardware.

| Parameter | Value | Meaning |
| --- | ---: | --- |
| `Lead` | 5 ms | Sound reaches the reference mic before the ear |
| `EarDelay` | 1 ms | Modeled earphone/output acoustic path |
| `Gain` | 0.95 | Antinoise amplitude relative to microphone signal |
| `AppDelay` | 2 ms, 20 ms | Stepped phone capture/processing/output delay |
| `Wait` | `max(Lead-AppDelay-EarDelay,0)` | Extra causal wait when antinoise would arrive too early |

The `.meas` commands compare RMS noise and residual over 30–100 ms. The installed LTspice 24.1.9 run gave:

| App delay | Noise RMS | Residual RMS | Reduction |
| --- | ---: | ---: | ---: |
| 2 ms | 0.738 | 0.051 | **+23.22 dB** |
| 20 ms | 0.738 | 1.328 | **−5.11 dB** (noise amplified) |

Open `phone_anc_timing.log` to see the full measurement output. `phone_anc_timing.raw` stores the solved traces. `phone_anc_preview.png` is a presentation image made from those actual LTspice traces with `make_preview.py`.

To experiment, edit `.step param AppDelay list 2m 20m` or change `Lead`, `EarDelay`, and `Gain` on the schematic, then run it again. The exact dB result depends on the chosen tones and geometry. A late output can occasionally line up with a periodic tone, but it cannot generally cancel unpredictable broadband noise after that noise has reached the ear.
