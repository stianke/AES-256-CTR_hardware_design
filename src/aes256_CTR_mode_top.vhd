library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_AES256_COMPONENT.all;

entity aes256_ctr_mode_top is
    generic (
        -- These generics can be changed to customize the design
        IV_COUNTER_WIDTH    : integer := 32;
        NUM_AES_CORES       : integer := 1; -- Allowed values: [1-5, 8, 15]
        ADD_KEYSTREAM_BUFFER: boolean := False;
        
        -- These generics should remain as is
        REGISTER_WIDTH      : integer := 32;
        ADDR_WIDTH          : natural := 12
    );
    port(
        -- System
        clk                 : IN STD_LOGIC;
        rst_n               : IN STD_LOGIC;
        
        -- Slave AXI-Lite interface
        s_axi_awaddr            : in std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        s_axi_awvalid           : in std_logic := '0';
        s_axi_awready           : out std_logic := '0';
        s_axi_wdata             : in std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        s_axi_wvalid            : in std_logic := '0';
        s_axi_wready            : out std_logic := '0';
        s_axi_bresp             : out std_logic_vector(1 downto 0) := (others => '0');
        s_axi_bvalid            : out std_logic := '0';
        s_axi_bready            : in std_logic := '0';
        s_axi_araddr            : in std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        s_axi_arvalid           : in std_logic := '0';
        s_axi_arready           : out std_logic := '0';
        s_axi_rdata             : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        s_axi_rvalid            : out std_logic := '0';
        s_axi_rready            : in std_logic := '0';
        s_axi_rresp             : out std_logic_vector(1 downto 0) := (others => '0');
        
        -- Plaintext Input
        s_axis_tready       : OUT STD_LOGIC;
        s_axis_tvalid       : IN STD_LOGIC;
        s_axis_tlast        : IN STD_LOGIC;
        s_axis_tdata        : IN STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
        
        -- Ciphertext Output
        m_axis_tready       : IN STD_LOGIC;
        m_axis_tvalid       : OUT STD_LOGIC;
        m_axis_tlast        : OUT STD_LOGIC;
        m_axis_tdata        : OUT STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0)
    );
end aes256_ctr_mode_top;

architecture behavioral of aes256_ctr_mode_top is


-- Control/Status Register
signal control_register    : STD_LOGIC_VECTOR(REGISTER_WIDTH - 1 DOWNTO 0);
signal status_register     : STD_LOGIC_VECTOR(REGISTER_WIDTH - 1 DOWNTO 0);
        
-- Key and IV
signal key                 : STD_LOGIC_VECTOR(MATRIX_KEY_WIDTH-1 DOWNTO 0);
signal iv                  : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);

signal rst               : STD_LOGIC;

begin

    AES_256_CTR_MAIN_INST_1: entity work.aes256_ctr_mode_main
    generic map(
        IV_COUNTER_WIDTH => IV_COUNTER_WIDTH,
        REGISTER_WIDTH => REGISTER_WIDTH,
        NUM_AES_CORES => NUM_AES_CORES,
        ADD_KEYSTREAM_BUFFER => ADD_KEYSTREAM_BUFFER
    )
    port map(
        -- System
        clk  => clk,
        rst => rst,
        -- Registers
        control_register => control_register,
        status_register => status_register,
        input_key => key,
        input_iv => iv,
        -- Data Input
        s_axis_tready => s_axis_tready,
        s_axis_tvalid => s_axis_tvalid,
        s_axis_tlast => s_axis_tlast,
        s_axis_tdata => s_axis_tdata,
        -- Data Output
        m_axis_tready => m_axis_tready,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tlast => m_axis_tlast,
        m_axis_tdata => m_axis_tdata
    );
    
    
    AXI_LITE_REGS_INST_1: entity work.axi_regs
        generic map(
            ADDR_WIDTH => ADDR_WIDTH,
            REGISTER_WIDTH => REGISTER_WIDTH
        )
        port map(
            -- Slave AXI-Lite interface
            s_axi_aclk       => clk,
            s_axi_aresetn    => rst_n,
            s_axi_awaddr     => s_axi_awaddr,
            s_axi_awvalid    => s_axi_awvalid,
            s_axi_awready    => s_axi_awready,
            s_axi_wdata      => s_axi_wdata,
            s_axi_wvalid     => s_axi_wvalid,
            s_axi_wready     => s_axi_wready,
            s_axi_bresp      => s_axi_bresp,
            s_axi_bvalid     => s_axi_bvalid,
            s_axi_bready     => s_axi_bready,
            s_axi_araddr     => s_axi_araddr,
            s_axi_arvalid    => s_axi_arvalid,
            s_axi_arready    => s_axi_arready,
            s_axi_rdata      => s_axi_rdata,
            s_axi_rvalid     => s_axi_rvalid,
            s_axi_rready     => s_axi_rready,
            s_axi_rresp      => s_axi_rresp,
            control_register => control_register ,
            key_part_0       => key(1*REGISTER_WIDTH-1 downto 0*REGISTER_WIDTH),
            key_part_1       => key(2*REGISTER_WIDTH-1 downto 1*REGISTER_WIDTH),
            key_part_2       => key(3*REGISTER_WIDTH-1 downto 2*REGISTER_WIDTH),
            key_part_3       => key(4*REGISTER_WIDTH-1 downto 3*REGISTER_WIDTH),
            key_part_4       => key(5*REGISTER_WIDTH-1 downto 4*REGISTER_WIDTH),
            key_part_5       => key(6*REGISTER_WIDTH-1 downto 5*REGISTER_WIDTH),
            key_part_6       => key(7*REGISTER_WIDTH-1 downto 6*REGISTER_WIDTH),
            key_part_7       => key(8*REGISTER_WIDTH-1 downto 7*REGISTER_WIDTH),
            iv_part_0        => iv(1*REGISTER_WIDTH-1 downto 0*REGISTER_WIDTH),
            iv_part_1        => iv(2*REGISTER_WIDTH-1 downto 1*REGISTER_WIDTH),
            iv_part_2        => iv(3*REGISTER_WIDTH-1 downto 2*REGISTER_WIDTH),
            iv_part_3        => iv(4*REGISTER_WIDTH-1 downto 3*REGISTER_WIDTH),
            status_register  => status_register
    );
    
    rst <= not rst_n;
    
end behavioral;
