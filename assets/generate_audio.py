"""Render the original Azure Coast loop with only Python's standard library."""
from array import array
from math import sin, pi, exp, tanh
from pathlib import Path
from random import Random
import wave

RATE = 22050
BEAT = 60 / 152
BARS = 16
samples = array("f", [0.0]) * int(RATE * BEAT * BARS * 4)
rng = Random(1991)


def note(midi, beat, length, volume, voice="pluck"):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    start = int(beat * BEAT * RATE)
    duration = length * BEAT
    for i in range(int(duration * RATE)):
        t = i / RATE
        phase = 2 * pi * frequency * t
        release = min(1, (duration - t) * 22)
        if voice == "bass":
            signal = (sin(phase) + 0.24 * sin(phase * 2)) * min(1, t * 100) * release
        elif voice == "pad":
            signal = (sin(phase) + 0.2 * sin(phase * 1.003)) * min(1, t * 10) * release * 0.6
        else:
            signal = (sin(phase) + 0.24 * sin(phase * 2) + 0.09 * sin(phase * 3))
            signal *= exp(-t * 5.5) * min(1, t * 160) * release
        index = (start + i) % len(samples)
        samples[index] += signal * volume


def drum(beat, kind):
    start = int(beat * BEAT * RATE)
    duration = 0.20 if kind == "kick" else 0.13
    for i in range(int(duration * RATE)):
        t = i / RATE
        if kind == "kick":
            signal = sin(2 * pi * (49 * t + 8 * (1 - exp(-t * 28)))) * exp(-t * 23) * 0.30
        elif kind == "snare":
            signal = (rng.uniform(-1, 1) * 0.7 + sin(2 * pi * 185 * t) * 0.3) * exp(-t * 33) * 0.16
        else:
            signal = rng.uniform(-1, 1) * exp(-t * 90) * 0.045
        samples[(start + i) % len(samples)] += signal


# Dmaj9 → Aadd9 → Bm7 → Gmaj7; a sunny original syncopated melody.
chords = [(50, 62, 66, 69, 73), (45, 61, 64, 69, 71), (47, 62, 66, 69, 74), (43, 59, 62, 66, 69)]
melody = [78, 81, 85, 81, 78, 76, 74, 76, 78, 81, 83, 85, 83, 81, 78, 76]
for bar in range(BARS):
    root, *chord = chords[bar % 4]
    at = bar * 4
    for tone in chord:
        note(tone, at, 3.85, 0.045, "pad")
    for tick in range(8):
        note(root + (12 if tick in (3, 7) else 0), at + tick * 0.5, 0.36, 0.17, "bass")
        note(chord[tick % 4] + 12, at + tick * 0.5 + 0.25, 0.4, 0.085)
        drum(at + tick * 0.5, "hat")
    for beat in (0, 1.5, 2, 3.5):
        drum(at + beat, "kick")
    for beat in (1, 3):
        drum(at + beat, "snare")
    for j, offset in enumerate((0, 0.75, 1.5, 2.5)):
        note(melody[(bar * 4 + j) % len(melody)], at + offset, 0.63, 0.12)

pcm = array("h", (int(tanh(s * 1.2) * 25000) for s in samples))
out = Path(__file__).parent / "audio" / "coast.wav"
out.parent.mkdir(exist_ok=True)
with wave.open(str(out), "wb") as stream:
    stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
    stream.writeframes(pcm.tobytes())
print(f"Rendered {len(samples) / RATE:.2f}s of original music → {out}")
