`timescale 1ns/1ps


`define CLK_PERIOD 10

import axi_vip_0_pkg::*;
//import axi_vip_master_pkg::*;  // Master agent package

module aes256_ctr_tb ();

// bench variables
reg clk = 1;
reg aresetn;


// key in
reg [255:0] master_key;
reg [127:0] input_iv;

reg [31:0] config_register; 
reg [31:0] status_register; 


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

integer test_number;


// Slave AXI-Lite interface
wire [11:0] s_axi_awaddr;
wire s_axi_awvalid;
wire s_axi_awready;
wire [31:0] s_axi_wdata;
wire s_axi_wvalid;
wire s_axi_wready;
wire [1:0] s_axi_bresp;
wire s_axi_bvalid;
wire s_axi_bready;
wire [11:0] s_axi_araddr;
wire s_axi_arvalid;
wire s_axi_arready;
wire [31:0] s_axi_rdata;
wire s_axi_rvalid;
wire s_axi_rready;
wire [1:0] s_axi_rresp;

reg resp;

aes256_ctr_mode_top DUT_aes256_i(
    .clk(clk),
    .rst_n(aresetn),
    
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .s_axi_rresp(s_axi_rresp),
    
    .s_axis_tready(s_axis_tready),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tdata(s_axis_tdata),
    
    .m_axis_tready(m_axis_tready),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tdata(m_axis_tdata)
);

// AXI VIP instance
  axi_vip_0 vip_master (
    .aclk    (clk),
    .aresetn (aresetn),
    .m_axi_awaddr  (s_axi_awaddr),
    .m_axi_awvalid (s_axi_awvalid),
    .m_axi_awready (s_axi_awready),
    .m_axi_wdata   (s_axi_wdata),
    .m_axi_wvalid  (s_axi_wvalid),
    .m_axi_wready  (s_axi_wready),
    .m_axi_bresp   (s_axi_bresp),
    .m_axi_bvalid  (s_axi_bvalid),
    .m_axi_bready  (s_axi_bready),
    .m_axi_araddr  (s_axi_araddr),
    .m_axi_arvalid (s_axi_arvalid),
    .m_axi_arready (s_axi_arready),
    .m_axi_rdata   (s_axi_rdata),
    .m_axi_rresp   (s_axi_rresp),
    .m_axi_rvalid  (s_axi_rvalid),
    .m_axi_rready  (s_axi_rready)
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


// Producer instance
data_producer #() prod (
    .clk(clk),
    .rst(rst),
    .m_axis_tdata(s_axis_tdata),
    .m_axis_tvalid(s_axis_tvalid),
    .m_axis_tlast(s_axis_tlast),
    .m_axis_tready(s_axis_tready),
    .test_number(test_number)
);

// Consumer instance
data_consumer #() cons (
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(m_axis_tdata),
    .s_axis_tvalid(m_axis_tvalid),
    .s_axis_tlast(m_axis_tlast),
    .s_axis_tready(m_axis_tready),
    .test_number(test_number)
);


// setup test vars and checkers


initial begin
    $timeformat(-9, 2, " ns", 20);
end

integer fd;
integer i;
string key_filename;
string iv_filename;
integer num_tests;

//axi_vip_master_mst_t master_agent;
axi_vip_0_mst_t  axi_vip_master_agent;

`define CONTROL_REGISTER_ADDR   32'h00
`define STATUS_REGISTER_ADDR    32'h04

`define KEY_PART_0_ADDR         32'h08
`define KEY_PART_1_ADDR         32'h0C
`define KEY_PART_2_ADDR         32'h10
`define KEY_PART_3_ADDR         32'h14
`define KEY_PART_4_ADDR         32'h18
`define KEY_PART_5_ADDR         32'h1C
`define KEY_PART_6_ADDR         32'h20
`define KEY_PART_7_ADDR         32'h24

`define IV_PART_0_ADDR          32'h28
`define IV_PART_1_ADDR          32'h2C
`define IV_PART_2_ADDR          32'h30
`define IV_PART_3_ADDR          32'h34


initial begin
    
    // Start by performing a full reset of the system
    aresetn <= 0;
    #10
    aresetn <= 1;
    
    
    fd = $fopen("../../../../../verif/generated_test_data/number_of_test_sets.txt", "r");
    if (fd == 0) $fatal(1 ,"Failed to open file number_of_test_sets.txt\n");
    $fscanf(fd, "%d\n", num_tests);
    $fclose(fd);
    
    axi_vip_master_agent = new("axi_vip_master_agent", aes256_ctr_tb.vip_master.inst.IF);
    axi_vip_master_agent.start_master();
    
    for (i = 0; i< num_tests; i++) begin
        $display("Starting test %0d", i);
        
        axi_vip_master_agent.AXI4LITE_READ_BURST(`STATUS_REGISTER_ADDR, 0, status_register, resp);
        $display("Status register is %h before test starts", status_register);
        
        // Set "load key and IV high, to prevent the previous encryption session to eat up my new set of plaintext
        config_register = 32'h00_00_00_01;
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`CONTROL_REGISTER_ADDR, 0, config_register, resp);
        
        axi_vip_master_agent.AXI4LITE_READ_BURST(`STATUS_REGISTER_ADDR, 0, status_register, resp);
        $display("Config register set to %h (enabling load_key_and_iv bit). New value of status register reads as %h", config_register, status_register);
        
        // Increment test_number, signaling to data_producer and data_consumer to open a new file.
        test_number = i;
        
        
        //master_key <= 256'h_603DEB10_15CA71BE_2B73AEF0_857D7781_1F352C07_3B6108D7_2D9810A3_0914DFF4; // Test vectors from https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Standards-and-Guidelines/documents/examples/AES_CTR.pdf
        //input_iv <= 128'h_F0F1F2F3_F4F5F6F7_F8F9FAFB_FCFDFEFF;
        
        key_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_key.txt", test_number);
        fd = $fopen(key_filename, "r");
        if (fd == 0) $fatal(1 ,"Failed to open key file %s\n", key_filename);
        $fscanf(fd, "%h\n", master_key);
        $fclose(fd);
        
        iv_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_iv.txt", test_number);
        fd = $fopen(iv_filename, "r");
        if (fd == 0) $fatal(1, "Failed to open iv file %s\n", key_filename);
        $fscanf(fd, "%h\n", input_iv);
        $fclose(fd);
        
        // Set the key
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_0_ADDR, 0, master_key[(1*32-1):(0*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_1_ADDR, 0, master_key[(2*32-1):(1*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_2_ADDR, 0, master_key[(3*32-1):(2*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_3_ADDR, 0, master_key[(4*32-1):(3*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_4_ADDR, 0, master_key[(5*32-1):(4*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_5_ADDR, 0, master_key[(6*32-1):(5*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_6_ADDR, 0, master_key[(7*32-1):(6*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`KEY_PART_7_ADDR, 0, master_key[(8*32-1):(7*32)], resp);
        $display("Key set to %h", master_key);
        
        // Set the IV
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`IV_PART_0_ADDR, 0, input_iv[(1*32-1):(0*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`IV_PART_1_ADDR, 0, input_iv[(2*32-1):(1*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`IV_PART_2_ADDR, 0, input_iv[(3*32-1):(2*32)], resp);
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`IV_PART_3_ADDR, 0, input_iv[(4*32-1):(3*32)], resp);
        $display("IV set to %h", input_iv);
        
        // Set to normal operation
        config_register = 32'h00_00_00_00;
        axi_vip_master_agent.AXI4LITE_WRITE_BURST(`CONTROL_REGISTER_ADDR, 0, config_register, resp);
        
        #100
        axi_vip_master_agent.AXI4LITE_READ_BURST(`STATUS_REGISTER_ADDR, 0, status_register, resp);
        $display("Config register set to %h, to continue normal operation. 100 clock cycles later, the new value of the status register reads as %h", config_register, status_register);
        
        // Wait until the end of the test
        do begin
            @(posedge clk);
        end while (!(m_axis_tlast == 1 && m_axis_tvalid == 1 && m_axis_tready == 1));
        
        $display("Test %0d finished successfully\n", test_number);
     end
    #100
    //axi_send_sample(128'h_6BC1BEE2_2E409F96_E93D7E11_7393172A, 0); // Expected result is: 601EC313 775789A5 B7A7F504 BBF3D228 (keystream 0BDF7DF1_59171633_5E9A8B15_C860C502)
    //axi_send_sample(128'h_AE2D8A57_1E03AC9C_9EB76FAC_45AF8E51, 0); // Expected result is: F443E3CA 4D62B59A CA84E990 CACAF5C5 (keystream 5A6E699D_53611906_5433863C_8F657B94)
    //axi_send_sample(128'h_30C81C46_A35CE411_E5FBC119_1A0A52EF, 0); // Expected result is: 2B0930DA A23DE94C E87017BA 2D84988D (keystream 1BC12C9C_01610D5D_0D8BD6A3_378ECA62)
    //axi_send_sample(128'h_F69F2445_DF4F9B17_AD2B417B_E66C3710, 1); // Expected result is: DFC9C58D B67AADA6 13C2DD08 457941A6 (keystream 2956E1C8_693536B1_BEE99C73_A31576B6)
    
    //#650
    
    //for (int i = 0; i < 200; i++)
        //#140
    //    #30
    //    axi_send_sample(128'h_AE2D_8A57_1E03_AC9C_9EB7_6FAC_45AF_8E51, 0);
    
    #650
    // Test vector set 2 (https://nvlpubs.nist.gov/nistpubs/fips/nist.fips.197.pdf, page 42):
    //master_key <= 256'h_0001_0203_0405_0607_0809_0a0b_0c0d_0e0f_1011_1213_1415_1617_1819_1a1b_1c1d_1e1f;
    // s_axis_tdata <= 123'h_0011_2233_4455_6677_8899_aabb_ccdd_eeff; // Expected result is 8ea2b7ca516745bfeafc49904b496089
    finish_simulation;
end

function finish_simulation;
    $display("%0t: --- Simulation finished successfully ---", $time);
    $display("\n");
    $finish;
endfunction

endmodule
