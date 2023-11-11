`timescale 1ns / 1ps
`default_nettype none

module trigger_detector #(
    parameter integer WIDTH = 16
) (
    input wire clk,
    input wire resetn,
    
    input wire s_tvalid,
    output wire s_tready,
    input wire [WIDTH-1:0] s_tdata,

    input wire [WIDTH-1:0] level,

    output wire m_tvalid,
    input wire m_tready,
    output wire [WIDTH-1:0] m_tdata,
    output reg [1:0] m_tuser // trigger {falling, rising}
);
    // combinatorial-only component to keep it simple.
    wire signed [WIDTH-1:0] signed_level = level;
    wire signed [WIDTH-1:0] signed_s_tdata = s_tdata;
    
    reg signed [WIDTH-1:0] signed_last_data;
    reg last_data_valid = 0;
    
    // pass interface signals through
    assign m_tvalid = s_tvalid;
    assign s_tready = m_tready;
    assign m_tdata = s_tdata;
    
    // store last valid sample
    always @(posedge clk) begin
        if (resetn == 0) begin
            last_data_valid <= 0;
        end else if (s_tvalid == 1 && s_tready == 1) begin
            last_data_valid <= 1;
            signed_last_data <= signed_s_tdata;
        end
    end
    
    // implement level detects
    always @(*) begin
        m_tuser[0] = (signed_s_tdata >= signed_level && signed_last_data < signed_level) ? 1'b1 : 1'b0;
        m_tuser[1] = (signed_s_tdata <= signed_level && signed_last_data > signed_level) ? 1'b1 : 1'b0;
    end
endmodule