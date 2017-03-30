library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.nonogram_package.all;

entity board_datapath is

	port
	(
		CLOCK									: 	in std_logic;
		RESET_N								: 	in std_logic;
		
		QUERY									:	in query_type;
		W_NOT_R								:	in std_logic;
		INPUT_LINE							:	in line_type;
		OUTPUT_LINE							:	out line_type;
		
		VIEW_QUERY							:	in query_type;
		VIEW_OUTPUT_LINE					:	out line_type;
	
		UNDEFINED_CELLS 					:  out integer range 0 to MAX_LINE * MAX_LINE
	);
	
	--FUNCTIONS
	function get_board_line(board : board_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return line_type;
	
end board_datapath;

architecture RTL of board_datapath is

	--SIGNALS
	signal board 						: board_type := (others => (others => INVALID));
	
	--FUNCTIONS
	function get_board_line(board : board_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return line_type is
		variable result : line_type := (others => INVALID);
	begin
		for i in 0 to MAX_LINE - 1 loop
			if(transposed = 0 and i < MAX_LINE) then
				result(i) := board(i, index);
			elsif(transposed = 1 and i < MAX_LINE) then
				result(i) := board(index, i);
			end if;
		end loop;
		return result;
	end function;
	
begin 

	--PROCESSES
	query_process : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			board <= (others => (others => INVALID));
		elsif(rising_edge(CLOCK)) then
			if(W_NOT_R = '1') then
				for i in 0 to MAX_LINE - 1 loop
					if(QUERY.transposed = 0) then
						board(i, QUERY.index) <= INPUT_LINE(i);
					elsif(QUERY.transposed = 1) then
						board(QUERY.index, i) <= INPUT_LINE(i);
					end if;
				end loop;
			else
				OUTPUT_LINE <= get_board_line(board, QUERY.transposed, QUERY.index);
			end if;
		end if;
	end process;
	
	view_query_process : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
		elsif(rising_edge(CLOCK)) then
			VIEW_OUTPUT_LINE <= get_board_line(board, VIEW_QUERY.transposed, VIEW_QUERY.index);
		end if;
	end process;
	
	undefined_cells_process : process(CLOCK, RESET_N)
		variable result : integer range 0 to MAX_LINE * MAX_LINE := 0;
	begin
		if(RESET_N = '0') then
			UNDEFINED_CELLS <= 0;
		elsif(rising_edge(CLOCK)) then
			result := 0;
			for x in 0 to MAX_LINE - 1 loop
				for y in 0 to MAX_LINE - 1 loop
					if(board(x, y) = UNDEFINED) then
						result := result + 1;
					end if;
				end loop;
			end loop;
			UNDEFINED_CELLS <= result;
		end if;
	end process;
	
end architecture;