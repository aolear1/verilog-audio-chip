#!/bin/bash
# Name: run.sh
# Purpose: Compile and simulate Verilog testbench in ModelSim

# Exit on error
set -e

# Simulation name
TOP_MODULE="tb_pulse"
WORK_LIB="work"

# Clean old simulation files
rm -rf transcript vsim.wlf work audio.raw output.wav
vlib $WORK_LIB

# Compile the DUT create raw file
vlog -work $WORK_LIB ../../rtl/pulse.sv ../../tb/tb_pulse.sv
vsim -c -do "run -all; quit" $TOP_MODULE

# Convert to .WAV
echo "Converting to WAV..."
ffmpeg -f s16le -ar 48000 -ac 2 -i audio.raw output.wav
echo "Generated audio.wav"
