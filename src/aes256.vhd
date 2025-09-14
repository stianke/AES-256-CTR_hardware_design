library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_AES256_COMPONENT.all;

entity aes256 is
    port(
        -- system
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        -- data input
        pi_key_expand_start : IN STD_LOGIC;
        pi_master_key : IN STD_LOGIC_VECTOR(MATRIX_KEY_WIDTH-1 DOWNTO 0);
        -- data output
        po_key_ready : OUT STD_LOGIC;
        -- data input
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tvalid: IN STD_LOGIC;
        s_axis_tdata: IN STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
        -- data output
        --m_axis_tready : IN STD_LOGIC;
        --m_axis_tvalid: OUT STD_LOGIC;
        --m_axis_tdata: OUT STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
        
        po_data_valid : OUT STD_LOGIC;
        po_data : OUT STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0)
    );
end aes256;

architecture behavioral of aes256 is

signal w_KEY_EXP_ROUND_KEYS_ARRAY : t_ROUND_KEYS;
signal reg_KEY_EXP_KEY_READY : STD_LOGIC;

signal reg_DATA_ENC_DATA_VALID : STD_LOGIC;
signal reg_DATA_ENC_DATA : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);

begin
    KEY_EXPANSION_TOP_INST_1: entity work.key_expansion_top
        port map(
            clk => clk,
            rst => rst,
            pi_key_expand_start => pi_key_expand_start,
            pi_master_key => pi_master_key,
            po_round_keys_array => w_KEY_EXP_ROUND_KEYS_ARRAY,
            po_key_ready => reg_KEY_EXP_KEY_READY
        );
    
    ENCRYPTION_TOP_INST_1: entity work.encryption_top
        port map(
            clk => clk,
            rst => rst,
            pi_round_keys_array => w_KEY_EXP_ROUND_KEYS_ARRAY,
            pi_key_ready => reg_KEY_EXP_KEY_READY,
            s_axis_tready => s_axis_tready,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata => s_axis_tdata,
            po_data_valid => reg_DATA_ENC_DATA_VALID,
            po_data => reg_DATA_ENC_DATA
        );

    po_key_ready <= reg_KEY_EXP_KEY_READY;
    po_data_valid <= reg_DATA_ENC_DATA_VALID;
    po_data <= reg_DATA_ENC_DATA;
    
end behavioral;
