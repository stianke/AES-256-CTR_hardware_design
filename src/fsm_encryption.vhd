library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;

entity fsm_encryption is
    port(
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        pi_key_ready : IN STD_LOGIC;
        pi_round_num_incremented : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        po_round_num_to_increment : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        po_key_sel_round_num : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        po_round_cnt_en : OUT STD_LOGIC;
        po_sub_bytes_en : OUT STD_LOGIC;
        po_shift_rows_en : OUT STD_LOGIC;
        po_mix_columns_en : OUT STD_LOGIC;
        po_add_round_key_en : OUT STD_LOGIC;
        po_add_round_key_mux : OUT STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tvalid: IN STD_LOGIC;
        s_axis_tlast: IN STD_LOGIC;
        po_data_valid : OUT STD_LOGIC;
        po_data_tlast : OUT STD_LOGIC;
        downstream_fifo_free_slots : IN UNSIGNED(2 downto 0)
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


signal reg_NEXT_VAL_REQ_SQ : STD_LOGIC;
signal reg_ENC_DONE : STD_LOGIC;

signal reg_ROUND_CNT_EN : STD_LOGIC;
signal reg_SUB_BYTES_EN : STD_LOGIC;
signal reg_SHIFT_ROWS_EN : STD_LOGIC;
signal reg_MIX_COLUMNS_EN : STD_LOGIC;
signal reg_ADD_ROUND_KEY_EN : STD_LOGIC;
signal reg_ADD_ROUND_KEY_MUX : STD_LOGIC;
signal reg_S_AXIS_TREADY : STD_LOGIC;
signal reg_PO_DATA_TLAST : STD_LOGIC;
signal reg_ROUND_NUM_TO_INCREMENT : STD_LOGIC_VECTOR(3 downto 0);
signal reg_KEY_SEL_ROUND_NUM : STD_LOGIC_VECTOR(3 downto 0);

type roundnum_array is array (0 to 3) of STD_LOGIC_VECTOR(3 downto 0);
signal reg_LANES_ROUND_NUM : roundnum_array;
signal clock_phase : UNSIGNED(1 DOWNTO 0);

signal reg_LANES_TLAST : STD_LOGIC_VECTOR(3 downto 0);

signal pr_sub_bytes_lane : UNSIGNED(1 DOWNTO 0);
signal pr_shift_rows_lane : UNSIGNED(1 DOWNTO 0);
signal pr_mix_columns_lane : UNSIGNED(1 DOWNTO 0);
signal pr_add_round_key_lane : UNSIGNED(1 DOWNTO 0);

signal nx_sub_bytes_lane : UNSIGNED(1 DOWNTO 0);
signal nx_shift_rows_lane : UNSIGNED(1 DOWNTO 0);
signal nx_mix_columns_lane : UNSIGNED(1 DOWNTO 0);
signal nx_add_round_key_lane : UNSIGNED(1 DOWNTO 0);

signal num_active_lanes : UNSIGNED(2 DOWNTO 0);

begin
    -- Start encrypting job when both reg_S_AXIS_TREADY and s_axis_tvalid are high simultaneously
    reg_NEXT_VAL_REQ_SQ <= (reg_S_AXIS_TREADY and s_axis_tvalid);
    
    fsm_process: process(clk)
    begin 
        if (rising_edge(clk)) then
            if (rst = '1') then
                clock_phase <= "00";
            else
                clock_phase <= clock_phase + 1;
            end if;
        end if;
    end process;
    
    lane_slotting : process(clock_phase)
    begin 
        case to_integer(clock_phase) is
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
    nx_sub_bytes_lane     <= pr_add_round_key_lane;
    nx_shift_rows_lane    <= pr_sub_bytes_lane;
    nx_mix_columns_lane   <= pr_shift_rows_lane;
    nx_add_round_key_lane <= pr_mix_columns_lane;
    
    
    
    num_active_lanes_process: process(clk)
    begin 
        if (rising_edge(clk)) then
            if (rst = '1') then
                num_active_lanes <= to_unsigned(0, 3);
            else
                if (reg_NEXT_VAL_REQ_SQ = '1' and reg_ENC_DONE = '1') then
                    num_active_lanes <= num_active_lanes;
                elsif (reg_NEXT_VAL_REQ_SQ = '1') then
                    num_active_lanes <= num_active_lanes + 1;
                elsif (reg_ENC_DONE = '1') then
                    num_active_lanes <= num_active_lanes - 1;
                else
                    num_active_lanes <= num_active_lanes;
                end if;
            end if;
        end if;
    end process;
    
    input_process: process(reg_LANES_ROUND_NUM, pr_add_round_key_lane, pi_key_ready, downstream_fifo_free_slots, num_active_lanes)
    begin 
        if (reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) = "0000" and pi_key_ready = '1' and downstream_fifo_free_slots > num_active_lanes) then
            reg_S_AXIS_TREADY <= '1';
        else
            reg_S_AXIS_TREADY <= '0';
        end if;
    end process;
    
    round_number_comb_process: process(reg_LANES_ROUND_NUM, nx_add_round_key_lane)
    begin
        reg_ROUND_NUM_TO_INCREMENT <= reg_LANES_ROUND_NUM(to_integer(nx_add_round_key_lane));
        
        if (reg_LANES_ROUND_NUM(to_integer(nx_add_round_key_lane)) = "1110") then
            reg_ROUND_CNT_EN <= '0'; -- Reset to zero when finished with AES-block
        else
            reg_ROUND_CNT_EN <= '1';
        end if;
    end process;
    
    round_numer_seq_process: process(clk)
    begin
    if (rising_edge(clk)) then
        if (rst = '1') then
            reg_LANES_ROUND_NUM(0) <= "0000";
            reg_LANES_ROUND_NUM(1) <= "0000";
            reg_LANES_ROUND_NUM(2) <= "0000";
            reg_LANES_ROUND_NUM(3) <= "0000";
        else
            if (reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) = "0000" and reg_NEXT_VAL_REQ_SQ = '0') then
                reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) <= "0000"; -- Retain zero-value when not used
            else
                reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) <= pi_round_num_incremented;
            end if;
        end if;
    end if;
    end process;
    
    
    
    tlast_buffer_seq_process: process(clk)
    begin
    if (rising_edge(clk)) then
        if (rst = '1') then
            reg_LANES_TLAST <= "0000";
        else
            reg_LANES_TLAST <= reg_LANES_TLAST;
                    
            if (reg_NEXT_VAL_REQ_SQ = '1') then
                reg_LANES_TLAST(to_integer(pr_add_round_key_lane)) <= s_axis_tlast;
            end if;
        end if;
    end if;
    end process;
    
    
    
    
    fsm_output_process: process(reg_LANES_ROUND_NUM, pr_sub_bytes_lane, pr_shift_rows_lane, pr_mix_columns_lane, pr_add_round_key_lane, reg_NEXT_VAL_REQ_SQ)
    begin
        
        if (reg_LANES_ROUND_NUM(to_integer(pr_sub_bytes_lane)) = "0000") then
            reg_SUB_BYTES_EN <= '0';
        else
            reg_SUB_BYTES_EN <= '1';
        end if;
        
        if (reg_LANES_ROUND_NUM(to_integer(pr_shift_rows_lane)) = "0000") then
            reg_SHIFT_ROWS_EN <= '0';
        else
            reg_SHIFT_ROWS_EN <= '1';
        end if;
        
        
        if (reg_LANES_ROUND_NUM(to_integer(pr_mix_columns_lane)) = "0000" or reg_LANES_ROUND_NUM(to_integer(pr_mix_columns_lane)) = "1110") then
            reg_MIX_COLUMNS_EN <= '0';
        else
            reg_MIX_COLUMNS_EN <= '1';
        end if;
                
        if (reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) = "0000" and reg_NEXT_VAL_REQ_SQ = '0') then
            reg_ADD_ROUND_KEY_EN <= '0';
        else
            reg_ADD_ROUND_KEY_EN <= '1';
        end if;
        reg_KEY_SEL_ROUND_NUM <= reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane));
                
    end process;
    
    add_round_key_mux_process: process(reg_LANES_ROUND_NUM, pr_add_round_key_lane)
    begin
        case reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) is
            when "0000" => reg_ADD_ROUND_KEY_MUX <= '0'; -- s_axis_tdata
            when others => reg_ADD_ROUND_KEY_MUX <= '1'; -- reg_MIX_COLUMNS_DATA
        end case;
    end process;


    out_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1') then
                reg_ENC_DONE <= '0';
                reg_PO_DATA_TLAST <= '0';
            elsif (reg_LANES_ROUND_NUM(to_integer(pr_add_round_key_lane)) = "1110") then
                reg_ENC_DONE <= '1';
                reg_PO_DATA_TLAST <= reg_LANES_TLAST(to_integer(pr_add_round_key_lane));
            else
                reg_ENC_DONE <= '0';
                reg_PO_DATA_TLAST <= '0';
            end if;
        end if;
    end process;
    
    -- Output assignments
    
    po_data_valid               <= reg_ENC_DONE;
    po_round_cnt_en             <= reg_ROUND_CNT_EN;
    po_round_num_to_increment   <= reg_ROUND_NUM_TO_INCREMENT;
    po_sub_bytes_en             <= reg_SUB_BYTES_EN;
    po_shift_rows_en            <= reg_SHIFT_ROWS_EN;
    po_mix_columns_en           <= reg_MIX_COLUMNS_EN;
    po_add_round_key_en         <= reg_ADD_ROUND_KEY_EN;
    po_add_round_key_mux        <= reg_ADD_ROUND_KEY_MUX;
    s_axis_tready               <= reg_S_AXIS_TREADY;
    po_data_tlast               <= reg_PO_DATA_TLAST;
    po_key_sel_round_num        <= reg_KEY_SEL_ROUND_NUM;

end behavioral;