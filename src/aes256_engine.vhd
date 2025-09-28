library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_AES256_COMPONENT.all;



entity aes256_engine is
    generic (
        NUM_AES_CORES       : natural range 1 to 15 := 1 -- Allowed values: [1-5, 8, 15]
    );
    port(
        -- System
        clk                 : IN STD_LOGIC;
        rst                 : IN STD_LOGIC;
        
        -- Key Logic
        pi_key_expand_start : IN STD_LOGIC;
        pi_master_key       : IN STD_LOGIC_VECTOR(MATRIX_KEY_WIDTH-1 DOWNTO 0);
        po_key_ready        : OUT STD_LOGIC;
        
        -- Data Input
        s_axis_tready       : OUT STD_LOGIC;
        s_axis_tvalid       : IN STD_LOGIC;
        s_axis_tlast        : IN STD_LOGIC;
        s_axis_tdata        : IN STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
        
        -- Data Output
        m_axis_tready       : IN STD_LOGIC;
        m_axis_tvalid       : OUT STD_LOGIC;
        m_axis_tlast        : OUT STD_LOGIC;
        m_axis_tdata        : OUT STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0)
    );
end aes256_engine;

architecture behavioral of aes256_engine is

signal round_keys_array         : t_ROUND_KEYS(0 to N_ROUNDS-1);
signal reg_KEY_EXP_KEY_READY    : STD_LOGIC;


type logic_array                is array (0 to NUM_AES_CORES -1) of STD_LOGIC;
type logic_vector_array         is array (0 to NUM_AES_CORES -1) of STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 downto 0);

signal AES_core_s_axis_tready   : logic_array;
signal AES_core_s_axis_tvalid   : logic_array;
signal AES_core_s_axis_tlast    : logic_array;
signal AES_core_s_axis_tdata    : logic_vector_array;

signal AES_core_m_axis_tready   : logic_array;
signal AES_core_m_axis_tvalid   : logic_array;
signal AES_core_m_axis_tlast    : logic_array;
signal AES_core_m_axis_tdata    : logic_vector_array;


begin
    -- Throw assert if NUM_AES_CORES is set to an illegal value
    check_num_cores : assert (NUM_AES_CORES = 1 or NUM_AES_CORES = 2 or NUM_AES_CORES = 3 or NUM_AES_CORES = 4 or NUM_AES_CORES = 5 or NUM_AES_CORES = 8 or NUM_AES_CORES = 15) report "Invalid value given for NUM_AES_CORES. Allowed values are {1,2,3,4,5,8,15}" severity failure;

    KEY_EXPANSION_TOP_INST_1: entity work.key_expansion_top
        port map(
            clk => clk,
            rst => rst,
            pi_key_expand_start => pi_key_expand_start,
            pi_master_key => pi_master_key,
            po_round_keys_array => round_keys_array,
            po_key_ready => reg_KEY_EXP_KEY_READY
        );
    
    
    AES_cores : for i in 0 to (NUM_AES_CORES-1) generate
        type int_list_t is array (0 to 14) of integer;
        type nested_int_list_t is array (natural range <>) of int_list_t;
        constant core_rounds : nested_int_list_t := (
            (15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (7,  8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (5,  5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (3,  4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (3,  3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (others => 0),
            (others => 0),
            (1,  2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (1,  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
        );
        constant core_start_round_num : nested_int_list_t := (
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (0,  7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (0,  5, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (0,  3, 7, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (0,  3, 6, 9, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            (others => 0),
            (others => 0),
            (0,  1, 3, 5, 7, 9, 11, 13, 0, 0, 0, 0, 0, 0, 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (others => 0),
            (0,  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)
        );

        constant NUM_ROUNDS_CORE_i : integer := core_rounds(NUM_AES_CORES-1)(i);
        constant START_IDX_CORE_i : integer := core_start_round_num(NUM_AES_CORES-1)(i);
        constant END_IDX_CORE_i   : integer := START_IDX_CORE_i + NUM_ROUNDS_CORE_i - 1;
    begin
        INST_i : entity work.aes_core
            generic map(
                NUM_ROUNDS => NUM_ROUNDS_CORE_i,
                CONTAINS_INITIAL_ROUND => i = 0,
                CONTAINS_FINAL_ROUND => i = NUM_AES_CORES-1
            )
            port map(
                clk => clk,
                rst => rst,
                pi_round_keys_array => round_keys_array(START_IDX_CORE_i to END_IDX_CORE_i),
                pi_key_ready => reg_KEY_EXP_KEY_READY,
                s_axis_tready => AES_core_s_axis_tready(i),
                s_axis_tvalid => AES_core_s_axis_tvalid(i),
                s_axis_tlast => AES_core_s_axis_tlast(i),
                s_axis_tdata => AES_core_s_axis_tdata(i),
                m_axis_tready => AES_core_m_axis_tready(i),
                m_axis_tvalid => AES_core_m_axis_tvalid(i),
                m_axis_tlast => AES_core_m_axis_tlast(i),
                m_axis_tdata => AES_core_m_axis_tdata(i)
            );
    end generate;
    
    AES_core_axis_interconnections : for i in 1 to (NUM_AES_CORES-1) generate
        AES_core_s_axis_tdata(i) <= AES_core_m_axis_tdata(i-1);
        AES_core_s_axis_tlast(i) <= AES_core_m_axis_tlast(i-1);
        AES_core_s_axis_tvalid(i) <= AES_core_m_axis_tvalid(i-1) and reg_KEY_EXP_KEY_READY;
        AES_core_m_axis_tready(i-1) <= AES_core_s_axis_tready(i) or not reg_KEY_EXP_KEY_READY;
    end generate;
    
    AES_core_s_axis_tdata(0) <= s_axis_tdata;
    AES_core_s_axis_tlast(0) <= s_axis_tlast;
    AES_core_s_axis_tvalid(0) <= s_axis_tvalid;
    s_axis_tready <= AES_core_s_axis_tready(0);
    
    m_axis_tdata <= AES_core_m_axis_tdata(NUM_AES_CORES-1);
    m_axis_tlast <= AES_core_m_axis_tlast(NUM_AES_CORES-1);
    m_axis_tvalid <= AES_core_m_axis_tvalid(NUM_AES_CORES-1);
    AES_core_m_axis_tready(NUM_AES_CORES-1) <= m_axis_tready;
    
    po_key_ready <= reg_KEY_EXP_KEY_READY;
    
end behavioral;
