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
	
	function set_board_line(index : integer range 0 to MAX_LINE; input_line : line_type) return boolean;
	
end datapath;

architecture RTL of datapath is

	--signals
	type solver_status_type is (S_IDLE, S_ANALYZING, S_SIMPLE_BLOCKS, S_SIMPLE_SPACES, S_FINALIZING, S_CHECKING);
	signal solver_status_register			: solver_status_type := S_IDLE;
	
	type loader_status_type is (L_IDLE, L_LOADING, L_ACK);
	signal loader_status_register			: loader_status_type := L_IDLE;
	
	signal ack_register						: status_type := IDLE;
	
	signal iteration_register				: integer range 0 to MAX_ITERATION;
	signal undefined_cells_register		: integer range 0 to MAX_ROW * MAX_COLUMN;

	signal board								: board_type;
	signal constraints 						: constraint_matrix_type;
	signal transposed							: integer := 0;
	
	function set_board_line(index : integer range 0 to MAX_LINE; input_line : line_type) return boolean is
	begin
		for i in 0 to MAX_LINE loop
			if(transposed = 0 and i < MAX_ROW) then
				board(i, index) <= input_line(i);
			elsif(transposed = 1 and i < MAX_COLUMN) then
				board(index, i) <= input_line(i);
			end if;
		end loop;
		return true;
	end function;
	
	procedure simple_blocks(index : integer range 0 to MAX_LINE - 1) is
		variable tmp_line : line_type;
		variable check : boolean;
	begin
		if(LEVEL_INPUT(LEVEL).dim(1 - transposed) > index) then
			tmp_line := get_board_line(board, transposed, index);
			for i in 0 to MAX_CLUE_LINE - 1 loop
			if(constraints(transposed, index, i).size /= -1) then
				for j in 0 to MAX_LINE - 1 loop
				if(LEVEL_INPUT(LEVEL).dim(transposed) > j) then
					if(j >= constraints(transposed, index, i).max_end + 1 - constraints(transposed, index, i).size and 
						j < constraints(transposed, index, i).min_start + constraints(transposed, index, i).size) then
						tmp_line(j) := FULL;
					end if;
				end if;
				end loop;
			end if;
			end loop;
			check := set_board_line(index, tmp_line);
		end if;
	end simple_blocks;
	
	procedure simple_spaces(index : integer range 0 to MAX_LINE - 1) is
		variable last_clue_max_end : integer range 0 to MAX_LINE - 1 := 0;
		variable tmp_line : line_type;
		variable check : boolean;
	begin
		if(LEVEL_INPUT(LEVEL).dim(1 - transposed) > index) then
			tmp_line := get_board_line(board, transposed, index);
			for i in 0 to MAX_CLUE_LINE - 1 loop
			if(constraints(transposed, index, i).size /= -1) then
				for j in 0 to MAX_LINE - 1 loop
				if(LEVEL_INPUT(LEVEL).dim(transposed) > j) then
					if(j >= last_clue_max_end and j < constraints(transposed, index, i).min_start) then
						tmp_line(j) := EMPTY;
					end if;
				end if;
				end loop;
				last_clue_max_end := constraints(transposed, index, i).max_end + 1;
			end if;
			end loop;
			for j in 0 to MAX_LINE - 1 loop
				if(LEVEL_INPUT(LEVEL).dim(transposed) > j and j >= last_clue_max_end) then
					tmp_line(j) := EMPTY;
				end if;
			end loop;
			check := set_board_line(index, tmp_line);
		end if;
	end simple_spaces;

	--procedures
	procedure load_procedure is
	begin
		case(loader_status_register) is
			when L_IDLE =>
				ack_register <= IDLE;
				board <= load_board(LEVEL);
				constraints <= load_constraints(LEVEL);
				loader_status_register <= L_LOADING;
			when L_LOADING =>
				if(check_board(LEVEL, board) and check_constraints(LEVEL, constraints)) then
					loader_status_register <= L_ACK;
				else
					board <= load_board(LEVEL);
					constraints <= load_constraints(LEVEL);
					loader_status_register <= L_LOADING;
				end if;
			when L_ACK =>
				iteration_register <= 0;
				ack_register <= LOAD;
				loader_status_register <= L_IDLE;
		end case;
	end load_procedure;
	
	procedure solve_procedure(operation : integer range 0 to 1) is
	begin
		case(solver_status_register) is
			when S_IDLE =>
				solver_status_register <= S_ANALYZING;
			when S_ANALYZING =>
				solver_status_register <= S_SIMPLE_BLOCKS;
			when S_SIMPLE_BLOCKS =>
				for i in 0 to MAX_LINE - 1 loop
					simple_blocks(i);
				end loop;
				solver_status_register <= S_SIMPLE_SPACES;
			when S_SIMPLE_SPACES =>
				for i in 0 to MAX_LINE - 1 loop
					simple_spaces(i);
				end loop;
				solver_status_register <= S_FINALIZING;
			when S_FINALIZING =>
				iteration_register <= iteration_register + 1;
				transposed <= 1 - transposed;
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
			loader_status_register <= L_IDLE;
			ack_register <= IDLE;
			undefined_cells_register <= 0;
			iteration_register <= 0;
		elsif(rising_edge(CLOCK)) then
			case(STATUS) is
				when IDLE =>
					undefined_cells_register <= get_undefined_cells(board);
					solver_status_register <= S_IDLE;
					loader_status_register <= L_IDLE;
					ack_register <= IDLE;
				when LOAD =>
					load_procedure;
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