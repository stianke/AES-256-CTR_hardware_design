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
    
    
    
    master_key <= 256'h_603D_EB10_15CA_71BE_2B73_AEF0_857D_7781_1F35_2C07_3B61_08D7_2D98_10A3_0914_DFF4; // Test vectors from https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_Core256.pdf
    key_expand_start <= 1;
    #10
    key_expand_start <= 0;
    #950
    
    s_axis_tvalid <= 1;
    s_axis_tdata <= 128'h_6BC1_BEE2_2E40_9F96_E93D_7E11_7393_172A; // Expected result is: F3EE_D1BD_B5D2_A03C_064B_5A7E_3DB1_81F8
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    //#120
    s_axis_tvalid <= 1;
    s_axis_tdata <= 128'h_AE2D_8A57_1E03_AC9C_9EB7_6FAC_45AF_8E51; // Expected result is: 591C_CB10_D410_ED26_DC5B_A74A_3136_2870
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    //#120
    s_axis_tvalid <= 1;
    s_axis_tdata <= 128'h_30C8_1C46_A35C_E411_E5FB_C119_1A0A_52EF; // Expected result is: B6ED_21B9_9CA6_F4F9_F153_E7B1_BEAF_ED1D
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    //#120
    s_axis_tvalid <= 1;
    s_axis_tdata <= 128'h_F69F_2445_DF4F_9B17_AD2B_417B_E66_C3710; // Expected result is: 2330_4B7A_39F9_F3FF_067D_8D8F_9E24_ECC7
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    
    
    #560
    s_axis_tvalid <= 1;
    s_axis_tdata <= 123'h_0000_0000_0000_0000_0000_0000_0000_0000;
    #10
    s_axis_tvalid <= 0;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
        
    
    #650
    // Test vector set 2 (https://nvlpubs.nist.gov/nistpubs/fips/nist.fips.197.pdf, page 42):
    //master_key <= 256'h_0001_0203_0405_0607_0809_0a0b_0c0d_0e0f_1011_1213_1415_1617_1819_1a1b_1c1d_1e1f;
    // s_axis_tdata <= 123'h_0011_2233_4455_6677_8899_aabb_ccdd_eeff; // Expected result is 8ea2b7ca516745bfeafc49904b496089
    finish_simulation;
end

function finish_simulation;
    $display("%0t: --- Simulation finished ---", $time);
    $display("\n");
    $finish;
endfunction

endmodule
