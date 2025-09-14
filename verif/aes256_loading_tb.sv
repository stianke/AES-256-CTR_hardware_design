`timescale 1ns/1ps

`define CLK_PERIOD 10

module aes256_tb ();

// bench variables
reg clk = 1;
reg rst;

// key in
reg key_expand_start;
reg [255:0] master_key; 

// key out
wire key_ready;

// data in
wire s_axis_tready;
reg s_axis_tvalid;
reg [127:0] s_axis_tdata;

// data out
wire data_out_valid;
wire [127:0] data_out;

aes256 DUT_aes256_i(
    .clk(clk),
    .rst(rst),
    .pi_key_expand_start(key_expand_start),
    .pi_master_key(master_key),
    .po_key_ready(key_ready),
    
    .s_axis_tready(s_axis_tready),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tdata(s_axis_tdata),
    
    .po_data_valid(data_out_valid),
    .po_data(data_out)
);

// clock gen
always #(`CLK_PERIOD/2) clk = ~clk;

// setup test vars and checkers


initial begin
    $timeformat(-9, 2, " ns", 20);
end

initial begin
    rst <= 1;
    s_axis_tvalid <= 0;
    key_expand_start <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    master_key <= 256'h_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
    
    #50
    rst <= 0;
    #40
    
    master_key <= 256'h_0001_0203_0405_0607_0809_0a0b_0c0d_0e0f_1011_1213_1415_1617_1819_1a1b_1c1d_1e1f;
    key_expand_start <= 1;
    #10
    key_expand_start <= 0;
    #950
    
    s_axis_tvalid <= 1;
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    //#120
    s_axis_tvalid <= 1;
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    //#120
    s_axis_tvalid <= 1;
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    //#120
    s_axis_tvalid <= 1;
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    
    #560
    s_axis_tvalid <= 1;
    s_axis_tdata <= 123'h_0011_2233_4455_6677_8899_aabb_ccdd_eeff;
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
        
    
    #650
    finish_simulation;
end

function finish_simulation;
    $display("%0t: --- Simulation finished ---", $time);
    $display("\n");
    $finish;
endfunction

endmodule
