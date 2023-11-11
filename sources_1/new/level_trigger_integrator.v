`timescale 1ns / 1ps
`default_nettype none

// take an incoming stream of data,
// wait for one sample to hit a trigger level,
// then sum the samples around it,
// and emit that sum as one sample on the output interface. 

module level_trigger_integrator #(
    parameter integer PULSE_LENGTH = 1000,
    parameter integer TRIGGER_POSITION = 100,
    parameter integer WIDTH = 16,
    parameter integer SUM_WIDTH = 32
) (
    input wire clk,
    input wire resetn,

    input wire [WIDTH-1:0] trigger_level,
    input wire [1:0] trigger_enable,

    input wire s_tvalid,
    output wire s_tready,
    input wire [WIDTH-1:0] s_tdata,

    output wire m_tvalid,
    input wire m_tready,
    output wire [SUM_WIDTH-1:0] m_tdata,
    
    output wire adder_err,
    output wire stream_overflow_err
);
    // top module
    
    // state machine
    localparam STATE_PREBUFFER = 0; // prebuffer data in fifo until it's full
    localparam STATE_DISCARD = 1; // waiting for trigger, discard oldest data in full fifo
    localparam STATE_SUM = 2; // continue streaming data into the fifo, pass data coming out into the accumulator, count beats passing into the accumulator until PULSE_LENGTH have been passed. 
    reg [1:0] state = 0;
    wire trigger;
    wire sum_done;
    wire prebuffer_full;
    
    always @(posedge clk) begin
        if (resetn == 0) begin
            state <= 0;
        end else case (state)
            STATE_PREBUFFER: if (prebuffer_full) state <= STATE_DISCARD;
            STATE_DISCARD: if (trigger) state <= STATE_SUM;
            STATE_SUM: if (sum_done) state <= STATE_DISCARD;
        endcase
    end
    
    // generate triggers
    wire td_m_tvalid;
    wire td_m_tready;
    wire [WIDTH-1:0] td_m_tdata;
    wire [1:0] td_m_tuser;
    trigger_detector #(
        .WIDTH    (WIDTH)
    ) trigger_inst (
        .clk      (clk),
        .resetn   (resetn),
        .s_tvalid (s_tvalid),
        .s_tready (s_tready),
        .s_tdata  (s_tdata),
        .level    (trigger_level),
        .m_tvalid (td_m_tvalid),
        .m_tready (td_m_tready),
        .m_tdata  (td_m_tdata),
        .m_tuser  (td_m_tuser)
    );
    
    assign trigger = |(td_m_tuser & trigger_enable);
    
    // fifo buffers data so that the trigger position doesn't have to be at the front of the sum frame
    wire fifo_m_tvalid;
    wire fifo_m_tready;
    wire [WIDTH-1:0] fifo_m_tdata;
    wire fifo_full;
    fifo #(
        .DEPTH (TRIGGER_POSITION + 2), // +2 accounts for trigger detect pipeline latency, 1 cycle for trigger register, 1 cycle for state register, two extra fifo slots delays data output by two cycles
        .WIDTH (WIDTH)
    ) fifo_inst (
        .clk         (clk),
        .resetn      (resetn),
        .s_tvalid    (td_m_tvalid),
        .s_tready    (td_m_tready),
        .s_tdata     (td_m_tdata),
        .m_tvalid    (fifo_m_tvalid),
        .m_tready    (fifo_m_tready),
        .m_tdata     (fifo_m_tdata),
        .full        (),
        .almost_full (fifo_full), // use almost full instead of full since by the time the state machine register has time to react to this signal, the fifo will be full
        .empty       ()
    );
    
    assign prebuffer_full = fifo_full;
    
    // discard data or route to accumulator/summer, assert tlast based on counter
    reg router_s_tready;
    wire router_s_tvalid = fifo_m_tvalid;
    wire [WIDTH-1:0] router_s_tdata = fifo_m_tdata;
    reg router_m_tvalid;
    wire router_m_tready;
    wire [WIDTH-1:0] router_m_tdata;
    wire router_m_tlast;
    reg [$clog2(PULSE_LENGTH-1)-1:0] router_last_count = 'b0;
    always @(posedge clk) begin
        if (resetn == 0) begin
            router_last_count <= 'b0;
        end else if (state == STATE_SUM) begin
            if (router_last_count + 1 == PULSE_LENGTH)
                router_last_count <= 'b0;
            else          
                router_last_count <= router_last_count + 1;
        end else begin
            router_last_count <= 'b0;
        end
    end
    
    assign sum_done = router_m_tlast;
    assign fifo_m_tready = router_s_tready; // LATCH implies there's a loop. remove it by inserting a register?
    assign router_m_tdata = router_s_tdata;
    assign router_m_tlast = (router_last_count + 1 == PULSE_LENGTH);
    
    always @(*) begin
        if (state == STATE_PREBUFFER) begin
            router_s_tready = 0;
            router_m_tvalid = 0;
        end else if (state == STATE_DISCARD) begin
            router_s_tready = 1;
            router_m_tvalid = 0;
        end else if (state == STATE_SUM) begin
            router_s_tready = router_m_tready;
            router_m_tvalid = router_s_tvalid;
        end else begin // invalid state
            router_s_tready = 0;
            router_m_tvalid = 0;
        end
    end
    
    // collect data
    wire sum_s_tvalid;
    wire sum_s_tready;
    wire [WIDTH-1:0] sum_s_tdata;
    wire sum_s_tlast;
    wire sum_m_tvalid;
    wire sum_m_tready;
    wire [SUM_WIDTH-1:0] sum_m_tdata;
    
    assign sum_s_tvalid = router_m_tvalid;
    assign router_m_tready = sum_s_tready;
    assign sum_s_tdata = router_m_tdata;
    assign sum_s_tlast = router_m_tlast;
    
    axis_frame_summer #(
        .DATA_WIDTH (WIDTH),
        .SUM_WIDTH  (SUM_WIDTH),
        .MAX_LENGTH (PULSE_LENGTH)
    ) sum_inst (
        .clk                 (clk),
        .resetn              (resetn),
        .s_tready            (sum_s_tready),
        .s_tvalid            (sum_s_tvalid),
        .s_tdata             (sum_s_tdata),
        .s_tlast             (sum_s_tlast),
        .m_tready            (sum_m_tready),
        .m_tvalid            (sum_m_tvalid),
        .m_tdata             (sum_m_tdata),
        .adder_err           (adder_err),
        .stream_overflow_err (stream_overflow_err)
    );
    assign m_tvalid = sum_m_tvalid;
    assign m_tdata = sum_m_tdata;
    assign sum_m_tready = m_tready; 
endmodule