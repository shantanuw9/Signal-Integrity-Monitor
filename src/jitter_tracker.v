`default_nettype none

module jitter_tracker (
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire [5:0] cfg_window,
    input wire [5:0] cfg_jitter_thresh,
    output reg jitter_fault
);

reg [15:0] counter;
wire [15:0] expected;
wire [15:0] delta;

assign expected = {cfg_window, 10'b0};
assign delta = (expected > counter) ? expected - counter : counter - expected;

always @(posedge clk) begin
    jitter_fault <= 1'b0;
    if (!rst_n) begin
        counter <= 16'b0;
    end else if (sample_valid) begin
        if (counter > expected) begin
            if (counter - expected > {cfg_jitter_thresh, 10'b0})
                jitter_fault <= 1'b1;
        end else begin
            if (expected - counter > {cfg_jitter_thresh, 10'b0})
                jitter_fault <= 1'b1;
        end
        counter <= 16'b0;
    end else begin
        counter <= counter + 1'b1;
    end
end

endmodule