"""Generates the focus-screen background sounds (assets/sounds/*.wav).

Synthesized noise, not recordings, so there's nothing to license. Each file
is a 20 s mono loop whose end is cross-faded into its start, so it repeats
without a click. WAV because compressed formats add a gap at every loop.

    python3 tool/make_sounds.py
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
SECONDS = 20
FADE = RATE  # 1 s cross-fade
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(7)


def white(n):
    return rng.standard_normal(n)


def brown(n):
    # Integrated white noise with a leak, so it doesn't drift.
    x = white(n)
    y = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc = 0.997 * acc + x[i] * 0.05
        y[i] = acc
    return y


def pink(n):
    # Voss-McCartney-style approximation via 1/f filtering in frequency.
    spec = np.fft.rfft(white(n))
    f = np.arange(len(spec))
    f[0] = 1
    spec /= np.sqrt(f)
    return np.fft.irfft(spec, n)


def fan(n):
    # Low-passed white noise plus a soft motor hum.
    x = white(n)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    spec *= 1 / (1 + (freqs / 500) ** 2)
    y = np.fft.irfft(spec, n)
    t = np.arange(n) / RATE
    hum = 0.15 * np.sin(2 * np.pi * 60 * t) + 0.05 * np.sin(2 * np.pi * 120 * t)
    return y / np.abs(y).max() + hum


def loop(make):
    n = RATE * SECONDS
    y = make(n + FADE)
    y = y - y.mean()
    head, tail = y[:FADE], y[n:n + FADE]
    ramp = np.linspace(0, 1, FADE)
    out = y[:n].copy()
    out[:FADE] = head * ramp + tail * (1 - ramp)
    out /= np.abs(out).max()
    return (out * 0.5 * 32767).astype("<i2")


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(samples.tobytes())


if __name__ == "__main__":
    write("brown", loop(brown))
    write("rain", loop(pink))
    write("fan", loop(fan))
    for p in sorted(OUT.glob("*.wav")):
        print(p.name, p.stat().st_size // 1024, "KB")
