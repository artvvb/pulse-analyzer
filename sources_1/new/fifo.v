`timescale 1ns / 1ps
`default_nettype none
module fifo #(
    parameter integer DEPTH = 1000,
    parameter integer WIDTH = 16
) (
    input  wire clk,
    input  wire resetn,
    input  wire s_tvalid,
    output wire s_tready,
    input  wire [WIDTH-1:0] s_tdata,
    output wire m_tvalid,
    input  wire m_tready,
    output wire [WIDTH-1:0] m_tdata,
    output wire full,
    output wire almost_full,
    output wire empty
);
    // simple axi4-stream fifo
    reg [$clog2(DEPTH-1)-1:0] write_addr = 0;
    reg [$clog2(DEPTH-1)-1:0] inc_write_addr;
    reg [$clog2(DEPTH-1)-1:0] inc_write_addr_next;
    reg [$clog2(DEPTH-1)-1:0] read_addr = 0;
    reg [$clog2(DEPTH-1)-1:0] inc_read_addr;
    
    wire s_beat = s_tready & s_tvalid;
    wire m_beat = m_tready & m_tvalid;
    
    reg [WIDTH-1:0] mem [DEPTH-1:0];
    
    initial begin : init_mem
        integer i;
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 0;
        end
    end
    
    always @(*) begin
        if (write_addr + 1 < DEPTH)
            inc_write_addr = write_addr + 1;
        else
            inc_write_addr = 0;
    end
    
    always @(*) begin
        if (inc_write_addr + 1 < DEPTH)
            inc_write_addr_next = inc_write_addr + 1;
        else
            inc_write_addr_next = 0;
    end
    
    always @(*) begin
        if (read_addr + 1 < DEPTH)
            inc_read_addr = read_addr + 1;
        else
            inc_read_addr = 0;
    end
    
    assign empty = (write_addr == read_addr);
    assign full = (inc_write_addr == read_addr);
    assign almost_full = (inc_write_addr_next == read_addr);
    assign s_tready = !full | m_tready;
    assign m_tvalid = !empty | s_tvalid; // pretty sure I need to register this to delay it for the read cycle that the 
    
    always @(posedge clk) begin
        if (resetn == 0) begin
             write_addr = 0;
        end else begin
            if (s_beat == 1 && (m_beat == 0 || empty == 0)) begin
                write_addr <= inc_write_addr;
                mem[write_addr] <= s_tdata;
            end
        end
    end
    
    always @(posedge clk) begin
        if (resetn == 0) begin
             read_addr = 0;
        end else begin
            if (m_beat == 1 && empty == 0)
                read_addr <= inc_read_addr;
        end
    end
    
    // mux lets the first write fall through
    assign m_tdata = (empty) ? s_tdata : mem[read_addr];
    
endmodule