# Content-Aware Brightness ☀️

A native macOS utility that adjusts screen brightness based on the *content* you are looking at.
Dark Mode IDE? **Dim** the screen to save battery.
White Web Page? **Boost** brightness for readability.

## Features

*   **⚡️ Ultra Low Power:** Uses **0.24W** of power (less than a single LED).
*   **🏎️ Event-Driven:** No polling loops. Sleeps 99% of the time. Triggers only on:
    *   Application Switching
    *   Tab Switching (Cmd+T / Cmd+W)
    *   Window Title Changes
    *   Space Switching
*   **🧠 Adaptive Learning:** Use F1/F2 keys to teach it. It remembers your preferred brightness for Dark vs. Light content.
*   **👁️ Bio-Mimicry:** Dims fast (to save power/contrast) but brightens slowly (to prevent blinding you).
*   **🔋 Luma-Only Engine:** Captures raw YCbCr (Luma channel) directly from the GPU, bypassing expensive RGBA conversion.

## How it works

1.  **Event Listener:** Wait for a user action (e.g., switching to VS Code).
2.  **Luma Capture:** Instantly sample the screen center (16x16 grid) using `ScreenCaptureKit` in `NV12` format.
3.  **Analysis:** Calculate average brightness (Luma).
4.  **Adjustment:** Smoothly animate hardware brightness to your learned preference.

## Benchmarks

| Metric | Net Cost | Verdict |
|--------|----------|---------|
| **Power** | +0.24 W | ✅ Extremely Efficient |
| **CPU** | +0.5% | ✅ Negligible |

## Installation

```bash
# 1. Compile & Install
chmod +x setup.sh
./setup.sh

# 2. Grant Permission
# The app will prompt you to open System Settings -> Screen Recording.
# Enable "auto-brightness".
```
