# Phone-app active noise cancellation: software simulation

## Project aim

Study whether a phone application could reduce outside sound heard through ordinary **wired earphones**, using the phone microphone as a reference and playing antinoise through the earphones. This folder is a simulation and a feasibility study, not a downloadable app or a measured claim about a real phone.

**Core finding:** Cancellation requires the antinoise to arrive at the ear at the right amplitude and phase. In the illustrative model, a reference microphone hears noise 5 ms before it reaches the ear. A 2 ms app delay plus a 1 ms earphone path leaves 2 ms for a causal controller; a 20 ms app delay misses that window. Results depend strongly on the acoustic geometry, routing delay, noise spectrum, and earphone fit.

## Files

| File | Purpose |
| --- | --- |
| `anc_simulation.py` | Runnable Python model, diagrams, plots, GIF, metrics |
| `anc_simulation.m` | Matching MATLAB model and visual outputs |
| `anc_interactive.m` | Live MATLAB slider demonstration of timing and phase |
| `interactive_preview.png` | Screenshot of the interactive MATLAB window |
| `requirements.txt` | Python packages |
| `results/01_signal_flow.png` | Labeled box diagram |
| `results/02_waveform_and_learning.png` | Noise, residual, and learning curves |
| `results/03_timing_sensitivity.png` | Idealized phase-error curve |
| `results/04_anc_animation.gif` | Animated acoustic-wave sum at the ear |
| `results/metrics.csv` | RMS and attenuation numbers |

MATLAB produces equivalent files in `matlab_results/`.

## Run

From this folder:

```powershell
python -m pip install -r requirements.txt
python anc_simulation.py --output results
```

Change the assumed delays for an experiment:

```powershell
python anc_simulation.py --low-latency 2 --high-latency 20
```

In MATLAB, open this folder and run `anc_simulation`. MATLAB R2021b or later is recommended. The script uses core MATLAB functions and no extra toolbox. To change the conditions, edit the constants at the top of the script.

For the **interactive MATLAB demonstration**, run `anc_interactive` from this folder. Drag the four sliders to change noise frequency, app delay, microphone lead, and antinoise gain. The waveform, reduction number, and frequency curve update while dragging. The time plot models one steady tone with a fixed antinoise rule; it is deliberately simpler than the adaptive broadband FxLMS simulation. It is useful for demonstrating phase and delay, not for claiming phone performance. The idealized curve can show narrow cancellation peaks for a tone even when the antinoise arrives late; that does **not** make late broadband noise causally cancellable.

## Model and equations

The sample rate is 8 kHz and the simulated signal is a 120 Hz tone mixed with correlated broadband noise. The simulation uses normalized acoustic pressure; it does not predict real sound pressure in dB SPL.

1. Reference signal at the phone microphone: `x[n]`.
2. Primary acoustic path to the ear: `d[n] = 0.85 x[n-40] + 0.15 x[n-43]` (5 ms nominal lead at 8 kHz).
3. Controller output: `u[n] = -sum(w_i x[n-i])`, with 64 adaptive coefficients.
4. App plus earphone path: `y[n] = 0.92 u[n-D] + 0.08 u[n-D-2]`, where `D = app delay + 1 ms`.
5. Remaining pressure at the ear: `e[n] = d[n] + y[n]`.
6. Filtered-x LMS changes the weights using the reference filtered through the modeled secondary path, with a normalized learning rate of 0.01.

The attenuation metric is `20 log10(RMS(d) / RMS(e))`, measured only on the second half of the simulation so that startup learning does not dominate. Positive values mean less simulated noise. Negative values mean the controller made it worse.

The timing plot is a separate *single-tone* calculation. If antinoise has equal amplitude and a timing error `Delta t`, the residual amplitude ratio is `2 |sin(pi f Delta t)|`. It is an idealized phase-sensitivity demonstration, not the measured broadband result from FxLMS.

## Representative Python result (seed 7)

| App delay | Remaining RMS | Reduction |
| --- | ---: | ---: |
| 2 ms | 0.143 | 16.58 dB |
| 20 ms | 0.589 | 4.27 dB |

The baseline noise RMS is 0.963. The 20 ms case still reduces some predictable 120 Hz noise; it performs poorly on the unpredictable broadband part. This is why one result must not be presented as a promise for all noise types.

## Feasibility and limits for a real phone

- The **5 ms microphone lead** is an optimistic assumed geometry. The phone mic must detect the relevant sound before it reaches the ear. A phone in a pocket, directional sound, and reflections may provide little lead or even the wrong reference.
- This adaptive simulation uses a **virtual error signal at the ear** to update its filter. An ordinary phone microphone does not measure pressure inside the ear. A real app without an ear microphone would need a calibrated fixed model, an estimate of ear pressure, or another way to obtain feedback. The simulation does not solve that measurement problem.
- Real input-to-output latency includes microphone capture, audio buffers, app processing, operating-system routing, output conversion, and the earphone acoustic path. It varies by device and route. Bluetooth commonly adds routing complexity; this study assumes wired earphones only.
- Earphone fit, leakage, motion, and other sounds change the acoustic paths. The model keeps them fixed. It also excludes music playback, feedback/howling, clipping, multiple noise sources, and hearing-safety controls.
- Android's `AcousticEchoCanceler` operates on the **captured microphone signal** for voice calls. It is not a ready-made function that removes external sound at the listener's ear.

Therefore a software-only **simulation** is valid for this project, while a universal app that provides AirPods-like ANC on every normal phone and earphone cannot be established by these simulated results. A future practical prototype should first measure input-to-output latency on a specific phone and wired audio route, then measure residual sound near the ear under safe sound levels.

## Suggested presentation / viva sequence

1. Show `01_signal_flow.png` and explain reference, primary, and secondary paths.
2. Show `04_anc_animation.gif`: the yellow antinoise opposes the gray noise, leaving the blue residual.
3. Show `02_waveform_and_learning.png`: compare the 2 ms and 20 ms assumed app delays.
4. Show `03_timing_sensitivity.png`: explain why phase accuracy worsens as frequency rises.
5. State the two key practical barriers: unpredictable phone routing delay and no ear-pressure feedback sensor.

## Why there is no LTspice file

LTspice models analog circuits. This project is specifically a phone software simulation with no hardware changes, so the digital acoustic/control model in Python and MATLAB is the relevant simulation. An LTspice op-amp circuit would describe a different project.

## References

- Android Developers, [Audio latency](https://developer.android.com/ndk/guides/audio/audio-latency): definitions of input, output, and round-trip latency; variation by device/build.
- Android Developers, [Low latency audio](https://developer.android.com/games/sdk/oboe/low-latency-audio): route and buffer choices for low latency and measured example variability.
- Android Developers, [AcousticEchoCanceler](https://developer.android.com/reference/android/media/audiofx/AcousticEchoCanceler): echo removal in the captured voice path.
