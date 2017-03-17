library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.nonogram_package.all;

entity datapath is

	port
	(
		CLOCK					: 	in std_logic;
		RESET_N				: 	in std_logic;
		
		LEVEL					:	in integer range -1 to MAX_LEVEL - 1;
		ROW_INDEX			: 	in integer range 0 to MAX_COLUMN - 1;
		ROW_DESCRIPTION	:	out line_type;
		
		STATUS				:	in status_type;
		ACK					:	out status_type;
		
		ITERATION			:	out integer range 0 to MAX_ITERATION - 1;
		UNDEFINED_CELLS	:	out integer range 0 to MAX_ROW * MAX_COLUMN
	);

end datapath;

architecture RTL of datapath is

	--signals
	signal ack_register						: status_type;
	
	signal iteration_register				: integer range 0 to MAX_ITERATION - 1;
	signal undefined_cells_register		: integer range 0 to MAX_ROW * MAX_COLUMN;
	
	signal board								: board_type;
	
begin

	--processes
	row_description_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			ROW_DESCRIPTION <= (others => INVALID);
		elsif(rising_edge(CLOCK)) then
			if(ROW_INDEX >= LEVEL_INPUT(LEVEL).rows) then
				ROW_DESCRIPTION <= (others => INVALID);
			else
				ROW_DESCRIPTION <= get_board_line(board, 0, ROW_INDEX);
			end if;
		end if;
	end process;
	
	board_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			board <= (others => (others => INVALID));
			ACK <= IDLE;
		elsif(rising_edge(CLOCK)) then
			case(STATUS) is
				when IDLE =>
					ack_register <= IDLE;
				when LOAD =>	
					iteration_register <= 0;
					board <= load_board(LEVEL);
					--constrains <= constrains_load(LEVEL); TODO
					ack_register <= LOAD;
				when SOLVE_ITERATION =>
					
				when SOLVE_ALL =>
				
				when WON =>
				
				when LOST =>
				
			end case;
			
			ITERATION <= iteration_register;
			ACK <= ack_register;
		end if;
	end process;

end architecture;