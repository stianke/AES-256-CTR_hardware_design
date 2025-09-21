library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity cnt_16 is
    port(
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        pi_enable : IN STD_LOGIC;
        pi_data : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        po_data : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
end cnt_16;

architecture behavioral of cnt_16 is

begin
    cnt_16_process: process(pi_enable, pi_data)
    begin
        if (pi_enable = '1') then
            po_data <= STD_LOGIC_VECTOR( UNSIGNED(pi_data) + 1 );
        else
            po_data <= (others => '0');
        end if;
    end process;

end behavioral;
