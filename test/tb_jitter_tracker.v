`default_nettype none
`timescale 1ns / 1ps

module tb_jitter_tracker;

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg [5:0] cfg_window;
    reg [5:0] cfg_jitter_thresh;
    wire jitter_fault;

    jitter_tracker dut (
        .clk (clk),
        .rst_n (rst_n),
        .sample_valid (sample_valid),
        .cfg_window (cfg_window),
        .cfg_jitter_thresh (cfg_jitter_thresh),
        .jitter_fault (jitter_fault)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_jitter_tracker.vcd");
        $dumpvars(0, tb_jitter_tracker);
    end

    integer fail_count = 0;

    task automatic check(input expected, input integer test_id);
        if (jitter_fault !== expected) begin
            $display("FAIL test %0d: expected jitter_fault=%b got %b", test_id, expected, jitter_fault);
            fail_count++;
        end else begin
            $display("PASS test %0d", test_id);
        end
    endtask

    task automatic send_pulse(); begin
        @(posedge clk);
        sample_valid <= 1'b1;
        @(posedge clk);
        sample_valid <= 1'b0;
    end
    endtask

    task automatic send_pulse_and_check(input expected, input integer test_id); begin
        @(posedge clk);
        sample_valid <= 1'b1;
        @(posedge clk);
        // sample and check on the cycle AFTER sample_valid goes high
        // jitter_fault reflects this cycle's computation
        #1;  // tiny delay to let non-blocking assignments settle
        if (jitter_fault !== expected) begin
            $display("FAIL test %0d: expected jitter_fault=%b got %b", test_id, expected, jitter_fault);
            fail_count++;
        end else begin
            $display("PASS test %0d", test_id);
        end
        sample_valid <= 1'b0;
    end
    endtask

    task automatic wait_cycles(input integer n); begin
        repeat(n) @(posedge clk);
    end
    endtask

    // window=2 -> 2048 cycles, thresh=1 -> 1024 cycles of allowed jitter
    initial begin
    rst_n             = 0;
    sample_valid      = 0;
    cfg_window        = 6'd2;      // expected interval = 2048 cycles
    cfg_jitter_thresh = 6'd1;      // tolerance = 1024 cycles

    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // Test 1: On-time pulse, no fault
    wait_cycles(2048);
    send_pulse_and_check(1'b0, 1);

    // Test 2: Late but within threshold, no fault (500 cycles late)
    wait_cycles(2548);
    send_pulse_and_check(1'b0, 2);

    // Test 3: Late beyond threshold, fault expected (1500 cycles late)
    wait_cycles(3548);
    send_pulse_and_check(1'b1, 3);

    // Test 4: Early beyond threshold, fault expected (1500 cycles early)
    wait_cycles(548);
    send_pulse_and_check(1'b1, 4);

    // Test 5: Back on time, no fault
    wait_cycles(2048);
    send_pulse_and_check(1'b0, 5);

    // Test 6: Reset clears state
    wait_cycles(500);
    rst_n = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    check(1'b0, 6);

    // Test 7: Zero threshold, any deviation faults
    cfg_jitter_thresh = 6'd0;
    wait_cycles(2049);
    send_pulse_and_check(1'b1, 7);

    $display("-----------------------------");
    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", fail_count);
    $display("-----------------------------");
    $finish;
end

endmodule