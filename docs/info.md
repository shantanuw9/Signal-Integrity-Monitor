## How it works

The Sensor Integrity Monitor is a hardware watchdog designed for periodic sensor pipelines, specifically systems that expect data to arrive at a fixed interval, such as a 50Hz IMU sampling over I²C. It was motivated by ClimbWright, a climbing wristband that samples orientation data at 50Hz.

The design consists of four modules:

**config_regs** accepts a time-multiplexed 8-bit input bus carrying two programmable parameters: the expected sample window (`cfg_window`) and the jitter tolerance threshold (`cfg_jitter_thresh`). Both are 6-bit values scaled internally by 1024 clock cycles. A strobe-and-select protocol (`cfg_strobe`, `cfg_sel`) latches each value independently into registers that persist during operation.

**deadline_monitor** counts clock ticks between `sample_valid` pulses. If the counter exceeds the programmed window before the next pulse arrives, `deadline_miss` is asserted for one clock cycle. The counter resets on every valid pulse.

**jitter_tracker** measures the absolute deviation between the actual sample interval and the expected window on every pulse arrival. If the deviation exceeds the programmed threshold, `jitter_fault` is asserted for one clock cycle. It catches both early and late arrivals symmetrically.

**bist_controller** runs a Built-In Self-Test on startup before releasing `system_ready`. It first injects synthetic pulses at the correct interval through the monitoring pipeline, verifying that no false faults fire. It then deliberately injects a late pulse and verifies that `deadline_miss` fires correctly. Only if both checks pass does it assert `system_ready`. If either check fails, `bist_fail` is asserted instead. This pattern is used in production ASICs to validate monitoring logic without external test equipment.

During BIST, `bist_active` is high and the internal mux routes synthetic pulses from `bist_controller` into both `deadline_monitor` and `jitter_tracker` instead of the external `sample_valid` pin. Once `system_ready` asserts, the mux switches to the live input and normal operation begins.

At the default 10MHz clock, `cfg_window = 20` corresponds to an expected sample interval of 20,480 clock cycles (~2ms, 500Hz). For ClimbWright's 50Hz IMU, `cfg_window = 195` targets a ~20ms interval.

## How to test

**On reset:** BIST runs automatically. Monitor `system_ready` (uo[2]) — it goes high once self-test passes. If `bist_fail` (uo[3]) asserts instead, the monitoring logic failed self-verification. With default `cfg_window = 20`, BIST completes in approximately 82,000 clock cycles (~8ms at 10MHz).

**Programming the config registers:**

To set `cfg_window`:
- Place the desired 6-bit value on `ui_in[5:0]`
- Set `ui_in[6]` (cfg_sel) = 0
- Pulse `ui_in[7]` (cfg_strobe) high for one cycle

To set `cfg_jitter_thresh`:
- Same procedure with `ui_in[6]` (cfg_sel) = 1

**In live mode** (after `system_ready`):
- Assert `ui_in[0]` (sample_valid) high for one cycle each time a sensor sample arrives
- Monitor `uo[0]` (deadline_miss) for late or missing samples
- Monitor `uo[1]` (jitter_fault) for samples arriving outside the jitter tolerance

**Timing scale factor:** both `cfg_window` and `cfg_jitter_thresh` are multiplied by 1024 internally. `cfg_window = 1` means an expected interval of 1024 clock cycles.

## External hardware

No external hardware required for basic operation. For integration with a real sensor pipeline, connect the microcontroller's sample-ready interrupt or DMA transfer-complete signal to `ui_in[0]` (sample_valid). `deadline_miss` and `jitter_fault` can be routed to MCU GPIO interrupt pins for real-time fault handling.
