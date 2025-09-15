library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_AES256_COMPONENT.all;

entity aes256 is
    port(
        -- System
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        
        -- Key Logic
        pi_key_expand_start : IN STD_LOGIC;
        pi_master_key : IN STD_LOGIC_VECTOR(MATRIX_KEY_WIDTH-1 DOWNTO 0);
        po_key_ready : OUT STD_LOGIC;
        
        -- Data Input
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tvalid: IN STD_LOGIC;
        s_axis_tlast: IN STD_LOGIC;
        s_axis_tdata: IN STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
        
        -- Data Output
        m_axis_tready : IN STD_LOGIC;
        m_axis_tvalid: OUT STD_LOGIC;
        m_axis_tlast: OUT STD_LOGIC;
        m_axis_tdata: OUT STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0)
    );
end aes256;

architecture behavioral of aes256 is

signal w_KEY_EXP_ROUND_KEYS_ARRAY : t_ROUND_KEYS;
signal reg_KEY_EXP_KEY_READY : STD_LOGIC;

signal reg_DATA_ENC_DATA_VALID : STD_LOGIC;
signal reg_DATA_ENC_DATA_LAST : STD_LOGIC;
signal reg_DATA_ENC_DATA : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);

signal reg_FIFO_NUM_FREE_SLOTS : UNSIGNED(2 DOWNTO 0);

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
            s_axis_tlast => s_axis_tlast,
            s_axis_tdata => s_axis_tdata,
            po_data_valid => reg_DATA_ENC_DATA_VALID,
            po_data_tlast => reg_DATA_ENC_DATA_LAST,
            po_data => reg_DATA_ENC_DATA,
            downstream_fifo_free_slots => reg_FIFO_NUM_FREE_SLOTS
        );
    
    -- Since ENCRYPTION_TOP has no internal buffering (and thus no m_axis_tready), the ciphertext
    -- result must be read immediately upon completion. Since the downstream AXIS might not be 
    -- ready, a FIFO buffer is needed for the ciphertext. At any given time, ENCRYPTION_TOP is
    -- not allowed to pipeline more encryption jobs than the number of free slots on the FIFO. To
    -- ensure this is upheld, reg_FIFO_NUM_FREE_SLOTS is fed back into the fsm_encryption control.
    CIPHERTEXT_FIFO_INST_1: entity work.axis_fifo
        port map(
            clk => clk,
            rst => rst,
            s_axis_tdata => reg_DATA_ENC_DATA,
            s_axis_tvalid => reg_DATA_ENC_DATA_VALID,
            s_axis_tlast => reg_DATA_ENC_DATA_LAST,
            s_axis_tready => open, -- ENCRYPTION_TOP has no tready input
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tlast => m_axis_tlast,
            m_axis_tready => m_axis_tready,
            po_free_slots => reg_FIFO_NUM_FREE_SLOTS
        );

    po_key_ready <= reg_KEY_EXP_KEY_READY;
    
end behavioral;
