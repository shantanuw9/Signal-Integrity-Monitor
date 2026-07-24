# SPDX-FileCopyrightText: © 2026 Shantanu Wad
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_bist_and_ready(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1

    # Log outputs every 5000 cycles to see state progression
    # FIX: Increased limit from 22 to 50 (gives simulation up to 250,000 cycles)
    for i in range(50):
        await ClockCycles(dut.clk, 5000)
        uo = int(dut.uo_out.value)
        deadline_miss = uo & 1
        jitter_fault  = (uo >> 1) & 1
        system_ready  = (uo >> 2) & 1
        bist_fail     = (uo >> 3) & 1
        dut._log.info(
            f"cycle ~{(i+1)*5000}: deadline_miss={deadline_miss} "
            f"jitter_fault={jitter_fault} "
            f"system_ready={system_ready} "
            f"bist_fail={bist_fail}"
        )
        if system_ready or bist_fail:
            break

    uo = int(dut.uo_out.value)
    system_ready = (uo >> 2) & 1
    bist_fail    = (uo >> 3) & 1

    assert system_ready == 1, f"system_ready not asserted (uo_out={dut.uo_out.value})"
    assert bist_fail    == 0, f"bist_fail asserted (uo_out={dut.uo_out.value})"
    dut._log.info("PASS")