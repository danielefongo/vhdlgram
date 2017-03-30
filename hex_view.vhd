library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nonogram_package.all;

entity hex_view is
	
	port 
	(
		CLOCK					: 	in std_logic;
		RESET_N				: 	in std_logic;
		
		ITERATION			:	in	integer range 0 to MAX_ITERATION;
		UNDEFINED_CELLS	:	in integer range 0 to MAX_LINE * MAX_LINE;
	
		HEX7					: out std_logic_vector(6 downto 0);
		HEX6					: out std_logic_vector(6 downto 0);
		HEX3					: out std_logic_vector(6 downto 0);
		HEX2					: out std_logic_vector(6 downto 0);
		HEX1					: out std_logic_vector(6 downto 0);
		HEX0					: out std_logic_vector(6 downto 0)
	);
	
	--TYPES
	subtype hex_digit	is std_logic_vector(6 downto 0);
	
	--FUNCTIONS
	function write_digit(N : integer range 0 to 9) return hex_digit;
	
end entity;

architecture RTL of hex_view is

	--FUNCTIONS
	function write_digit(N : integer range 0 to 9) return hex_digit is
		variable result : hex_digit := (others => '1');
	begin
		case(N) is
			when 0	=> 
				result := "1000000";
			when 1	=> 
				result := "1111001";
			when 2	=> 
				result := "0100100";
			when 3	=> 
				result := "0110000";
			when 4	=> 
				result := "0011001";
			when 5	=> 
				result := "0010010";
			when 6	=> 
				result := "0000010";
			when 7	=> 
				result := "1111000";
			when 8	=> 
				result := "0000000";
			when 9	=> 
				result := "0010000";
		end case;
		
		return result;
	end;

begin

	--PROCESSES
	iteration_write : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			HEX7 <= (others => '1');
			HEX6 <= (others => '1');
		elsif(rising_edge(CLOCK)) then
			if(ITERATION > 99) then
				HEX7 <= write_digit(9);
				HEX6 <= write_digit(9);
			else
				HEX7 <= write_digit(ITERATION / 10);
				HEX6 <= write_digit(ITERATION mod 10);
			end if;
			
		end if;
	end process;
	
	undefined_cells_write : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			HEX3 <= (others => '1');
			HEX2 <= (others => '1');
			HEX1 <= (others => '1');
			HEX0 <= (others => '1');
		elsif(rising_edge(CLOCK)) then
			HEX3 <= write_digit(UNDEFINED_CELLS / 1000);
			HEX2 <= write_digit((UNDEFINED_CELLS mod 1000) / 100);
			HEX1 <= write_digit((UNDEFINED_CELLS mod 100) / 10);
			HEX0 <= write_digit(UNDEFINED_CELLS mod 10);
		end if;
	end process;
	
end architecture;