`default_nettype none
`timescale 1ns / 1ps

module tb_deadline_monitor();

reg clk;
reg rst_n;
reg sample_valid;
reg [5:0] cfg_window;
wire deadline_miss;

deadline_monitor dut (
        .clk (clk),
        .rst_n (rst_n),
        .sample_valid (sample_valid),
        .cfg_window (cfg_window),
        .deadline_miss (deadline_miss)
);

initial clk = 0;
always #5 clk = -clk;

//Waveforms
initial begin
        $dumpfile("tb_deadline_monitor.vcd");
        $dumpvars(0, tb_deadline_monitor);
end

integer fail_count = 0;

task check (input expected, input [63:0] test_id)
    begin
        if (deadline_miss !== expected) begin
            $display("FAIL test %0d: expected deadline_miss=%b, got %b at time %0t",
                        test_id, expected, deadline_miss, $time);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS test %0d", test_id);
        end
    end
endtask

task send_pulse;
    begin
        @(posedge clk);         // wait for clock edge
        sample_valid <= 1'b1;   // assert for one cycle
        @(posedge clk);
        sample_valid <= 1'b0;   // deassert
    end
endtask

task wait_cycles (input integer n)
    begin
        repeat(n) begin
            @(posedge clk);
        end
    end
endtask

initial begin
    rst_n        = 0;
    sample_valid = 0;
    cfg_window   = 6'd2;
    
    
    wait_cycles(5);
    rst_n = 1;
    wait_cycles(2);

    
    // Test 1: Pulse arrives before window limit reaches
    // Expected: deadline_miss stays 0
    // window = 2048 cycles, we send pulse after 100 cycles → safe

    wait_cycles(100);
    send_pulse;
    wait_cycles(2);
    check(1'b0, 1);

    // Test 2: Pulse arrives just before window
    // Expected: no deadline_miss
    // window = 2048, send pulse at cycle 2047 → safe

    wait_cycles(2045);
    send_pulse;
    wait_cycles(2);
    check(1'b0, 2);

    // Test 3: No pulse — window expires
    // Expected: deadline_miss asserts
    // Don't send any pulse, just wait past the window

    wait_cycles(2100);      // past 2048 → should have fired
    check(1'b1, 3);

    // Test 4: After a miss, sending a pulse clears the counter and the miss should go away next cycle
    // Expected: deadline_miss goes back to 0 after pulse

    send_pulse;
    wait_cycles(2);
    check(1'b0, 4);

    // Test 5: Reset clears everything mid-count
    // Expected: no deadline_miss after reset even without pulse
    wait_cycles(100);
    rst_n = 0;
    wait_cycles(3);
    rst_n = 1;
    wait_cycles(2);
    check(1'b0, 5);

    // Test 6: Different cfg_window value works
    // Change window to 1 (= 1024 cycles), miss it

    cfg_window = 6'd1;
    wait_cycles(1100);      // past 1024 → should miss
    check(1'b1, 6);

    // --- Done ---
    $display("-----------------------------");
    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", fail_count);
    $finish;
end

endmodule