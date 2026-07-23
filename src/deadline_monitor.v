`default_nettype none

module deadline_monitor (
    input wire clk,
    input wire rst_n,
    input wire sample_valid,
    input wire [5:0] cfg_window,
    output reg deadline_miss
);

reg [15:0] counter; // internal counter adjusted for 10 extra bits due to clock size

always @(posedge clk) begin
    deadline_miss <= 1'b0;
    if(!rst_n) begin
        counter <= 16'd0;
    end else if(sample_valid) begin
        counter <= 16'd0;
    end else begin
        counter <= counter + 1'b1;
        if(counter > {cfg_window, 10'b0}) begin //base case of counter
            deadline_miss <= 1'b1;
        end
    end

end

endmodule
