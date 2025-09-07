# NES-Inspired Audio Synth Core

This project is fleshed out to be a modernized NES-like audio chip. Many of the design choices are made with the NES APU in mind while adding a bit (lot) more control. I am creating this project to simply add a cool space invaders shoot sound to a Space Invaders game I ported to the DE1SOC running on an M68k softcore.

The original NES APU docs are [here](https://www.nesdev.org/wiki/APU).
Credit to the Terasic starter programs (available on their website) for their `I2C_AV_Config.v` audio initialization file to set up the WM8731 audio CODEC chip.

---

## Table of Contents
- [De1-SOC Console](#console)
- [Pulse Channel](#pulse-channel)
  - [Features](#features)
  - [Register Map](#register-map)
  - [Example Configuration](#example-configuration)
- [Noise Channel](#noise-channel)
  - [Overview](#overview)
  - [Register Map](#noise-register-map)
  - [Output Modes](#output-modes)
- [Saw/Triangle Channel](#noise-channel)
  - [Overview](#overview)
  - [Register Map](#saw-triange-register-map)
- [Timing Spreadsheet](#timing-spreadsheet)
- [Usage Notes](#usage-notes)
- [Output Specification](#output-specification)
- [Planned Features](#planned-features)

---

## De1-SOC Console

This console connects a NES-style audio chip to the DE1-SoC and provides an interface for creating, storing, and playing back register profiles that drive the chip’s sound channels.

### Mode Selection
- **Button 3 (leftmost):** Switch between **Mode 0 (Edit Profiles)** and **Mode 1 (Playback)**.  
- **LED 0 (leftmost):** Indicates the current mode (off = Mode 0, on = Mode 1).

---

### Mode 0: Register/Profile Editing
- **Buttons 0 / 1:** Increment / decrement the currently selected register index.  
  - Middle two HEX displays: current register index (decimal).  
  - Leftmost HEX display: current register value for the selected profile.  
  - Rightmost two HEX displays: byte value in hex written to that register.  
- **Switches 0–7:** Set the 8-bit value to write into the selected register.  
- **Switches 8–9:** Select profile 0–2.  
  - If set to `3`, enter **Load/Store mode** to save or load profiles from on-chip memory (editable via the In-System Memory Content Editor).  
  - **Button 3** triggers the load/store operation.  
- **LEDs:** Display the last value written to the selected register.  

#### Profiles
Each profile consists of **35 registers**:  
- Registers `0–8` → Pulse channel 1  
- Registers `9–17` → Pulse channel 2  
- Registers `18–23` → Triangle channel 1  
- Registers `24–29` → Triangle channel 2  
- Registers `30–34` → Noise channel  

---

### Mode 1: Playback
- **Switches 0–4:** Toggle individual channel outputs (up = mute).  
- **Buttons 0–2:** Write profiles 0–2 to the chip for playback.  
- **Note:** Muted channels remain muted until the next profile is written *and* the channel is toggled back on.  



---

## Pulse Channel

This Verilog module implements a **pulse (square wave) generator** with full **ADSR envelope control**, **frequency sweep**, **stereo panning**, and customizable **duty cycles**, designed for retro 8-bit sound synthesis.

### Features

- Square wave output with 8 duty cycle options (12.5%–93.75%)
- Full ADSR envelope: Attack, Decay, Sustain, Release
- Stereo panning with volume control
- Frequency sweep with programmable direction, shift, and timing
- Looping and dynamic retriggering via register change or dummy bit
- WAV generation testbench for previewing sound output

### Register Map

| Reg    | Bits       | Description |
|--------|------------|-------------|
| `reg_0` | `[7]`     | Envelope Mode: `1 = ADSR`, `0 = Constant` |
|         | `[6]`     | Dummy bit — software-triggered note replay |
|         | `[5:0]`   | Constant volume or Sustain level |
| `reg_1` | `[7:0]`   | Attack time |
| `reg_2` | `[7:0]`   | Decay time |
| `reg_3` | `[1:0]`   | Sustain shift (2^x multiplier) |
|         | `[7:2]`   | Sustain time |
| `reg_4` | `[7:0]`   | Release time |
| `reg_5` | `[7:5]`   | Duty cycle index (0–7) |
|         | `[4:0]`   | Stereo pan (0=left, 31=right, 16=center) |
| `reg_6` | `[7:0]`   | Frequency timer (low byte) |
| `reg_7` | `[7:4]`   | Loop enable, Sweep enable, Sweep direction, Sweep shift |
|         | `[3:0]`   | Frequency timer (high nibble) |

---

## Noise Channel

The noise module works similarly to the pulse channel, but instead uses LFSRs to generate pseudo-random waveforms for metallic percussion or other effects. It also includes stereo panning, ADSR, and multiple noise shaping modes.

### Overview

- LFSR-based noise generation with selectable taps and lengths
- 8 output modes with different bit widths and combinations for shaping
- Full ADSR envelope control
- Panning support
- 32 frequency divider steps

### Noise Register Map

| Reg    | Bits       | Description |
|--------|------------|-------------|
| `reg_0` | `[7]`     | Envelope Mode |
|         | `[6]`     | Dummy (retrigger) |
|         | `[5:0]`   | Constant volume / Sustain |
| `reg_1` | `[7:4]`   | Attack |
|         | `[3:0]`   | Decay |
| `reg_2` | `[7:4]`   | Sustain time |
|         | `[3:0]`   | Release |
| `reg_3` | `[7:5]`   | LFSR Mode (0–7) |
|         | `[4:0]`   | Frequency divider index |
| `reg_4` | `[7]`     | Loop enable |
|         | `[6:5]`   | Loop delay index |
|         | `[4:0]`   | Stereo pan (0–31) |

### Output Modes

| Mode | Description |
|------|-------------|
| 0    | NES-style 15-bit short |
| 1    | NES-style 15-bit long |
| 2    | Scaled 15-bit to 16-bit |
| 3    | Full swing 23-bit |
| 4    | 8-bit from 23-bit LFSR |
| 5    | 12-bit from 23-bit LFSR |
| 6    | 16-bit hybrid from 15 and 23-bit |
| 7    | Chaotic XOR mode |

## Saw/Triangle Channel

This module implements a simple waveform generator capable of producing either triangle or sawtooth waves. It follows the same ADSR envelope and stereo panning model as the pulse and noise channels, making it easy to integrate in a shared audio architecture. While it currently lacks modulation or filtering enhancements, its clean analog-style shapes make it ideal for adding richness to chiptune-style audio.

### Overview

- Selectable waveform: **Triangle** or **Sawtooth**
- Full **ADSR envelope** support (Attack, Decay, Sustain, Release)
- **Stereo panning** (linear, 5-bit)
- **Retrigger** via dummy bit for live note control
- Supports **looping envelopes** with different delays
- Wide frequency range using an 11-bit programmable timer


### Saw Triangle Register Map

| Reg    | Bits       | Description |
|--------|------------|-------------|
| `reg_0` | `[7]`     | Envelope Mode |
|         | `[6]`     | Dummy (retrigger) |
|         | `[5:0]`   | Constant volume / Sustain |
| `reg_1` | `[7:4]`   | Attack |
|         | `[3:0]`   | Decay |
| `reg_2` | `[7:4]`   | Sustain time |
|         | `[3:0]`   | Release |
| `reg_3` | `[7:5]`   | Timer high 3-bits |
|         | `[4:0]`   | Stereo pan (0=left, 31=right, 16=center)|
| `reg_4` | `[7:0]`   | Timer low 8-bits |
| `reg_4` | `[7]`     | Loop enable |
|         | `[6:5]`   | Loop delay index |
|         | `[4]`     | Wave bit (1=triangle, 0=saw) |
|         | `[3:0]`   | Currently Unused|

---

## Timing Spreadsheet

A spreadsheet for tuning ADSR and LFSR values is included for envelope shaping and pitch mapping. Useful for setting your sound’s temporal response and frequency.

**Spreadsheet:** [Here](https://docs.google.com/spreadsheets/d/1Eh8U3UQXN52IiYh81gvbQNVTpkSmRxA_tjlzTd-N62A/edit?usp=sharing)

---

## Usage Notes

- Dummy bit can be toggled to retrigger notes without needing to rewrite the full register set.
- Sweep units and timers operate on different clocks; ensure timing aligns with your DAC sampling.
- The LFSR noise channel is useful for percussion or background noise effects.
- Panning is linear for now: 0 is full left, 31 is full right.

---

## Output Specification

- Outputs: 16-bit signed audio values for left and right channels
- Sample Rate: 48 kHz
- Volume scaling and panning are applied digitally
- Designed to be pipelined into a DAC or WM8731 interface

---

## Planned Features

- .NSF backwards compatibility?
