library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.nonogram_package.all;

entity constraints_datapath is

	port
	(
		CLOCK									: 	in std_logic;
		RESET_N								: 	in std_logic;
		
		QUERY									:	in query_type;
		W_NOT_R								:	in std_logic;
		INPUT_LINE							:	in constraint_line_type;
		OUTPUT_LINE							:	out constraint_line_type;
		
		VIEW_QUERY							:	in query_type;
		VIEW_OUTPUT_LINE					:	out constraint_line_type
	);
	
end constraints_datapath;

architecture RTL of constraints_datapath is

	--SIGNALS
	signal constraints 						: constraint_matrix_type := (others => (others => (others => (-1, 0, 0))));
	
begin
	
	--PROCESSES
	query_process : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			constraints <= (others => (others => (others => (-1, 0, 0))));
		elsif(rising_edge(CLOCK)) then
			if(W_NOT_R = '1') then
				for i in 0 to MAX_CLUE_LINE - 1 loop
					constraints(QUERY.transposed, QUERY.index, i) <= INPUT_LINE(i);
				end loop;
			else
				for i in 0 to MAX_CLUE_LINE - 1 loop
					OUTPUT_LINE(i) <= constraints(QUERY.transposed, QUERY.index, i);
				end loop;
			end if;
		end if;
	end process;
	
	view_query_process : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
		elsif(rising_edge(CLOCK)) then
			for i in 0 to MAX_CLUE_LINE - 1 loop
				VIEW_OUTPUT_LINE(i) <= constraints(VIEW_QUERY.transposed, VIEW_QUERY.index, i);
			end loop;
		end if;
	end process;
	
end architecture;