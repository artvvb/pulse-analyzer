`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Digilent Inc
// Engineer: Arthur Brown
// 
// Create Date: 11/08/2023 05:27:54 PM
// Module Name: axis_frame_summer
// Target Devices: Eclypse Z7 
// Tool Versions: Vivado 2023.1
// Description: accepts axi4-stream frames terminated by tlast beats,
//              sums all data beats as they come in, and emits that
//              sum on an additional axi4-stream interface
// 
// Dependencies: None 
// 
// Revision:
// Revision 0.01 - File Created
//
//////////////////////////////////////////////////////////////////////////////////


module axis_frame_summer #(
    integer DATA_WIDTH = 16,
    integer SUM_WIDTH = 32,
    integer MAX_LENGTH = 1000
) (
    input wire clk,
    input wire resetn,
    
    // s interface accepts data beats
    // output data register is sized based on MAX_LENGTH, so that any frame with equal or less data beats in it can be summed into that register.
    output wire s_tready,
    input wire s_tvalid,
    input wire [DATA_WIDTH-1:0] s_tdata,
    input wire s_tlast,
    
    // m interface sends one beat for each packet received, after tlast is asserted
    // data is the sum of all data beats in the received packet.
    //does m_tdata size need adjusted for signed ints?
    input wire m_tready,
    output reg m_tvalid,
    output reg [SUM_WIDTH-1:0] m_tdata,
    
    output reg adder_err, // assert if the sum register rolls over; could indicate that the s packet was too long
    output reg stream_overflow_err // assert if m_tvalid is still asserted with no transfer when s_tlast is received - indicates a pipeline stall, reset required to clear.
);
    reg signed [SUM_WIDTH-1:0] signed_data;
    reg signed [SUM_WIDTH-1:0] accumulated_sum;
    reg signed [SUM_WIDTH-1:0] next_sum;
    
    wire next_sum_sign = next_sum[SUM_WIDTH-1];
    wire accumulated_sum_sign = accumulated_sum[SUM_WIDTH-1];
    wire signed_data_sign = signed_data[SUM_WIDTH-1];
    
    // hold high and use error bits to indicate if there's an issue. this generally assumes that we don't need to worry about much backpressure from the M interface
    assign s_tready = 1;
    
     // sign extend s_tdata
    always @(*) signed_data = {{SUM_WIDTH-DATA_WIDTH{s_tdata[DATA_WIDTH-1]}}, s_tdata};
    
    always @(*) next_sum <= accumulated_sum + signed_data;

    always @(posedge clk) begin
        if (resetn == 0) begin
            accumulated_sum <= 'b0;
        end else if (s_tvalid == 1 && s_tready == 1) begin
            if (s_tlast == 1) begin
                accumulated_sum <= 'b0; // clear in preparation for the next packet
            end else begin
                accumulated_sum <= next_sum;
            end
        end
    end
    
    always @(posedge clk) begin
        if (resetn == 0) begin
            m_tvalid <= 'b0;
        end else if (m_tready == 1 || m_tvalid == 0) begin
            // reduction of "(m_tvalid == 1 && m_tready == 1) || (m_tvalid == 0)"
            // if the M data reg is empty, see if it needs filled.
            // if the M data reg is full, see if it's ready to send, if it is, see if there's another piece of data ready to go
            if (s_tready == 1 && s_tvalid == 1 && s_tlast == 1) begin
                m_tvalid <= 'b1;
            end else begin
                m_tvalid <= 'b0;
            end
        end
    end
    
    always @(posedge clk) begin
        if (resetn == 0) begin
            m_tdata <= 'b0;
        end else if (m_tready == 1 || m_tvalid == 0) begin
            // if the M data reg is empty, see if it needs filled.
            // if the M data reg is full, see if it's ready to send, if it is, see if there's another piece of data ready to go
            if (s_tready == 1 && s_tvalid == 1 && s_tlast == 1) begin
                m_tdata <= next_sum; // take next sum here instead of registered accumulated sum to make sure the last piece of data is added in 
            end
        end
    end
    
    always @(posedge clk) begin
        if (resetn == 0) begin
            adder_err <= 0;
        end else if (signed_data_sign == accumulated_sum_sign && signed_data_sign != next_sum_sign) begin
            // error if adding two numbers with the same sign bit produces a number with a different sign bit, indicates rollover
            adder_err <= 1;
        end
    end
    
    always @(posedge clk) begin
        if (resetn == 0) begin
            stream_overflow_err <= 0;
        end else if (s_tready == 1 && s_tvalid == 1 && s_tlast == 1 && m_tready == 0 && m_tvalid == 1) begin
            // error if data is ready to go but the M interface isn't prepared to register it
            stream_overflow_err <= 1;
        end
    end
endmodule
