library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_AES256_COMPONENT.all;

entity aes256_ctr_mode is
    generic (
        IV_COUNTER_WIDTH    : integer := 32;
        REGISTER_WIDTH      : integer := 32
    );
    port(
        -- System
        clk                 : IN STD_LOGIC;
        rst                 : IN STD_LOGIC;
        
        -- Control/Status Register
        config_register     : IN STD_LOGIC_VECTOR(REGISTER_WIDTH - 1 DOWNTO 0);
        status_register     : OUT STD_LOGIC_VECTOR(REGISTER_WIDTH - 1 DOWNTO 0);
        
        -- Key and IV
        input_key           : IN STD_LOGIC_VECTOR(MATRIX_KEY_WIDTH-1 DOWNTO 0);
        input_iv            : IN STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
        
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
end aes256_ctr_mode;

architecture behavioral of aes256_ctr_mode is

signal iv                   : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH - 1 DOWNTO 0);
signal iv_nonce             : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH - IV_COUNTER_WIDTH - 1 DOWNTO 0);
signal iv_counter           : STD_LOGIC_VECTOR(IV_COUNTER_WIDTH - 1 DOWNTO 0);
signal increment_counter    : STD_LOGIC;

signal load_key_and_iv      : STD_LOGIC;
signal key_ready            : STD_LOGIC;

signal tx_raw_keystream     : STD_LOGIC;

signal keystream_tready     : STD_LOGIC;
signal keystream_tvalid     : STD_LOGIC;
signal keystream_tdata      : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);

signal fifo_tdata           : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal fifo_tvalid          : STD_LOGIC;
signal fifo_tlast           : STD_LOGIC;
signal fifo_tready          : STD_LOGIC;

begin
    
    
    AES_256_ENGINE_INST_1: entity work.aes256
    port map(
        -- System
        clk  => clk,
        rst => rst,
        -- Key Logic
        pi_key_expand_start => load_key_and_iv,
        pi_master_key => input_key,
        po_key_ready => key_ready,
        -- Data Input
        s_axis_tready => increment_counter,
        s_axis_tvalid => '1',
        s_axis_tlast => '0',
        s_axis_tdata => iv,
        -- Data Output
        m_axis_tready => keystream_tready,
        m_axis_tvalid => keystream_tvalid,
        m_axis_tlast => open,
        m_axis_tdata => keystream_tdata
    );
            
    -- Single-sample wide TX buffer to hold the sample to transmit.
    -- When loading a new key/IV pair, we want to drain the data in the fifo in the AES engine.
    -- This would result in deasserting m_axis_tvalid, which violates the AXI4-Stream standard.
    -- Therefore, this 1-wide tx buffer is added.
    TX_FIFO_INST_1: entity work.axis_register
    port map(
        clk => clk,
        rst => rst,
        s_axis_tdata => fifo_tdata,
        s_axis_tvalid => fifo_tvalid,
        s_axis_tlast => fifo_tlast,
        s_axis_tready => fifo_tready,
        m_axis_tdata => m_axis_tdata,
        m_axis_tvalid => m_axis_tvalid,
        m_axis_tlast => m_axis_tlast,
        m_axis_tready => m_axis_tready
    );
    
    
    status_register(0) <= key_ready;
    status_register(1) <= tx_raw_keystream;
    status_register(REGISTER_WIDTH - 1 downto 2) <= (others => '0');
    
    load_key_and_iv <= config_register(0);
    tx_raw_keystream <= config_register(0);
    
    iv(IV_COUNTER_WIDTH - 1 downto 0) <= iv_counter;
    iv(MATRIX_DATA_WIDTH - 1 downto IV_COUNTER_WIDTH) <= iv_nonce;
    
    
    iv_process: process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                iv_counter <= (others => '0');
                iv_nonce <= (others => '0');
            else
                if (load_key_and_iv = '1') then
                    iv_counter <= input_iv(IV_COUNTER_WIDTH - 1 downto 0);
                    iv_nonce <= input_iv(MATRIX_DATA_WIDTH - 1 downto IV_COUNTER_WIDTH);
                else
                    iv_nonce <= iv_nonce;
                    if (increment_counter = '1') then
                        iv_counter <= STD_LOGIC_VECTOR(UNSIGNED(iv_counter) + 1);
                    else
                        iv_counter <= iv_counter;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    
    
    fifo_input_process : process(key_ready, tx_raw_keystream, fifo_tready, fifo_tvalid, keystream_tdata, keystream_tvalid, s_axis_tvalid, s_axis_tlast, s_axis_tdata)
    begin
        if (key_ready = '0') then
            s_axis_tready    <= '0';
            keystream_tready <= '1'; -- Drain the precomputed keystream stored in the AES engine
            
            fifo_tvalid      <= '0';
            fifo_tlast       <= '0';
            fifo_tdata       <= (others => '0');
        elsif (tx_raw_keystream = '1') then
            -- Ignore the plaintext input, and transmit the raw keystream on the output
            s_axis_tready    <= '0';
            -- Transparent pass-through from AES engine to the FIFO
            keystream_tready <= fifo_tready;
            fifo_tvalid      <= keystream_tvalid;
            fifo_tlast       <= '1'; -- Lock tlast to 1
            fifo_tdata       <= keystream_tdata;
        else
            -- Normal CTR operation: Ciphertext = plaintext xor keystream
            keystream_tready <= fifo_tready and fifo_tvalid;
            s_axis_tready    <= fifo_tready and fifo_tvalid;
            
            fifo_tvalid      <= s_axis_tvalid and keystream_tvalid;
            fifo_tlast       <= s_axis_tlast;
            fifo_tdata       <= s_axis_tdata xor keystream_tdata;
        end if;
    end process;
    
    
end behavioral;
