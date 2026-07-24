# SPDX-FileCopyrightText: © 2026 Shantanu Wad
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_bist_and_ready(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 100, unit="ns")  # 10MHz
    cocotb.start_soon(clock.start())

    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1

    # cfg_window defaults to 20 in config_regs reset
    # BIST: 3 good pulses × 20480 + 1 bad pulse × 40960 + margin = ~103000 cycles
    await ClockCycles(dut.clk, 110000)

    system_ready = (int(dut.uo_out.value) >> 2) & 1
    bist_fail    = (int(dut.uo_out.value) >> 3) & 1

    dut._log.info(f"uo_out={dut.uo_out.value} system_ready={system_ready} bist_fail={bist_fail}")

    assert system_ready == 1, f"system_ready not asserted after BIST (uo_out={dut.uo_out.value})"
    assert bist_fail    == 0, f"bist_fail asserted unexpectedly (uo_out={dut.uo_out.value})"

    dut._log.info("PASS: BIST completed, system_ready asserted")