# SPDX-FileCopyrightText: © 2026 Shantanu Wad
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_bist_and_ready(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 100, units="ns")  # 10MHz
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value   = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Program cfg_window = 2 (2048 cycles) so BIST finishes fast
    # cfg_data[5:0] = 2, cfg_sel = 0, cfg_strobe = 1
    # ui_in = [cfg_strobe=1][cfg_sel=0][cfg_data=000010] = 0b10000010 = 0x82
    dut.ui_in.value = 0x82
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 0x00  # deassert strobe

    # Program cfg_jitter_thresh = 1 (1024 cycles)
    # cfg_data[5:0] = 1, cfg_sel = 1, cfg_strobe = 1
    # ui_in = [cfg_strobe=1][cfg_sel=1][cfg_data=000001] = 0b11000001 = 0xC1
    dut.ui_in.value = 0xC1
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 0x00

    # Wait for BIST to complete — 3 good pulses + 1 bad pulse at cfg_window=2
    # 3 × 2048 + 4096 + margin = ~15000 cycles
    await ClockCycles(dut.clk, 15000)

    # system_ready should be high (uo_out[2]), bist_fail should be low (uo_out[3])
    system_ready = (dut.uo_out.value >> 2) & 1
    bist_fail    = (dut.uo_out.value >> 3) & 1

    dut._log.info(f"uo_out = {dut.uo_out.value}, system_ready={system_ready}, bist_fail={bist_fail}")

    assert system_ready == 1, f"system_ready not asserted after BIST (uo_out={dut.uo_out.value})"
    assert bist_fail    == 0, f"bist_fail asserted unexpectedly (uo_out={dut.uo_out.value})"

    dut._log.info("PASS: BIST completed successfully")