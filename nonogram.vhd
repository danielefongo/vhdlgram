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
		
		HEX7						: out std_logic_vector(6 downto 0);
		HEX6						: out std_logic_vector(6 downto 0);
		HEX3						: out std_logic_vector(6 downto 0);
		HEX2						: out std_logic_vector(6 downto 0);
		HEX1						: out std_logic_vector(6 downto 0);
		HEX0						: out std_logic_vector(6 downto 0);
		
		LEDG						: out std_logic_vector(8 downto 0);
		LEDR						: out std_logic_vector(17 downto 0)
	);
	
end nonogram;

architecture RTL of nonogram is

	-- Signal declaration
	signal clock					: std_logic;
	signal vga_clock				: std_logic;
	signal reset_n					: std_logic;
	signal reset_sync				: std_logic;
	signal level					: integer range -1 to MAX_LEVEL - 1;
	signal status					: status_type;
	signal ack						: status_type;
	signal row_index				: integer range 0 to MAX_COLUMN - 1;
	signal row_description		: line_type;
	signal iteration				: integer range 0 to MAX_ITERATION;
	signal undefined_cells		: integer range 0 to MAX_ROW * MAX_COLUMN;
	
begin
	
	--entities
	pll: entity work.PLL
		port map
		(
				inclk0	=> CLOCK_50,
				c0			=> clock,
				c1			=> vga_clock
		);
		
	vga_view : entity work.vga_view
		port map 
		(
			CLOCK						=> vga_clock,			
			RESET_N					=> reset_n,
			VGA_R						=> VGA_R,
			VGA_G						=> VGA_G,
			VGA_B						=> VGA_B,
			VGA_HS					=> VGA_HS,
			VGA_VS					=> VGA_VS,
			VGA_SYNC_N				=> VGA_SYNC_N,
			VGA_BLANK_N				=> VGA_BLANK_N,
			
			ROW_DESCRIPTION		=> row_description,
			ROW_INDEX				=> row_index,
			
			LEVEL						=> level,
			STATUS					=> status
		);
		
	hex_view : entity work.hex_view
		port map
		(
			CLOCK						=> vga_clock,			
			RESET_N					=> reset_n,
			
			ITERATION				=> iteration,
			UNDEFINED_CELLS		=> undefined_cells,

			HEX7						=> HEX7,
			HEX6						=> HEX6,
			HEX3						=> HEX3,
			HEX2						=> HEX2,
			HEX1						=> HEX1,
			HEX0						=> HEX0
		);
		
	controller : entity work.controller
		port map
		(
			CLOCK						=> clock,
			RESET_N					=> reset_n,
			
			SW							=> SW(17 downto 1),
			LEVEL						=> level,
			
			ACK						=> ack,
			STATUS					=> status,
			
			KEY						=> KEY(3 downto 2)
		);
	
	datapath : entity work.datapath
		port map
		(
			CLOCK						=> clock,
			RESET_N					=> reset_n,
			
			LEVEL						=> level,
			ROW_INDEX				=> row_index,
			ROW_DESCRIPTION		=> row_description,
			
			STATUS					=> status,
			ACK						=> ack,
			
			ITERATION				=> iteration,
			UNDEFINED_CELLS		=> undefined_cells
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
	
	--debugging
	led_debugging : process(clock, reset_n)
	begin
		if(reset_n = '0') then
			LEDG <= "000000000";
		elsif(rising_edge(clock)) then
			case(status) is
				when IDLE =>
					LEDG <= "010000000";
				when LOAD =>
					LEDG <= "001000000";
				when SOLVE_ITERATION =>
					LEDG <= "000100000";
				when SOLVE_ALL =>
					LEDG <= "000010000";
				when WON	=>
					LEDG <= "000001000";
				when LOST =>
					LEDG <= "000000100";
			end case;
		end if;
	end process;
		
end architecture;
 