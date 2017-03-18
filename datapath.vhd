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
	type solver_status_type is (S_IDLE, S_ANALYZING, S_SIMPLE_BLOCKS, S_SIMPLE_SPACES, S_FINALIZING, S_CHECKING);
	signal solver_status_register			: solver_status_type := S_IDLE;
	
	signal ack_register						: status_type := IDLE;
	
	signal iteration_register				: integer range 0 to MAX_ITERATION;
	signal undefined_cells_register		: integer range 0 to MAX_ROW * MAX_COLUMN;
	
	signal board								: board_type;
	signal constraints 						: constraint_matrix_type;
	
	--procedures
	procedure solve_procedure(operation : integer range 0 to 1) is
	begin
		case(solver_status_register) is
			when S_IDLE =>
				solver_status_register <= S_ANALYZING;
			when S_ANALYZING =>
				solver_status_register <= S_SIMPLE_BLOCKS;
			when S_SIMPLE_BLOCKS =>
				solver_status_register <= S_SIMPLE_SPACES;
			when S_SIMPLE_SPACES =>
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
					if(operation = 0) then
						ack_register <= SOLVE_ITERATION;
						solver_status_register <= S_IDLE; 
					else
						solver_status_register <= S_ANALYZING;
					end if;
				end if;
		end case;
	end solve_procedure;
	
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
					undefined_cells_register <= get_undefined_cells(board);
					ack_register <= IDLE;
				when LOAD =>
					iteration_register <= 0;
					board <= load_board(LEVEL);
					constraints <= load_constraints(LEVEL);
					if(board(0,0) /= INVALID) then --TODO: remove asap
						ack_register <= LOAD;
					else
						ack_register <= IDLE;
					end if;
				when SOLVE_ITERATION =>
					solve_procedure(0);
				when SOLVE_ALL =>
					solve_procedure(1);
				when WON | LOST =>
					ack_register <= ack_register;
			end case;

		end if;
		UNDEFINED_CELLS <= undefined_cells_register;
		ITERATION <= iteration_register;
		ACK <= ack_register;
	end process;

end architecture;