library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use WORK.MATRIX_CONST.all;
use WORK.PACKAGE_ENCRYPTION_LUT.all;
use WORK.PACKAGE_ENCRYPTION_COMPONENT.all;

entity axis_register is
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
        m_axis_tready : in  std_logic
    );
end entity axis_register;

architecture behavioral of axis_register is
    signal data_register              : STD_LOGIC_vector(MATRIX_DATA_WIDTH downto 0);

    signal contains_data            : STD_LOGIC;

    signal s_axis_tready_internal   : STD_LOGIC;
    signal m_axis_tvalid_internal   : STD_LOGIC;
    
    signal receiving                : STD_LOGIC;
    signal transmitting             : STD_LOGIC;

begin
    receiving <= '1' when s_axis_tvalid = '1' and s_axis_tready_internal = '1' else '0';
    transmitting <= '1' when m_axis_tvalid_internal = '1' and m_axis_tready = '1' else '0';
    
    
    read_write_process : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                contains_data <= '0';
                data_register <= (others => '0');
            else
                if (receiving = '1') then
                    data_register(MATRIX_DATA_WIDTH - 1 downto 0) <= s_axis_tdata;
                    data_register(MATRIX_DATA_WIDTH) <= s_axis_tlast;
                    contains_data <= '1';
                elsif (transmitting = '1') then
                    contains_data <= '0';
                    data_register <= (others => '0');
                else
                    contains_data <= contains_data;
                    data_register <= data_register;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Outputs
    ------------------------------------------------------------------------
    
    s_axis_tready <= s_axis_tready_internal;
    m_axis_tvalid <= m_axis_tvalid_internal;
    
    
    s_axis_tready_internal <= '1' when contains_data = '0' or m_axis_tready = '1' else '0';
    
    m_axis_tvalid_internal <= contains_data;
    m_axis_tdata  <= data_register(MATRIX_DATA_WIDTH - 1 downto 0);
    m_axis_tlast  <= data_register(MATRIX_DATA_WIDTH);

end behavioral;
