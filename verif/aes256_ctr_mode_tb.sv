`timescale 1ns/1ps

`define CLK_PERIOD 10

module aes256_ctr_tb ();

// bench variables
reg clk = 1;
reg rst;

// key in
reg [255:0] master_key; 
reg [127:0] input_iv;

reg [31:0] config_register; 
wire [31:0] status_register; 


// data in
wire s_axis_tready;
reg s_axis_tvalid;
reg s_axis_tlast;
reg [127:0] s_axis_tdata;

// data out
reg m_axis_tready;
wire m_axis_tvalid;
wire m_axis_tlast;
wire [127:0] m_axis_tdata;

aes256_ctr_mode DUT_aes256_i(
    .clk(clk),
    .rst(rst),
    
    .config_register(config_register),
    .status_register(status_register),
    
    .input_key(master_key),
    .input_iv(input_iv),
    
    .s_axis_tready(s_axis_tready),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tdata(s_axis_tdata),
    
    .m_axis_tready(m_axis_tready),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tdata(m_axis_tdata)
);

// clock gen
always #(`CLK_PERIOD/2) clk = ~clk;

task automatic axi_send_sample(
    input logic [127:0] tdata,
    input logic         tlast
);
begin
    // Drive AXI signals
    s_axis_tdata  <= tdata;
    s_axis_tlast  <= tlast;
    s_axis_tvalid <= 1;

    // Wait one cycle
    #10;

    // Deassert valid after one cycle
    s_axis_tvalid <= 0;
    s_axis_tlast  <= 0;
    s_axis_tdata  <= '0;
end
endtask

// setup test vars and checkers


initial begin
    $timeformat(-9, 2, " ns", 20);
end

initial begin
    rst <= 1;
    s_axis_tvalid <= 0;
    s_axis_tlast <= 0;
    config_register <= 32'h_00;
    s_axis_tdata <= 128'h_0000_0000_0000_0000_0000_0000_0000_0000;
    master_key <= 256'h_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
    m_axis_tready <= 1;
    
    #50
    rst <= 0;
    #40
    
    master_key <= 256'h_603DEB10_15CA71BE_2B73AEF0_857D7781_1F352C07_3B6108D7_2D9810A3_0914DFF4; // Test vectors from https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_CTR.pdf
    input_iv <= 128'h_F0F1F2F3_F4F5F6F7_F8F9FAFB_FCFDFEFF;
    config_register <= 32'h_01;
    #10
    config_register <= 32'h_00;
    #950
    
    
    s_axis_tlast  <= 0;
    s_axis_tvalid <= 1;
    #30000
    
    
    #600
    
    axi_send_sample(128'h_6BC1BEE2_2E409F96_E93D7E11_7393172A, 0); // Expected result is: 601EC313 775789A5 B7A7F504 BBF3D228 (keystream 0BDF7DF1_59171633_5E9A8B15_C860C502)
    axi_send_sample(128'h_AE2D8A57_1E03AC9C_9EB76FAC_45AF8E51, 0); // Expected result is: F443E3CA 4D62B59A CA84E990 CACAF5C5 (keystream 5A6E699D_53611906_5433863C_8F657B94)
    axi_send_sample(128'h_30C81C46_A35CE411_E5FBC119_1A0A52EF, 0); // Expected result is: 2B0930DA A23DE94C E87017BA 2D84988D (keystream 1BC12C9C_01610D5D_0D8BD6A3_378ECA62)
    axi_send_sample(128'h_F69F2445_DF4F9B17_AD2B417B_E66C3710, 1); // Expected result is: DFC9C58D B67AADA6 13C2DD08 457941A6 (keystream 2956E1C8_693536B1_BEE99C73_A31576B6)
    
    #650
    
    for (int i = 0; i < 200; i++)
        //#140
        #30
        axi_send_sample(128'h_AE2D_8A57_1E03_AC9C_9EB7_6FAC_45AF_8E51, 0);
    
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
