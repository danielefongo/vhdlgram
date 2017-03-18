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
		
		ITERATION			:	out integer range 0 to MAX_ITERATION;
		UNDEFINED_CELLS	:	out integer range 0 to MAX_ROW * MAX_COLUMN
	);

end datapath;

architecture RTL of datapath is

	--signals
	type solver_status_type is (S_IDLE, S_SOLVING, S_FINALIZING, S_CHECKING);
	signal solver_status_register			: solver_status_type := S_IDLE;
	
	signal ack_register						: status_type := IDLE;
	
	signal iteration_register				: integer range 0 to MAX_ITERATION;
	signal undefined_cells_register		: integer range 0 to MAX_ROW * MAX_COLUMN;
	
	signal board								: board_type;
	signal constraints 						: constraint_matrix_type;
	
begin

	--processes
	row_description_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			ROW_DESCRIPTION <= (others => INVALID);
		elsif(rising_edge(CLOCK)) then
			if(ROW_INDEX >= LEVEL_INPUT(LEVEL).dim(1)) then
				ROW_DESCRIPTION <= (others => INVALID);
			else
				ROW_DESCRIPTION <= get_board_line(board, 0, ROW_INDEX);
			end if;
		end if;
	end process;
	
	status_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			board <= (others => (others => INVALID));
			solver_status_register <= S_IDLE;
			ack_register <= IDLE;
			undefined_cells_register <= 0;
			iteration_register <= 0;
		elsif(rising_edge(CLOCK)) then
			case(STATUS) is
				when IDLE =>
					ack_register <= IDLE;
					undefined_cells_register <= get_undefined_cells(board);
				when LOAD =>	
					iteration_register <= 0;
					board <= load_board(LEVEL);
					constraints <= load_constraints(LEVEL);
					ack_register <= LOAD;
				when SOLVE_ITERATION =>
					case(solver_status_register) is
						when S_IDLE =>
							solver_status_register <= S_SOLVING;
						when S_SOLVING =>
							solver_status_register <= S_FINALIZING;
						when S_FINALIZING =>
							iteration_register <= iteration_register + 1;
							undefined_cells_register <= get_undefined_cells(board);
							solver_status_register <= S_CHECKING;
						when S_CHECKING =>
							solver_status_register <= S_IDLE;
							if(undefined_cells_register = 0) then
								ack_register <= WON;
							elsif(iteration_register >= MAX_ITERATION - 1) then
								ack_register <= LOST;
							else
								ack_register <= SOLVE_ITERATION;
							end if;
					end case;
				when SOLVE_ALL =>
					case(solver_status_register) is
						when S_IDLE =>
							solver_status_register <= S_SOLVING;
						when S_SOLVING =>
							solver_status_register <= S_FINALIZING;
						when S_FINALIZING =>
							iteration_register <= iteration_register + 1;
							undefined_cells_register <= get_undefined_cells(board);
							solver_status_register <= S_CHECKING;
						when S_CHECKING =>
							if(undefined_cells_register = 0) then
								ack_register <= WON;
								solver_status_register <= S_IDLE;
							elsif(iteration_register >= MAX_ITERATION - 1) then
								ack_register <= LOST;
								solver_status_register <= S_IDLE;
							else
								solver_status_register <= S_SOLVING;
							end if;
					end case;
				when WON | LOST =>
					ack_register <= ack_register;
			end case;

		end if;
		UNDEFINED_CELLS <= undefined_cells_register;
		ITERATION <= iteration_register;
		ACK <= ack_register;
	end process;

end architecture;