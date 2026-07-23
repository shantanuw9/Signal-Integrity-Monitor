`default_nettype none

module config_regs (
    input wire clk,
    input wire rst_n,
    input wire [5:0] cfg_data, // ui_in[5:0]
    input wire cfg_sel, // ui_in[6]
    input wire cfg_strobe, // ui_in[7]
    output reg [5:0] cfg_window,
    output reg [5:0] cfg_jitter_thresh
);

always @(posedge clk) begin
    if(!rst_n) begin
        cfg_window <= 6'd20;
        cfg_jitter_thresh <= 6'd5;
    end else if (cfg_strobe) begin
        if (!cfg_sel)
            cfg_window <= cfg_data;
        else
            cfg_jitter_thresh <= cfg_data;
    end
end

endmodule
