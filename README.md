![GDS](../../workflows/gds/badge.svg)
![Docs](../../workflows/docs/badge.svg)
![Test](../../workflows/test/badge.svg)

# Real-Time Sensor Integrity Monitor

A hardware watchdog and timing verification engine designed for 
sensor pipelines, implemented in Verilog and taped out on SkyWater SKY130 
130nm.

## Overview

Embedded systems that sample sensors at fixed intervals (e.g., 50Hz IMU 
data over I²C) typically rely on firmware to assume samples arrive on time. 
This chip verifies that sampling accurately
with zero firmware backup, and flags violations in real time.

Motivated by ClimbWright, a sensor-powered 
climbing wristband that samples IMU data at 50Hz. Degraded sample timing 
causes orientation estimation drift. This chip catches that failure in the hardware without any firmware dependency.

## Architecture

![Block Diagram](docs/block_diagram.png)

The design consists of four modules:

**`config_regs`** — Accepts an 8-bit time-multiplexed input bus carrying 
two programmable parameters: the expected sample window and the jitter 
tolerance threshold. A strobe-and-select protocol latches each value 
independently.

**`deadline_monitor`** — Counts clock ticks between `sample_valid` pulses. 
If the counter exceeds the programmed window (in units of 1024 clock cycles) 
before the next pulse arrives, `deadline_miss` is asserted for one cycle.

**`jitter_tracker`** — Measures the absolute deviation between the actual 
sample interval and the expected window. If deviation exceeds the programmed 
threshold, `jitter_fault` is asserted. Detects both early and late arrivals.

**`bist_controller`** — Runs a Built-In Self-Test on startup before releasing 
`system_ready`. Injects synthetic pulses at the correct interval (verifying 
no false faults), then injects a deliberately late pulse (verifying 
`deadline_miss` fires correctly). Only asserts `system_ready` if both checks 
pass. This is the pattern used in production ASICs to verify monitoring logic 
without external test equipment.

## Pinout

| Pin | Direction | Signal | Description |
|-----|-----------|--------|-------------|
| ui[0] | Input | sample_valid / cfg_data[0] | Sensor sample strobe (live mode) / config data bit 0 |
| ui[1] | Input | cfg_data[1] | Config data bit 1 |
| ui[2] | Input | cfg_data[2] | Config data bit 2 |
| ui[3] | Input | cfg_data[3] | Config data bit 3 |
| ui[4] | Input | cfg_data[4] | Config data bit 4 |
| ui[5] | Input | cfg_data[5] | Config data bit 5 |
| ui[6] | Input | cfg_sel | 0 = write cfg_window, 1 = write cfg_jitter_thresh |
| ui[7] | Input | cfg_strobe | Rising edge latches cfg_data into selected register |
| uo[0] | Output | deadline_miss | High for one cycle when sample arrives late |
| uo[1] | Output | jitter_fault | High for one cycle when jitter exceeds threshold |
| uo[2] | Output | system_ready | High after BIST passes; low during self-test |
| uo[3] | Output | bist_fail | High if BIST detects a monitoring logic fault |

## Timing Configuration

The expected sample interval and jitter threshold are each programmed as 
6-bit values scaled by 1024 clock cycles internally.

At the default 10MHz clock:
- `cfg_window = 20` → expected interval of 20 × 1024 = 20,480 cycles = ~2ms (500Hz)
- `cfg_window = 195` → ~20ms (50Hz, matching ClimbWright's IMU sample rate)
- `cfg_jitter_thresh = 1` → ±1024 cycles (~0.1ms) of tolerated jitter

## How to Test

On reset, the chip runs BIST automatically. Monitor `system_ready` — it goes 
high once self-test passes (typically within a few hundred clock cycles 
depending on `cfg_window`). If `bist_fail` asserts instead, the monitoring 
logic failed self-verification.

In live mode (after `system_ready`):

1. Program `cfg_window` by holding `cfg_data[5:0]` at the desired value, 
   asserting `cfg_sel=0`, and pulsing `cfg_strobe` high for one cycle.
2. Program `cfg_jitter_thresh` the same way with `cfg_sel=1`.
3. Assert `sample_valid` high for one cycle each time a sensor sample arrives.
4. Monitor `deadline_miss` and `jitter_fault` for timing violations.

## Simulation

Testbenches for each module are in `test/`. Run locally with:

```bash
cd test
iverilog -o sim.vvp tb_deadline_monitor.v ../src/deadline_monitor.v && vvp sim.vvp
iverilog -o sim.vvp tb_jitter_tracker.v ../src/jitter_tracker.v && vvp sim.vvp
iverilog -o sim.vvp tb_bist_controller.v ../src/bist_controller.v && vvp sim.vvp
```

![Simulation Waveform](docs/waveform.png)

## Resources

- [TinyTapeout](https://tinytapeout.com)
- [LibreLane](https://www.zerotoasiccourse.com/terminology/librelane/)
- [SKY130 PDK](https://github.com/google/skywater-pdk)
