`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2023 07:48:57 PM
// Design Name: 
// Module Name: fifo_tb
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


module fifo_tb;
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
    reg s_tvalid = 0;
    wire s_tready;
    reg [7:0] s_tdata = 0;
    always @(posedge clk) if (s_tready & s_tvalid) s_tdata <= s_tdata + 1;
    wire m_tvalid;
    reg m_tready = 0;
    wire [7:0] m_tdata;
    
    integer seed = 1;
    always @(posedge clk) begin
        if (s_tvalid == 0 || s_tready == 1) begin
            s_tvalid <= $random(seed);
        end
    end
    
    always @(posedge clk) begin
        m_tready <= $random(seed);
    end
    
    wire full;
    wire empty;
    fifo #(
        .DEPTH(10),
        .WIDTH(8)
    ) dut (
        .clk        (clk),
        .resetn     (resetn),
        .s_tvalid   (s_tvalid),
        .s_tready   (s_tready),
        .s_tdata    (s_tdata),
        .m_tvalid   (m_tvalid),
        .m_tready   (m_tready),
        .m_tdata    (m_tdata),
        .full       (full),
        .empty      (empty)
    );
endmodule
