`default_nettype none
`timescale 1ns / 1ps

module tb_bist_controller;

    reg clk;
    reg rst_n;
    reg [5:0] cfg_window;
    reg deadline_miss;
    reg jitter_fault;
    wire bist_active;
    wire bist_pulse;
    wire system_ready;
    wire bist_fail;

    bist_controller dut (
        .clk (clk),
        .rst_n (rst_n),
        .cfg_window (cfg_window),
        .deadline_miss(deadline_miss),
        .jitter_fault (jitter_fault),
        .bist_active (bist_active),
        .bist_pulse (bist_pulse),
        .system_ready (system_ready),
        .bist_fail (bist_fail)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_bist_controller.vcd");
        $dumpvars(0, tb_bist_controller);
    end

    integer fail_count = 0;

    task automatic check(input expected_ready, input expected_fail, input integer test_id); begin
        if (system_ready !== expected_ready || bist_fail !== expected_fail) begin
            $display("FAIL test %0d: expected ready=%b fail=%b got ready=%b fail=%b",
                     test_id, expected_ready, expected_fail, system_ready, bist_fail);
            fail_count++;
        end else begin
            $display("PASS test %0d", test_id);
        end
    end
    endtask

    task automatic wait_cycles(input integer n); begin
        repeat(n) @(posedge clk);
    end
    endtask

    // window=2 → 2048 cycles per pulse interval
    task automatic run_bist_good(); begin
        deadline_miss = 0;
        jitter_fault  = 0;
    end
    endtask

    task automatic run_bist_bad(); begin
        // Drive deadline_miss=1 one cycle after bist_pulse fires
        // representing monitor correctly catching a late pulse
        @(posedge bist_pulse);
        @(posedge clk);
        deadline_miss = 1;
        @(posedge clk);
        deadline_miss = 0;
    end
    endtask

    initial begin
    rst_n         = 0;
    cfg_window    = 6'd2;
    deadline_miss = 0;
    jitter_fault  = 0;

    repeat(5) @(posedge clk);
    rst_n = 1;

    // Test 1: Healthy BIST — assert deadline_miss during INJECT_BAD window
    // 3 good pulses × ~2048 cycles = ~6144 cycles before INJECT_BAD starts
    wait_cycles(7000);       // now inside INJECT_BAD
    deadline_miss = 1;
    repeat(2) @(posedge clk);
    deadline_miss = 0;

    wait_cycles(12000);      // wait for VERIFY and DONE
    if (system_ready !== 1'b1 || bist_fail !== 1'b0) begin
        $display("FAIL test 1: expected ready=1 fail=0 got ready=%b fail=%b",
                 system_ready, bist_fail);
        fail_count++;
    end else begin
        $display("PASS test 1");
    end

    // Test 2: Spurious fault during INJECT_GOOD causes bist_fail
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;

    wait_cycles(100);
    deadline_miss = 1;       // spurious fault early in INJECT_GOOD
    repeat(2) @(posedge clk);
    deadline_miss = 0;

    wait_cycles(20000);
    if (system_ready !== 1'b0 || bist_fail !== 1'b1) begin
        $display("FAIL test 2: expected ready=0 fail=1 got ready=%b fail=%b",
                 system_ready, bist_fail);
        fail_count++;
    end else begin
        $display("PASS test 2");
    end

    $display("-----------------------------");
    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", fail_count);
    $display("-----------------------------");
    $finish;
end

endmodule