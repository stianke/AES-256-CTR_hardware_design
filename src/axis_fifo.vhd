library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_ENCRYPTION_LUT.all;
use WORK.PACKAGE_ENCRYPTION_COMPONENT.all;

entity axis_fifo is
    generic (
        G_DEPTH      : integer := 4;
        ADDR_WIDTH   : integer := 2 -- ceil(log2(G_DEPTH))
    );
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;

        -- AXI4-Stream slave interface (input)
        s_axis_tdata  : in  std_logic_vector(MATRIX_DATA_WIDTH-1 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tlast  : in  std_logic;
        s_axis_tready : out std_logic;

        -- AXI4-Stream master interface (output)
        m_axis_tdata  : out std_logic_vector(MATRIX_DATA_WIDTH-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tlast  : out std_logic;
        m_axis_tready : in  std_logic;

        -- Status
        num_active_lanes : IN UNSIGNED(2 downto 0);
        fifo_has_space : OUT STD_LOGIC
    );
end entity axis_fifo;

architecture behavioral of axis_fifo is

    type fifo_array is array (0 to G_DEPTH-1) of STD_LOGIC_vector(MATRIX_DATA_WIDTH downto 0);
    signal fifo_buffer              : fifo_array;

    signal wr_ptr                   : UNSIGNED(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal rd_ptr                   : UNSIGNED(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal count                    : UNSIGNED(ADDR_WIDTH downto 0)   := (others => '0'); -- one extra bit

    signal s_axis_tready_internal   : STD_LOGIC;
    signal m_axis_tvalid_internal   : STD_LOGIC;
    
    signal receiving                : STD_LOGIC;
    signal transmitting             : STD_LOGIC;
    
    signal num_free_slots   : unsigned(ADDR_WIDTH downto 0);
begin
    receiving <= '1' when s_axis_tvalid = '1' and s_axis_tready_internal = '1' else '0';
    transmitting <= '1' when m_axis_tvalid_internal = '1' and m_axis_tready = '1' else '0';
    
    receive_logic : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr <= (others => '0');
                fifo_buffer <= (others => (others => '0'));
            else
                if (receiving = '1') then
                    fifo_buffer(to_integer(wr_ptr))(MATRIX_DATA_WIDTH - 1 downto 0) <= s_axis_tdata;
                    fifo_buffer(to_integer(wr_ptr))(MATRIX_DATA_WIDTH) <= s_axis_tlast;
                    wr_ptr <= wr_ptr + 1;
                else
                    wr_ptr <= wr_ptr;
                end if;
            end if;
        end if;
    end process;

    
    transmit_logic : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rd_ptr <= (others => '0');
            else
                if (transmitting = '1') then
                    rd_ptr <= rd_ptr + 1;
                end if;
            end if;
        end if;
    end process;
    
    
    
    count_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count <= (others => '0');
            else
                if    (receiving = '1' and transmitting = '0') then
                    count <= count + 1;
                elsif (receiving = '0' and transmitting = '1') then
                    count <= count - 1;
                else
                    count <= count;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Outputs
    ------------------------------------------------------------------------
    
    s_axis_tready <= s_axis_tready_internal;
    m_axis_tvalid <= m_axis_tvalid_internal;
    
    
    s_axis_tready_internal <= '1' when (count < G_DEPTH) else '0';
    
    m_axis_tvalid_internal <= '1' when (count > 0 or s_axis_tvalid = '1') else '0';
    m_axis_tdata  <= fifo_buffer(to_integer(rd_ptr))(MATRIX_DATA_WIDTH - 1 downto 0) when (count > 0) else s_axis_tdata;
    m_axis_tlast  <= fifo_buffer(to_integer(rd_ptr))(MATRIX_DATA_WIDTH) when (count > 0) else s_axis_tlast;

    num_free_slots <= to_unsigned(G_DEPTH, ADDR_WIDTH + 1) - count;
    
    
    tready_process: process(num_free_slots, num_active_lanes, transmitting)
    begin 
        if (num_free_slots > num_active_lanes) then
            fifo_has_space <= '1';
        elsif (num_free_slots = num_active_lanes and transmitting = '1') then
            fifo_has_space <= '1';
        else
            fifo_has_space <= '0';
        end if;
    end process;
end behavioral;
