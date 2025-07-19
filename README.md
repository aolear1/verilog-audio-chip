# Project Description
This project is fleshed out to be a modernized NES-like audio chip. Many of the design choices are made with the NES APU in mind while adding a bit (lot) more control. I am creating this project to simply add a cool space invaders shoot sound to a space invaders game I ported to the DE1SOC running on a M68k softcore. 

The original NES APU docs are [here](https://www.nesdev.org/wiki/APU). Credit to the Terasic starter programs that can be found on their website for their `I2C_AV_Config.v` audio initialization file to set up the WM8731 audio CODEC chip .
# Pulse Channel – Verilog Audio Synth Core

This module implements a **pulse (square wave) generator** with full **ADSR envelope control**, **frequency sweep**, **stereo panning**, and customizable **duty cycles**, designed for retro 8-bit sound synthesis. It's intended as part of a larger audio chip project.

The module operates on multiple clock domains (50 MHz system, 8 kHz envelope timing, 48 kHz audio output), and supports register-triggered retriggering. A dummy bit is available for software-controlled note replay. Frequency sweep logic and looping sustain/release envelopes are also implemented.

---

## Features

- Square wave output with 8 duty cycle options (12.5%–93.75%)
- Full ADSR Envelope: Attack, Decay, Sustain, and Release stages
- Volume-controlled stereo panning
- Frequency sweep with programmable shift, period, direction, and enable
- Looping capability with configurable loop counter
- Dynamic retriggering on register change or dummy bit write
- Testing script to run the associated test bench and generate a .wav preveiw of the sound output with chosen settings

---

## Register Map

| Reg | Bits     | Description |
|------|----------|-------------|
| `reg_0` | `[7]`     | Envelope Mode: `1 = ADSR`, `0 = Constant` |
|        | `[6]`     | Dummy bit — software-triggered note replay |
|        | `[5:0]`   | Constant volume or Sustain level (if ADSR) |
| `reg_1` | `[7:0]`   | Attack time |
| `reg_2` | `[7:0]`   | Decay time |
| `reg_3` | `[1:0]`   | Sustain shift (multiplies sustain time by `2^x`) |
|        | `[7:2]`   | Sustain time |
| `reg_4` | `[7:0]`   | Release time |
| `reg_5` | `[7:5]`   | Duty cycle index (0–7) |
|        | `[4:0]`   | Stereo pan (0 = hard left, 31 = hard right, 16 = center) |
| `reg_6` | `[7:0]`   | Frequency timer (low 8 bits) |
| `reg_7` | `[7:4]`   | Loop counter (repeats envelope sequence) |
|        | `[3]`     | Reset sweep freq on loop (1 = yes) |
|        | `[2:0]`   | Frequency timer (high 3 bits) |
| `reg_8` | `[7]`     | Sweep enable |
|        | `[6]`     | Sweep negate (1 = decrease frequency) |
|        | `[5:3]`   | Sweep shift amount |
|        | `[2:0]`   | Sweep period (in 8 kHz ticks) |

---

## Excel Timing Spreadsheet

A companion Excel spreadsheet is provided to help with design and tuning. It contains:

- ADSR envelope calculators
- Frequency timer lookup tables (musical note mapping)
- Sweep timing and frequency calculations based on shift, period, and direction

**Spreadsheet:** [Here](https://docs.google.com/spreadsheets/d/1Eh8U3UQXN52IiYh81gvbQNVTpkSmRxA_tjlzTd-N62A/edit?usp=sharing)

---

## Usage Notes

- Envelope is retriggered upon any change to an envelope related register.
- Sweep is retriggered on any register change, as well as on ADSR loops if the flag is enabled (will reset frequency to original frequency set by timer value)
- To replay a sound, toggle the dummy bit (`reg_0[6]`) or make a small change to any envelope parameter.
- The duty cycle sets the harmonic profile (timbre) using a 16-step pattern.
- If the frequency becomes invalid (<10 or >1023), the channel mutes automatically.
- The output signal is scaled by both the envelope and stereo pan.

---

## Output Specification

- Stereo 16-bit signed PCM output
- Output sample rate: 48 kHz
- Panning is linear: 0 (left) to 31 (right), 16 is dead center

---

## Example Configuration

This example sets up a basic tone with fast attack, moderate decay, short sustain, and soft release:

```verilog
reg_0 = 8'b10100000; // ADSR enabled, sustain level 32
reg_1 = 8'd10;        // Attack time = 88 ms
reg_2 = 8'd10;        // Decay time = 44 ms
reg_3 = 8'b01010000; // Sustain time = 84 ms (with no shift)
reg_4 = 8'd16;       // Release time = 68 ms
reg_5 = 8'b01100000; // 50% duty cycle, center panned
reg_6 = 8'hFF;       // Timer low
reg_7 = 8'b00000001; // Timer high + no loop
reg_8 = 8'b00000000; // No sweep
```

---

## Planned Features

- Integration with triangle and noise channels for the full NES-like chip
- Support for modulation and LFOs
- Altera MM integration and addressable chip
