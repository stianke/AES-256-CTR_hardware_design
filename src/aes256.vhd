library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_AES256_COMPONENT.all;

entity aes256 is
    generic (
        NUM_AES_CORES       : integer := 1
    );
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

signal round_keys_array : t_ROUND_KEYS;
signal reg_KEY_EXP_KEY_READY : STD_LOGIC;

signal s_axis_tready_internal : STD_LOGIC;
signal m_axis_tvalid_internal : STD_LOGIC;

type logic_array is array (0 to NUM_AES_CORES -1) of STD_LOGIC;
type logic_vector_array is array (0 to NUM_AES_CORES -1) of STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 downto 0);

signal AES_core_s_axis_tready : logic_array;
signal AES_core_s_axis_tvalid : logic_array;
signal AES_core_s_axis_tlast : logic_array;
signal AES_core_s_axis_tdata : logic_vector_array;

signal AES_core_m_axis_tready : logic_array;
signal AES_core_m_axis_tvalid : logic_array;
signal AES_core_m_axis_tlast : logic_array;
signal AES_core_m_axis_tdata : logic_vector_array;

signal pr_rx_core : UNSIGNED(3 DOWNTO 0);
signal pr_tx_core : UNSIGNED(3 DOWNTO 0);
signal num_samples_received : UNSIGNED(1 DOWNTO 0);
signal num_samples_sent : UNSIGNED(1 DOWNTO 0);

begin

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
        INST_i : entity work.encryption_top
            port map(
                clk => clk,
                rst => rst,
                pi_round_keys_array => round_keys_array,
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
    
    
    
    rx_control : process(clk)
    begin
    if (rising_edge(clk)) then
        if (rst = '1') then
            pr_rx_core <= to_unsigned(0, 4);
            num_samples_received <= to_unsigned(0, 2);
        else
            if (s_axis_tvalid = '1' and s_axis_tready_internal = '1') then
                num_samples_received <= num_samples_received + 1;
                if (num_samples_received = to_unsigned(3, 2)) then
                    if (pr_rx_core = to_unsigned(NUM_AES_CORES-1, 4)) then
                        pr_rx_core <= to_unsigned(0, 4);
                    else
                        pr_rx_core <= pr_rx_core + 1;
                    end if;
                else
                    pr_rx_core <= pr_rx_core;
                end if;
            else
                num_samples_received <= num_samples_received;
                pr_rx_core <= pr_rx_core;
            end if;
        end if;
    end if;
    end process;
    
    tx_control : process(clk)
    begin
    if (rising_edge(clk)) then
        if (rst = '1') then
            pr_tx_core <= to_unsigned(0, 4);
            num_samples_sent <= to_unsigned(0, 2);
        else
            if (m_axis_tvalid_internal = '1' and m_axis_tready = '1') then
                num_samples_sent <= num_samples_sent + 1;
                if (num_samples_sent = to_unsigned(3, 2)) then
                    if (pr_tx_core = to_unsigned(NUM_AES_CORES-1, 4)) then
                        pr_tx_core <= to_unsigned(0, 4);
                    else
                        pr_tx_core <= pr_tx_core + 1;
                    end if;
                else
                    pr_tx_core <= pr_tx_core;
                end if;
            else
                num_samples_sent <= num_samples_sent;
                pr_tx_core <= pr_tx_core;
            end if;
        end if;
    end if;
    end process;
    
    s_axis_tready_internal <= AES_core_s_axis_tready(to_integer(pr_rx_core));
    
    m_axis_tlast <= AES_core_m_axis_tlast(to_integer(pr_tx_core));
    m_axis_tdata <= AES_core_m_axis_tdata(to_integer(pr_tx_core));
    m_axis_tvalid_internal <= AES_core_m_axis_tvalid(to_integer(pr_tx_core));
    
    AES_cores_axis_assignment : for i in 0 to (NUM_AES_CORES-1) generate
        AES_core_s_axis_tlast(i) <= s_axis_tlast;
        AES_core_s_axis_tdata(i) <= s_axis_tdata;
        
        s_axis_tvalid_i : process(pr_rx_core, s_axis_tvalid)
        begin
            if (i = pr_rx_core) then
                AES_core_s_axis_tvalid(i) <= s_axis_tvalid;
            else
                AES_core_s_axis_tvalid(i) <= '0';
            end if;
        end process;
        
        m_axis_tready_i : process(pr_tx_core, m_axis_tready)
        begin
            if (i = pr_tx_core) then
                AES_core_m_axis_tready(i) <= m_axis_tready;
            else
                AES_core_m_axis_tready(i) <= '0';
            end if;
        end process;
    end generate;
    
    s_axis_tready <= s_axis_tready_internal;
    m_axis_tvalid <= m_axis_tvalid_internal;
    
    po_key_ready <= reg_KEY_EXP_KEY_READY;
    
end behavioral;
