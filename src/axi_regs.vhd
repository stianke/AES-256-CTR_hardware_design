library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_regs is
    Generic(
        ADDR_WIDTH : natural    := 12; -- Must be >= 2 and <= 30
        REGISTER_WIDTH : integer := 32 -- Do not change
    );    
    Port(
        -- Slave AXI-Lite interface
        s_axi_aclk              : in std_logic := '0';
        s_axi_aresetn           : in std_logic := '0';
        
        s_axi_awaddr            : in std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        s_axi_awvalid           : in std_logic := '0';
        s_axi_awready           : out std_logic := '0';
        
        s_axi_wdata             : in std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        s_axi_wvalid            : in std_logic := '0';
        s_axi_wready            : out std_logic := '0';
        
        s_axi_bresp             : out std_logic_vector(1 downto 0) := (others => '0');
        s_axi_bvalid            : out std_logic := '0';
        s_axi_bready            : in std_logic := '0';
        
        s_axi_araddr            : in std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
        s_axi_arvalid           : in std_logic := '0';
        s_axi_arready           : out std_logic := '0';
        
        s_axi_rdata             : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        s_axi_rvalid            : out std_logic := '0';
        s_axi_rready            : in std_logic := '0';
        s_axi_rresp             : out std_logic_vector(1 downto 0) := (others => '0');
        
        -- Read-Write registers
        control_register        : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_0              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_1              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_2              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_3              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_4              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_5              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_6              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        key_part_7              : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        iv_part_0               : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        iv_part_1               : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        iv_part_2               : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        iv_part_3               : out std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0');
        
        
        -- Read-only register
        status_register         : in std_logic_vector(REGISTER_WIDTH-1 downto 0) := (others => '0')
        
    );
end axi_regs;

architecture Behavioral of axi_regs is
    
    -- Number of registers
    constant NUM_REGS_MAX               : natural := 2**(ADDR_WIDTH-2); -- The registers not in use (outside 0 to NUM_REGISTERS_IN_USE-1 will be optimized away by the synthesiser) 
    constant NUM_REGISTERS_IN_USE       : natural := 14;
    
    -- Slave AXI-Lite state machine
    type S_AXI_STATES                   is (Wait_Addr, Wait_Read, Wait_Write, Wait_Bready);
    signal s_axi_state                  : S_AXI_STATES := Wait_Addr;
    signal s_axi_reg_nr                 : natural range 0 to NUM_REGISTERS_IN_USE-1 := 0; 

    -- Registers array
    type REGS_ARRAY                     is array (0 to NUM_REGISTERS_IN_USE-1) of std_logic_vector(REGISTER_WIDTH-1 downto 0);
    signal REGS                         : REGS_ARRAY := (others => (others => '0'));     
    
begin

check_num_cores : assert (NUM_REGISTERS_IN_USE <= NUM_REGS_MAX) report "ERROR: The address width specified for the AXI Lite interface is too low to contain all the registers." severity failure;

-- Slave AXI-Lite state machine
process(s_axi_aclk, s_axi_aresetn) begin
    if (s_axi_aresetn = '0') then
        s_axi_state <= Wait_Addr;
        s_axi_reg_nr <= 0;
    elsif rising_edge(s_axi_aclk) then
        case s_axi_state is

            -- Wait for s_axi_awvalid or s_axi_arvalid      
            when Wait_Addr =>
                if (s_axi_awvalid = '1') then
                    s_axi_state <= Wait_Write;
                    s_axi_reg_nr <= to_integer(unsigned(s_axi_awaddr(ADDR_WIDTH-1 downto 2))); -- Divide by 4 to get the reg number from AXI addr
                elsif (s_axi_arvalid = '1') then
                    s_axi_state <= Wait_Read;
                    s_axi_reg_nr <= to_integer(unsigned(s_axi_araddr(ADDR_WIDTH-1 downto 2))); -- Divide by 4 to get the reg number from AXI addr
                end if;

            -- Do the read
            when Wait_Read =>
                if (s_axi_rready = '1') then
                    s_axi_state <= Wait_Addr;
                end if;

            -- Do the write
            when Wait_Write =>
                if (s_axi_wvalid = '1') then
                    s_axi_state <= Wait_Bready;
                end if;
            
            when Wait_Bready =>
                if (s_axi_bready = '1') then
                    s_axi_state <= Wait_Addr;
                end if;

        end case;
    end if;
end process;

-- Slave AXI-Lite outputs
s_axi_awready 	<= '1' when (s_axi_state = Wait_Addr) else '0';
s_axi_wready 	<= '1' when (s_axi_state = Wait_Write) else '0';
s_axi_arready 	<= '1' when ((s_axi_state = Wait_Addr) and (s_axi_awvalid = '0')) else '0'; -- Prioritize write access
s_axi_rvalid 	<= '1' when (s_axi_state = Wait_Read) else '0';
s_axi_bvalid    <= '1' when (s_axi_state = Wait_Bready) else '0';





-- Read-Write registers
process(s_axi_aclk, s_axi_aresetn) begin
    if (s_axi_aresetn = '0') then
        REGS(0)  <= (others => '0');
        
        REGS(2)  <= (others => '0');
        REGS(3)  <= (others => '0');
        REGS(4)  <= (others => '0');
        REGS(5)  <= (others => '0');
        REGS(6)  <= (others => '0');
        REGS(7)  <= (others => '0');
        REGS(8)  <= (others => '0');
        REGS(9)  <= (others => '0');
        REGS(10) <= (others => '0');
        REGS(11) <= (others => '0');
        REGS(12) <= (others => '0');
        REGS(13) <= (others => '0');
        
        s_axi_bresp <= (others => '0');
    elsif rising_edge(s_axi_aclk) then
    
        -- Read-Only Status Register REGS(1) at address 0x04
        REGS(1) <= status_register; -- 0x04
        
        if ((s_axi_state = Wait_Write) and (s_axi_wvalid = '1')) then
            if (s_axi_reg_nr < NUM_REGISTERS_IN_USE and s_axi_reg_nr /= 1) then
                REGS(s_axi_reg_nr) <= s_axi_wdata;
                
                s_axi_bresp <= "00"; -- Signal that Write transaction went OK
            else
                s_axi_bresp <= "10"; -- SLVERR: Signal that Write transaction failed (invalid address)
            end if;
        end if;
    end if;
end process;


control_register    <= REGS(0);  -- 0x00

key_part_0          <= REGS(2);  -- 0x08
key_part_1          <= REGS(3);  -- 0x0C
key_part_2          <= REGS(4);  -- 0x10
key_part_3          <= REGS(5);  -- 0x14
key_part_4          <= REGS(6);  -- 0x18
key_part_5          <= REGS(7);  -- 0x1C
key_part_6          <= REGS(8);  -- 0x20
key_part_7          <= REGS(9);  -- 0x24
iv_part_0           <= REGS(10); -- 0x28
iv_part_1           <= REGS(11); -- 0x2C
iv_part_2           <= REGS(12); -- 0x30
iv_part_3           <= REGS(13); -- 0x34




process(s_axi_aclk, s_axi_aresetn) begin
    if (s_axi_aresetn = '0') then
        s_axi_rresp <= (others => '0');
        s_axi_rdata <= (others => '0');
    elsif rising_edge(s_axi_aclk) then
        if (s_axi_state = Wait_Read) then
            if (s_axi_reg_nr >= 0 and s_axi_reg_nr < NUM_REGISTERS_IN_USE) then
                s_axi_rresp <= "00"; -- Signal that Read transaction went OK
                s_axi_rdata <=  REGS(s_axi_reg_nr);
            else
                s_axi_rresp <= "10"; -- SLVERR: Signal that Read transaction failed (invalid address)
                s_axi_rdata <= (others => '0');
            end if;
        end if;
    end if;
end process;



end Behavioral;