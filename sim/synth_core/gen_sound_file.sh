#!/bin/bash
# Name: run.sh
# Purpose: Compile and simulate Verilog testbench in ModelSim

set -e

TOP_MODULE="tb_synth_core"
WORK_LIB="work"

RTL="../../rtl/synth_core.sv ../../rtl/noise.sv ../../rtl/pulse.sv ../../rtl/triangle_saw.sv"
TB="../../tb/tb_synth_core.sv"

# Clean old outputs, keep compilation cache
rm -f transcript vsim.wlf audio.raw output.wav

echo "Compiling sources..."
rm -rf $WORK_LIB
vlib $WORK_LIB
vlog -work $WORK_LIB $RTL $TB


# Run simulation
vsim -c -do "run -all; quit" $TOP_MODULE

# Convert to WAV
echo "Converting to WAV..."
ffmpeg -f s16le -ar 48000 -ac 2 -i audio.raw output.wav
echo "Generated output.wav"

