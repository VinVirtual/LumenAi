#!/usr/bin/env python3
"""Generate a 25-second pleasant alarm bell tone as a 16-bit PCM WAV.

The tone is a struck bell modeled as a sum of harmonics with exponential
decay; we re-strike every 1.0s so the listener never hits "dead silence"
during the loop. Output is mono, 44.1 kHz, 16-bit signed PCM. Once written,
afconvert turns it into the .caf container iOS expects for custom
notification sounds.
"""
import math
import struct
import wave
import sys
from pathlib import Path

SAMPLE_RATE = 44_100
DURATION_S = 25.0
STRIKE_INTERVAL_S = 1.0
PARTIALS = [
    # (frequency Hz, amplitude, decay seconds)
    (880.0, 0.50, 0.9),     # fundamental A5
    (1320.0, 0.30, 0.7),    # perfect fifth
    (1760.0, 0.20, 0.5),    # octave
    (2640.0, 0.10, 0.3),    # 12th overtone
]


def render():
    n_samples = int(SAMPLE_RATE * DURATION_S)
    samples = [0.0] * n_samples
    strike_count = int(DURATION_S / STRIKE_INTERVAL_S)
    for s in range(strike_count):
        start = int(s * STRIKE_INTERVAL_S * SAMPLE_RATE)
        for i in range(int(SAMPLE_RATE * STRIKE_INTERVAL_S * 1.2)):
            idx = start + i
            if idx >= n_samples:
                break
            t = i / SAMPLE_RATE
            v = 0.0
            for freq, amp, decay in PARTIALS:
                v += amp * math.sin(2 * math.pi * freq * t) * math.exp(-t / decay)
            samples[idx] += v
    peak = max(abs(v) for v in samples) or 1.0
    scale = 0.85 / peak
    return [int(max(-32768, min(32767, round(v * scale * 32767)))) for v in samples]


def main():
    out_wav = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("lumen-alarm.wav")
    samples = render()
    with wave.open(str(out_wav), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
    print(f"wrote {out_wav} ({len(samples) / SAMPLE_RATE:.1f}s)")


if __name__ == "__main__":
    main()
