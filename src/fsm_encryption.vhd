library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;

entity fsm_encryption is
    generic (
        NUM_ROUNDS              : integer := 15;
        ROUND_INEDX_WIDTH       : integer := 4;
        CONTAINS_INITIAL_ROUND  : boolean := True;
        CONTAINS_FINAL_ROUND    : boolean := True
    );
    port(
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        pi_key_ready : IN STD_LOGIC;
        po_key_sel_round_num : OUT STD_LOGIC_VECTOR(ROUND_INEDX_WIDTH-1 DOWNTO 0);
        po_sub_bytes_en : OUT STD_LOGIC;
        po_shift_rows_en : OUT STD_LOGIC;
        po_mix_columns_en : OUT STD_LOGIC;
        po_add_round_key_en : OUT STD_LOGIC;
        po_add_round_key_mux : OUT STD_LOGIC;
        po_sub_bytes_mux : OUT STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tvalid: IN STD_LOGIC;
        s_axis_tlast: IN STD_LOGIC;
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tlast : OUT STD_LOGIC;
        m_axis_tready: IN STD_LOGIC;
        po_freeze_operation : OUT STD_LOGIC
    );
end fsm_encryption;

-- Denotes on which clock phase each lane has access to the devices
--              Lane 0      Lane 1      Lane 2      Lane 3
-- SubBytes     00          01          10          11
-- ShiftRows    11          00          01          10
-- MixColumns   10          11          00          01
-- AddRoundKey  01          10          11          00

architecture behavioral of fsm_encryption is
-- Custom Types


-- Signals


signal w_next_value_incoming : STD_LOGIC;
signal w_ENC_DONE : STD_LOGIC;


signal w_SUB_BYTES_EN : STD_LOGIC;
signal w_SHIFT_ROWS_EN : STD_LOGIC;
signal w_MIX_COLUMNS_EN : STD_LOGIC;
signal w_ADD_ROUND_KEY_EN : STD_LOGIC;
signal w_ADD_ROUND_KEY_MUX : STD_LOGIC;
signal w_SUB_BYTES_MUX : STD_LOGIC;
signal w_S_AXIS_TREADY : STD_LOGIC;
signal reg_PO_DATA_TLAST : STD_LOGIC;
signal w_KEY_SEL_ROUND_NUM : STD_LOGIC_VECTOR(ROUND_INEDX_WIDTH-1 downto 0);

type roundnum_array is array (0 to 3) of STD_LOGIC_VECTOR(ROUND_INEDX_WIDTH-1 downto 0);
signal reg_LANES_ROUND_NUM : roundnum_array;
signal reg_clock_phase : UNSIGNED(1 DOWNTO 0);

signal reg_LANES_TLAST : STD_LOGIC_VECTOR(3 downto 0);
signal reg_LANE_ACTIVE : STD_LOGIC_VECTOR(3 downto 0);

signal pr_sub_bytes_lane : UNSIGNED(1 DOWNTO 0);
signal pr_shift_rows_lane : UNSIGNED(1 DOWNTO 0);
signal pr_mix_columns_lane : UNSIGNED(1 DOWNTO 0);
signal pr_add_round_key_lane : UNSIGNED(1 DOWNTO 0);

signal w_FREEZE_OPERATION : STD_LOGIC;
signal reg_M_AXIS_TVALID : STD_LOGIC;

signal w_round_num_incremented : STD_LOGIC_VECTOR(ROUND_INEDX_WIDTH-1 DOWNTO 0);

begin
    -- Start encrypting job when both w_S_AXIS_TREADY and s_axis_tvalid are high simultaneously
    w_next_value_incoming <= (w_S_AXIS_TREADY and s_axis_tvalid and not w_FREEZE_OPERATION);
    w_FREEZE_OPERATION <= reg_M_AXIS_TVALID and not m_axis_tready;
    
    
    fsm_process: process(clk)
    begin 
        if (rising_edge(clk)) then
            if (rst = '1') then
                reg_clock_phase <= "00";
            elsif (w_FREEZE_OPERATION = '1') then
                reg_clock_phase <= reg_clock_phase;
            else
                reg_clock_phase <= reg_clock_phase + 1;
            end if;
        end if;
    end process;
    
    lane_slotting : process(reg_clock_phase)
    begin 
        case to_integer(reg_clock_phase) is
            when 0 =>
                pr_sub_bytes_lane     <= to_unsigned(0, 2);
                pr_shift_rows_lane    <= to_unsigned(1, 2);
                pr_mix_columns_lane   <= to_unsigned(2, 2);
                pr_add_round_key_lane <= to_unsigned(3, 2);
            when 1 =>
                pr_sub_bytes_lane     <= to_unsigned(3, 2);
                pr_shift_rows_lane    <= to_unsigned(0, 2);
                pr_mix_columns_lane   <= to_unsigned(1, 2);
                pr_add_round_key_lane <= to_unsigned(2, 2);
            when 2 =>
                pr_sub_bytes_lane     <= to_unsigned(2, 2);
                pr_shift_rows_lane    <= to_unsigned(3, 2);
                pr_mix_columns_lane   <= to_unsigned(0, 2);
                pr_add_round_key_lane <= to_unsigned(1, 2);
             when others =>
                pr_sub_bytes_lane     <= to_unsigned(1, 2);
                pr_shift_rows_lane    <= to_unsigned(2, 2);
                pr_mix_columns_lane   <= to_unsigned(3, 2);
                pr_add_round_key_lane <= to_unsigned(0, 2);
        end case;
    end process;
    
    
    lane_active_flags_process: process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                reg_LANE_ACTIVE <= (others => '0');
            else
                reg_LANE_ACTIVE <= reg_LANE_ACTIVE;
                
                if (w_ENC_DONE = '1' and not w_FREEZE_OPERATION = '1') then
                    reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) <= '0';
                elsif (w_next_value_incoming = '1' and CONTAINS_INITIAL_ROUND) then
                    reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) <= '1';
                end if;
                
                if (w_next_value_incoming = '1' and not CONTAINS_INITIAL_ROUND) then
                    reg_LANE_ACTIVE(to_integer(pr_sub_bytes_lane)) <= '1';
                end if;
            end if;
        end if;
    end process;
    
    
    
    tready_process: process(reg_LANE_ACTIVE, pr_sub_bytes_lane, pr_add_round_key_lane, pi_key_ready, w_FREEZE_OPERATION)
    begin 
        if (pi_key_ready = '0' or w_FREEZE_OPERATION = '1') then
            w_S_AXIS_TREADY <= '0';
        elsif (CONTAINS_INITIAL_ROUND and reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) = '0') then
            w_S_AXIS_TREADY <= '1';
        elsif (not CONTAINS_INITIAL_ROUND and reg_LANE_ACTIVE(to_integer(pr_sub_bytes_lane)) = '0') then
            w_S_AXIS_TREADY <= '1';
        else
            w_S_AXIS_TREADY <= '0';
        end if;
    end process;
    
    
    w_round_num_incremented <= STD_LOGIC_VECTOR( UNSIGNED(reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane))) + 1 );
    
    round_numer_seq_process: process(clk)
    begin
    if (rising_edge(clk)) then
        if (rst = '1') then
            reg_LANES_ROUND_NUM <= (others => (others => '0'));
        else
            if (w_FREEZE_OPERATION = '1') then
                reg_LANES_ROUND_NUM <= reg_LANES_ROUND_NUM;
            elsif (reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) = std_logic_vector(to_unsigned(NUM_ROUNDS-1, ROUND_INEDX_WIDTH))) then
                reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) <= (others => '0');
            elsif (CONTAINS_INITIAL_ROUND and w_next_value_incoming = '1') then
                reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) <= w_round_num_incremented;
            elsif (reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) = '1') then
                reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) <= w_round_num_incremented;
            else
                reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) <= (others => '0'); -- Retain zero-value when not used
            end if;
        end if;
    end if;
    end process;
    
    
    
    tlast_buffer_seq_process: process(clk)
    begin
    if (rising_edge(clk)) then
        if (rst = '1') then
            reg_LANES_TLAST <= (others => '0');
        else
            if (w_next_value_incoming = '1') then
                reg_LANES_TLAST(to_integer(pr_add_round_key_lane)) <= s_axis_tlast;
            end if;
        end if;
    end if;
    end process;
    
    
    
    
    fsm_output_process: process(reg_LANE_ACTIVE, reg_LANES_ROUND_NUM, pr_sub_bytes_lane, pr_shift_rows_lane, pr_mix_columns_lane, pr_add_round_key_lane, w_next_value_incoming)
    begin
        
        if (reg_LANE_ACTIVE(to_integer(pr_sub_bytes_lane)) = '1' or (not CONTAINS_INITIAL_ROUND and w_next_value_incoming = '1')) then
            w_SUB_BYTES_EN <= '1';
        else
            w_SUB_BYTES_EN <= '0';
        end if;
        
        if (reg_LANE_ACTIVE(to_integer(pr_shift_rows_lane)) = '1') then
            w_SHIFT_ROWS_EN <= '1';
        else
            w_SHIFT_ROWS_EN <= '0';
        end if;
        
        
        if (reg_LANE_ACTIVE(to_integer(pr_mix_columns_lane)) = '0') then
            w_MIX_COLUMNS_EN <= '0';
        elsif (CONTAINS_FINAL_ROUND and reg_LANES_ROUND_NUM(to_integer(pr_mix_columns_lane)) = std_logic_vector(to_unsigned(NUM_ROUNDS-1, ROUND_INEDX_WIDTH))) then
            w_MIX_COLUMNS_EN <= '0';
        else
            w_MIX_COLUMNS_EN <= '1';
        end if;
                
        if (reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) = '1' or (CONTAINS_INITIAL_ROUND and w_next_value_incoming = '1')) then
            w_ADD_ROUND_KEY_EN <= '1';
        else
            w_ADD_ROUND_KEY_EN <= '0';
        end if;
        w_KEY_SEL_ROUND_NUM <= reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane));
    end process;
    
    add_round_key_mux_process: process(reg_LANE_ACTIVE, pr_add_round_key_lane)
    begin
        if (CONTAINS_INITIAL_ROUND and reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) = '0') then
            w_ADD_ROUND_KEY_MUX <= '0'; -- s_axis_tdata
        else
            w_ADD_ROUND_KEY_MUX <= '1'; -- reg_MIX_COLUMNS_DATA
        end if;
    end process;
    
    add_sub_bytes_mux_process: process(reg_LANE_ACTIVE, pr_sub_bytes_lane)
    begin
        if (not CONTAINS_INITIAL_ROUND and reg_LANE_ACTIVE(to_integer(pr_sub_bytes_lane)) = '0') then
            w_SUB_BYTES_MUX <= '0'; -- s_axis_tdata
        else
            w_SUB_BYTES_MUX <= '1'; -- reg_ADD_ROUND_KEY_DATA_OUT
        end if;
    end process;
    
    
    w_ENC_DONE <= '1' when reg_LANE_ACTIVE(to_integer(pr_add_round_key_lane)) = '1' and reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) = std_logic_vector(to_unsigned(NUM_ROUNDS-1, ROUND_INEDX_WIDTH)) else '0';
    
    out_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                reg_M_AXIS_TVALID <= '0';
                reg_PO_DATA_TLAST <= '0';
            elsif (w_ENC_DONE = '1' or w_FREEZE_OPERATION = '1') then
                reg_M_AXIS_TVALID <= '1';
                reg_PO_DATA_TLAST <= reg_LANES_TLAST(to_integer(pr_add_round_key_lane));
            else
                reg_M_AXIS_TVALID <= '0';
                reg_PO_DATA_TLAST <= '0';
            end if;
        end if;
    end process;
    
    -- Output assignments
    
    
    m_axis_tvalid               <= reg_M_AXIS_TVALID;
    m_axis_tlast                <= reg_PO_DATA_TLAST;
    s_axis_tready               <= w_S_AXIS_TREADY;
    po_freeze_operation         <= w_FREEZE_OPERATION;
    po_sub_bytes_en             <= w_SUB_BYTES_EN;
    po_shift_rows_en            <= w_SHIFT_ROWS_EN;
    po_mix_columns_en           <= w_MIX_COLUMNS_EN;
    po_add_round_key_en         <= w_ADD_ROUND_KEY_EN;
    po_add_round_key_mux        <= w_ADD_ROUND_KEY_MUX;
    po_sub_bytes_mux            <= w_SUB_BYTES_MUX;
    po_key_sel_round_num        <= w_KEY_SEL_ROUND_NUM;
    
end behavioral;