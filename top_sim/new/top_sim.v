`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2023 09:31:14 PM
// Design Name: 
// Module Name: top_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_sim;
    reg clk;
    initial begin
        clk = 0;
        #1 clk = 1;
        forever #0.5 clk = ~clk;
    end
    reg resetn = 0;
    initial begin
        @(posedge clk) resetn <= 1;
    end
    localparam integer DATA_WIDTH = 8;
    localparam integer SUM_WIDTH = 16;
    
    wire s_tvalid = 1'b1;
    wire s_tready;
    reg [DATA_WIDTH-1:0] s_tdata = 1;
    always @(posedge clk) begin
        if (s_tvalid == 1 && s_tready == 1) begin
            s_tdata <= s_tdata + 1;
        end
    end
    wire m_tvalid;
    wire [SUM_WIDTH-1:0] m_tdata;
    wire m_tready = 1'b1;
    wire stream_overflow_err;
    wire adder_err;
    
    level_trigger_integrator #(
        .PULSE_LENGTH           (20),
        .TRIGGER_POSITION       (10),
        .WIDTH                  (DATA_WIDTH),
        .SUM_WIDTH              (SUM_WIDTH)
    ) dut (
        .clk                    (clk),
        .resetn                 (resetn),
        .trigger_level          (150),
        .trigger_enable         (2'b1),
        .s_tvalid               (s_tvalid),
        .s_tready               (s_tready),
        .s_tdata                (s_tdata),
        .m_tvalid               (m_tvalid),
        .m_tready               (m_tready),
        .m_tdata                (m_tdata),
        .adder_err              (adder_err),
        .stream_overflow_err    (stream_overflow_err)
    );

endmodule
