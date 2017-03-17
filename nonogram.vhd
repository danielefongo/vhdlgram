library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.nonogram_package.all;
 
entity nonogram is

   port
	(
		CLOCK_50            	: in  std_logic;
		
		SW                  	: in  std_logic_vector(17 downto 0);
		
		KEY                 	: in  std_logic_vector(3 downto 0);
				
		VGA_R               	: out std_logic_vector(7 downto 0);
		VGA_G               	: out std_logic_vector(7 downto 0);
		VGA_B               	: out std_logic_vector(7 downto 0);
		VGA_HS              	: out std_logic;
		VGA_VS              	: out std_logic;
		VGA_SYNC_N				: out std_logic;
		VGA_BLANK_N				: out std_logic;
		VGA_CLK					: out std_logic;
		
		HEX7						: out std_logic_vector(6 to 0);
		HEX6						: out std_logic_vector(6 to 0);
		HEX3						: out std_logic_vector(6 to 0);
		HEX2						: out std_logic_vector(6 to 0);
		HEX1						: out std_logic_vector(6 to 0);
		HEX0						: out std_logic_vector(6 to 0);
		
		LERG						: out std_logic_vector(8 to 0);
		LEDR						: out std_logic_vector(17 to 0)
	);
	
end nonogram;

architecture RTL of nonogram is

	-- Signal declaration
	signal clock					: std_logic;
	signal vga_clock				: std_logic;
	signal reset_n					: std_logic;
	signal reset_sync				: std_logic;
	signal level					: integer range 0 to MAX_LEVEL - 1;
	signal status					: status_type;
	signal ack						: status_type;
	signal row_index				: integer range 0 to MAX_COLUMN - 1;
	signal row_description		: line_type;
	signal iteration				: integer range 0 to MAX_ITERATION - 1;
	signal undefined_cells		: integer range 0 to MAX_ROW * MAX_COLUMN - 1;
	
begin
	
	--entities
	pll: entity work.PLL
		port map
		(
				inclk0	=> CLOCK_50,
				c0			=> clock,
				c1			=> vga_clock
		);
	
	-- processes
	reset : process(clock)
	begin
		if(rising_edge(clock)) then
			reset_sync <= SW(0);
			reset_n <= reset_sync;
		end if;
	end process;
	
	vga_clock_forward : process(vga_clock)
	begin
		VGA_CLK <= vga_clock;
	end process;
		
end architecture;
 