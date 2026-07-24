/*
 * Copyright (c) 2026 Shantanu Wad
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_shantanuw9 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    // unused
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // unpack inputs
    wire sample_valid_pin = ui_in[0];
    wire cfg_sel = ui_in[6];
    wire cfg_strobe = ui_in[7];
    wire [5:0] cfg_data = ui_in[5:0];

    // config registers
    wire [5:0] cfg_window;
    wire [5:0] cfg_jitter_thresh;

    config_regs cfg (
        .clk               (clk),
        .rst_n             (rst_n),
        .cfg_data          (cfg_data),
        .cfg_sel           (cfg_sel),
        .cfg_strobe        (cfg_strobe),
        .cfg_window        (cfg_window),
        .cfg_jitter_thresh (cfg_jitter_thresh)
    );

    // bist mux — swap sample source during self-test
    wire bist_active;
    wire bist_pulse;
    wire sample_valid = bist_active ? bist_pulse : sample_valid_pin;

    // submodules
    wire deadline_miss, jitter_fault, system_ready, bist_fail;

    deadline_monitor dm (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_valid (sample_valid),
        .cfg_window   (cfg_window),
        .deadline_miss(deadline_miss)
    );

    jitter_tracker jt (
        .clk               (clk),
        .rst_n             (rst_n),
        .sample_valid      (sample_valid),
        .cfg_window        (cfg_window),
        .cfg_jitter_thresh (cfg_jitter_thresh),
        .jitter_fault      (jitter_fault)
    );

    bist_controller bist (
        .clk          (clk),
        .rst_n        (rst_n),
        .cfg_window   (cfg_window),
        .deadline_miss(deadline_miss),
        .jitter_fault (jitter_fault),
        .bist_active  (bist_active),
        .bist_pulse   (bist_pulse),
        .system_ready (system_ready),
        .bist_fail    (bist_fail)
    );

    // outputs
    assign uo_out[0] = deadline_miss;
    assign uo_out[1] = jitter_fault;
    assign uo_out[2] = system_ready;
    assign uo_out[3] = bist_fail;
    assign uo_out[7:4] = 4'b0;

endmodule