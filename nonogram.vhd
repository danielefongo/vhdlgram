library IEEE;
 use IEEE.STD_LOGIC_1164.ALL;
 use IEEE.numeric_std.all;
 use work.vga_package.all;
 
entity nonogram is
   port
	(
		CLOCK_50            : in  std_logic;
		KEY                 : in  std_logic_vector(3 downto 0);
		LEDR					  : out std_logic_vector(17 downto 0);
		LEDG					  : out std_logic_vector(7 downto 0);
		
		SW                  : in  std_logic_vector(17 downto 0);
		VGA_R               : out std_logic_vector(7 downto 0);
		VGA_G               : out std_logic_vector(7 downto 0);
		VGA_B               : out std_logic_vector(7 downto 0);
		VGA_HS              : out std_logic;
		VGA_VS              : out std_logic;
		
		SRAM_ADDR           : out   std_logic_vector(19 downto 0);
		SRAM_DQ             : inout std_logic_vector(15 downto 0);
		SRAM_CE_N           : out   std_logic;
		SRAM_OE_N           : out   std_logic;
		SRAM_WE_N           : out   std_logic;
		SRAM_UB_N           : out   std_logic;
		SRAM_LB_N           : out   std_logic
	);
end nonogram;

architecture RTL of nonogram is

	-- Signal declaration
	signal clock		: std_logic;
	signal vga_clock	: std_logic;
	signal RESET_N		: std_logic;
	
begin
	
	pll: entity work.PLL
		port map
		(
				inclk0	=> CLOCK_50,
				c0			=> clock,
				c1			=> vga_clock
		);

end architecture;
 