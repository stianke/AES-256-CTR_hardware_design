library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_ENCRYPTION_LUT.all;
use WORK.PACKAGE_ENCRYPTION_COMPONENT.all;

entity encryption_top is
    port(
        -- System
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        
        -- Key Logic
        pi_round_keys_array : IN t_ROUND_KEYS;
        pi_key_ready : IN STD_LOGIC;
        
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
end encryption_top;

architecture behavioral of encryption_top is
-- FSM


signal reg_FSM_ROUND_CNT_EN : STD_LOGIC;
signal reg_FSM_SUB_BYTES_EN : STD_LOGIC;
signal reg_FSM_SHIFT_ROWS_EN : STD_LOGIC;
signal reg_FSM_MIX_COLUMNS_EN : STD_LOGIC;
signal reg_FSM_ADD_ROUND_KEY_EN : STD_LOGIC;
signal reg_FSM_ADD_ROUND_KEY_INPUT_SEL : STD_LOGIC_VECTOR(1 DOWNTO 0);

signal fifo_s_axis_tlast : STD_LOGIC;
signal fifo_s_axis_tvalid : STD_LOGIC;

signal downstream_fifo_free_slots : UNSIGNED(2 downto 0);

-- LOGIC
signal w_CNT_ROUND_NUM_IN : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal w_CNT_ROUND_NUM_OUT : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal w_KEY_SEL_ROUND_NUM : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal reg_SUB_BYTES_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal w_SUB_BYTES_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal reg_SHIFT_ROWS_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal w_SHIFT_ROWS_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal reg_MIX_COLUMNS_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal w_MIX_COLUMNS_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal reg_ADD_ROUND_KEY_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal w_ADD_ROUND_KEY_DATA_OUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal w_ADD_ROUND_KEY_INPUT : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal w_ADD_ROUND_KEY_INPUT_KEY : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);
signal reg_SHIFT_ROWS_DATA_OUT_DELAYED : STD_LOGIC_VECTOR(MATRIX_DATA_WIDTH-1 DOWNTO 0);

begin
    FSM_ENCRYPTION_INST_1: entity work.fsm_encryption
        port map(
            clk => clk,
            rst => rst,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast => s_axis_tlast,
            pi_key_ready => pi_key_ready,
            pi_round_num_incremented => w_CNT_ROUND_NUM_OUT,
            po_round_num_to_increment => w_CNT_ROUND_NUM_IN,
            po_key_sel_round_num => W_KEY_SEL_ROUND_NUM,
            po_data_valid => fifo_s_axis_tvalid,
            po_data_tlast => fifo_s_axis_tlast,
            po_round_cnt_en => reg_FSM_ROUND_CNT_EN,
            po_sub_bytes_en => reg_FSM_SUB_BYTES_EN,
            po_shift_rows_en => reg_FSM_SHIFT_ROWS_EN,
            po_mix_columns_en => reg_FSM_MIX_COLUMNS_EN,
            po_add_round_key_en => reg_FSM_ADD_ROUND_KEY_EN,
            po_add_round_key_mux => reg_FSM_ADD_ROUND_KEY_INPUT_SEL,
            downstream_fifo_free_slots => downstream_fifo_free_slots
        );
    
    KEYSTREAM_FIFO_INST_1: entity work.axis_fifo
        port map(
            clk => clk,
            rst => rst,
            s_axis_tdata => reg_ADD_ROUND_KEY_DATA_OUT,
            s_axis_tvalid => fifo_s_axis_tvalid,
            s_axis_tlast => fifo_s_axis_tlast,
            s_axis_tready => open, -- FSM_ENCRYPTION_INST_1 uses downstream_fifo_free_slots to make sure it does not generate more than the fifo has capacity for
            m_axis_tdata => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tlast => m_axis_tlast,
            m_axis_tready => m_axis_tready,
            po_free_slots => downstream_fifo_free_slots
        );
        
    CNT_16_INST_1: entity work.cnt_16
        port map(
            clk => clk,
            rst => rst,
            pi_enable => reg_FSM_ROUND_CNT_EN,
            po_data => w_CNT_ROUND_NUM_OUT,
            pi_data => w_CNT_ROUND_NUM_IN
        );
    
    SUB_BYTES_INST_1: entity work.sub_bytes
        port map(
            pi_data=> reg_ADD_ROUND_KEY_DATA_OUT,
            po_data=> w_SUB_BYTES_DATA_OUT
        );
    
    sub_bytes_reg_process: process(clk)
    begin
        if (rising_edge(clk))then
            if (rst = '1') then
                reg_SUB_BYTES_DATA_OUT <= (others => '0');
            elsif (reg_FSM_SUB_BYTES_EN = '1') then
                reg_SUB_BYTES_DATA_OUT <= w_SUB_BYTES_DATA_OUT;
            end if;
        end if;
    end process;
    
    SHIFT_ROWS_INST_1: entity work.shift_rows
        port map(
            pi_data=> reg_SUB_BYTES_DATA_OUT,
            po_data=> w_SHIFT_ROWS_DATA_OUT
        );
    
    shift_rows_reg_process: process(clk)
    begin
        if (rising_edge(clk))then
            if (rst = '1') then
                reg_SHIFT_ROWS_DATA_OUT <= (others => '0');
            elsif (reg_FSM_SHIFT_ROWS_EN = '1') then
                reg_SHIFT_ROWS_DATA_OUT <= w_SHIFT_ROWS_DATA_OUT;
            end if;
            
            reg_SHIFT_ROWS_DATA_OUT_DELAYED <= reg_SHIFT_ROWS_DATA_OUT;
        end if;
    end process;

    MIX_COLUMNS_INST_1: entity work.mix_columns
        port map(
            pi_data=> reg_SHIFT_ROWS_DATA_OUT,
            po_data=> w_MIX_COLUMNS_DATA_OUT
        );
    
    mix_columns_reg_process: process(clk)
    begin
        if (rising_edge(clk))then
            if (rst = '1') then
                reg_MIX_COLUMNS_DATA_OUT <= (others => '0');
            elsif (reg_FSM_MIX_COLUMNS_EN = '1') then
                reg_MIX_COLUMNS_DATA_OUT <= w_MIX_COLUMNS_DATA_OUT;
            end if;
        end if;
    end process;

    add_round_key_input_mux_process: process(reg_FSM_ADD_ROUND_KEY_INPUT_SEL, s_axis_tdata, reg_SHIFT_ROWS_DATA_OUT_DELAYED, reg_MIX_COLUMNS_DATA_OUT)
    begin
        case reg_FSM_ADD_ROUND_KEY_INPUT_SEL is
            when "00" => w_ADD_ROUND_KEY_INPUT <= s_axis_tdata;
            when "10" => w_ADD_ROUND_KEY_INPUT <= reg_SHIFT_ROWS_DATA_OUT_DELAYED;
            when others => w_ADD_ROUND_KEY_INPUT <= reg_MIX_COLUMNS_DATA_OUT;
        end case;
    end process;
    
    w_ADD_ROUND_KEY_INPUT_KEY <= pi_round_keys_array(to_integer(UNSIGNED(w_KEY_SEL_ROUND_NUM)));
    ADD_ROUND_KEY_INST_1: entity work.add_round_key
        port map(
            pi_data => w_ADD_ROUND_KEY_INPUT,
            pi_round_key => w_ADD_ROUND_KEY_INPUT_KEY,
            po_data => w_ADD_ROUND_KEY_DATA_OUT
        );
    
    add_round_key_reg_process: process(clk)
    begin
        if (rising_edge(clk))then
            if (rst = '1') then
                reg_ADD_ROUND_KEY_DATA_OUT <= (others => '0');
            elsif (reg_FSM_ADD_ROUND_KEY_EN = '1') then
                reg_ADD_ROUND_KEY_DATA_OUT <= w_ADD_ROUND_KEY_DATA_OUT;
            end if;
        end if;
    end process;


end behavioral;