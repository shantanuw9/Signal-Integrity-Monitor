`default_nettype none

module bist_controller (
    input wire clk,
    input wire rst_n,
    input wire [5:0] cfg_window,
    input wire deadline_miss,
    input wire jitter_fault,
    output reg bist_active,
    output reg bist_pulse,
    output reg system_ready,
    output reg bist_fail
);

localparam INJECT_GOOD = 2'd0;
localparam INJECT_BAD = 2'd1;
localparam VERIFY = 2'd2;
localparam DONE = 2'd3;

reg [15:0] counter;
reg good_clean;
reg bad_triggered;
reg [1:0] state;
reg [1:0] pulse_count;
reg pulse_bad_count;

always @(posedge clk) begin
        bist_pulse <= 1'b0;
        if (!rst_n) begin
            state <= INJECT_GOOD;
            counter <= 16'b0;
            pulse_count <= 2'b0;
            pulse_bad_count <= 1'b0;
            good_clean <= 1'b1;
            bad_triggered <= 1'b0;
            bist_active <= 1'b1;
            bist_pulse <= 1'b0;
            system_ready <= 1'b0;
            bist_fail <= 1'b0;
        end else begin
            case (state)
                INJECT_GOOD: begin
                    if(deadline_miss || jitter_fault) begin
                        good_clean <= 0;
                    end
                    if(counter > {cfg_window, 10'b0}) begin
                        bist_pulse <= 1'b1;
                        counter <= 16'b0;
                        pulse_count <= pulse_count + 1'b1;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                    state <= pulse_count > 2'd2 ? INJECT_BAD : INJECT_GOOD;
                end
                INJECT_BAD: begin
                    if(deadline_miss) begin
                        bad_triggered <= 1'b1;
                    end
                    if(counter > {cfg_window, 10'b0} << 1) begin
                        bist_pulse <= 1'b1;
                        counter <= 16'b0;
                        pulse_bad_count <= 1'b1;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                    state <= pulse_bad_count ? VERIFY : INJECT_BAD;
                end
                VERIFY: begin
                    if(good_clean && bad_triggered) begin
                        system_ready <= 1'b1;
                    end else begin
                        bist_fail <= 1'b1;
                    end
                    state <= DONE;
                end
                DONE: begin
                    bist_active <= 1'b0;
                end
            endcase
        end
    end


endmodule