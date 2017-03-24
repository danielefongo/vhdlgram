library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.nonogram_package.all;

entity datapath is

	port
	(
		CLOCK							: 	in std_logic;
		RESET_N						: 	in std_logic;
		
		LEVEL							:	in integer range -1 to MAX_LEVEL - 1;	
		STATUS						:	in status_type;
		ACK							:	out status_type;
			
		ITERATION					:	out integer range 0 to MAX_ITERATION;
		
		BOARD_QUERY					:	out query_type;
		BOARD_W_NOT_R				:	out std_logic;
		BOARD_INPUT_LINE			:  out line_type;
		BOARD_OUTPUT_LINE			:  in line_type;
		UNDEFINED_CELLS			:	in integer range 0 to MAX_LINE * MAX_LINE;
		
		CONSTRAINT_QUERY			:	out query_type;
		CONSTRAINT_W_NOT_R		:	out std_logic;
		CONSTRAINT_INPUT_LINE	:  out constraint_line_type;
		CONSTRAINT_OUTPUT_LINE	:  in constraint_line_type
	);
		
end datapath;

architecture RTL of datapath is
	
	signal transposed_register				: integer := 0;
	signal index_register						: integer := 0;
	signal iteration_register 				: integer range 0 to MAX_ITERATION;
	signal ack_register						: status_type := IDLE;
	signal w_clock_divisor					: integer := 0;
	
begin
	
	
	--PROCESSES
	status_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			ack_register <= IDLE;
			iteration_register <= 0;
			transposed_register <= 0;
			index_register <= 0;
			w_clock_divisor <= 0;
			BOARD_W_NOT_R <= '0';
			CONSTRAINT_W_NOT_R <= '0';
		elsif(rising_edge(CLOCK)) then
			case(STATUS) is
				when IDLE =>
					transposed_register <= 0;
					index_register <= 0;
					w_clock_divisor <= 0;
					BOARD_W_NOT_R <= '0';
					CONSTRAINT_W_NOT_R <= '0';
					ack_register <= IDLE;
				when LOAD =>
					if(w_clock_divisor = 0) then
						if(transposed_register = 0) then
							BOARD_QUERY.index <= index_register;
							BOARD_QUERY.transposed <= 0;
							BOARD_W_NOT_R <= '1';
							BOARD_INPUT_LINE <= load_board_row(LEVEL, index_register);
							
							CONSTRAINT_QUERY.index <= index_register;
							CONSTRAINT_QUERY.transposed <= 0;
							CONSTRAINT_W_NOT_R <= '1';
							CONSTRAINT_INPUT_LINE <= load_constraint_line(LEVEL, transposed_register, index_register);
						else
							CONSTRAINT_QUERY.index <= index_register;
							CONSTRAINT_QUERY.transposed <= 1;
							CONSTRAINT_W_NOT_R <= '1';
							CONSTRAINT_INPUT_LINE <= load_constraint_line(LEVEL, transposed_register, index_register);
						end if;
						w_clock_divisor <= w_clock_divisor + 1;
					elsif(w_clock_divisor < W_PERIOD) then
						w_clock_divisor <= w_clock_divisor + 1;
					else
						w_clock_divisor <= 0;
						BOARD_W_NOT_R <= '0';
						CONSTRAINT_W_NOT_R <= '0';
						if(transposed_register = 0) then
							if(index_register < MAX_LINE - 1) then
								index_register <= index_register + 1;
							else
								index_register <= 0;
								transposed_register <= 1;
							end if;
						else
							if(index_register < MAX_LINE - 1) then
								index_register <= index_register + 1;
							else
								index_register <= 0;
								transposed_register <= 0;
								ack_register <= LOAD;
							end if;
						end if;
					end if;
				when SOLVE_ITERATION =>
					--solve_procedure(0);
					ack_register <= SOLVE_ITERATION;
				when SOLVE_ALL =>
					--solve_procedure(1);
					ack_register <= SOLVE_ALL;
				when WON | LOST =>
					ack_register <= ack_register;
			end case;

		end if;
		ITERATION <= iteration_register;
		ACK <= ack_register;
	end process;
	
/*
	--signals
	type solver_status_type is (S_IDLE, S_ANALYZING, S_SIMPLE_BLOCKS, S_SIMPLE_SPACES, S_FINALIZING, S_CHECKING);
	signal solver_status_register			: solver_status_type := S_IDLE;
	
	type loader_status_type is (L_IDLE, L_LOADING, L_ACK);
	signal loader_status_register			: loader_status_type := L_IDLE;
	signal loader_ack							: std_logic_vector(MAX_LINE - 1 downto 0);
	
	
	
	
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
	
	--procedures
	procedure analyze(index : integer range 0 to MAX_LINE - 1) is
		variable tmp_line : line_type;
		variable available_size : integer := 0;
		variable clue_sum : integer := 0;
		variable current_clue : integer := 0;
		variable field_start : integer := -1;
		variable field_end : integer := -1;
		variable exit_analysis : boolean := false;
		variable exit_clues : boolean := false;
		variable block_found : boolean := false;
	begin
		if(LEVEL_INPUT(LEVEL).dim(1 - transposed) > index) then
			tmp_line := get_board_line(board, transposed, index);
			
			for i in 0 to MAX_LINE - 1 loop
			if(tmp_line(i) = FULL or tmp_line(i) = UNDEFINED) then
				available_size := available_size + 1;
			end if;
			end loop;
			
			for i in 0 to MAX_CLUE_LINE - 1 loop
			if(constraints(transposed, index, i).size /= -1) then
				clue_sum := clue_sum + constraints(transposed, index, i).size;
			end if;
			end loop;
			
			for i in 0 to MAX_LINE - 1 loop
			if(tmp_line(i) /= INVALID and exit_analysis = false) then
				case(tmp_line(i)) is
					when FULL =>
						block_found := true;
						if(field_start = -1) then
							field_start := i;
						end if;
						field_end := i;
					when UNDEFINED =>
						if(field_start = -1) then
							field_start := i;
						end if;
						field_end := i;
					when EMPTY =>
						exit_clues := false;
						if(field_start /= -1 and field_end /= -1) then
							for j in 0 to MAX_CLUE_LINE - 1 loop
							if(j >= current_clue and constraints(transposed, index, j).size /= -1 and exit_analysis = false and exit_clues = false) then
								if(field_end - field_start + 1 >= constraints(transposed, index, current_clue).size) then
									if(constraints(transposed, index, current_clue).min_start < field_start) then
										constraints(transposed, index, current_clue).min_start <= field_start;
									end if;
									
									if(block_found = false and available_size - (field_end - field_start + 1) >= clue_sum) then
										exit_analysis := true;
									else --univocal
										if(constraints(transposed, index, current_clue).max_end > field_end) then
											constraints(transposed, index, current_clue).max_end <= field_end;
										end if;
										
										if(field_end - field_start + 1 = constraints(transposed, index, current_clue).size) then
											available_size := available_size - constraints(transposed, index, current_clue).size;
										else
											available_size := available_size - constraints(transposed, index, current_clue).size - 1;
										end if;
										
										field_start := field_start + constraints(transposed, index, current_clue).size + 1;
										clue_sum := clue_sum - constraints(transposed, index, current_clue).size;
										current_clue := current_clue + 1;
										block_found := false;
										
										if(field_end - field_start < 0) then
											exit_clues := true;
										end if;
									end if;
								else
									exit_clues := true;
									available_size := available_size - (field_end - field_start + 1);
								end if;
							end if;
							end loop;
						end if;
						field_start := -1;
						field_end := -1;
						block_found := false;
					when others =>
				end case;
			end if;
			end loop;
		end if;
	end analyze;
	
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

	procedure load_procedure is
	begin
		case(loader_status_register) is
			when L_IDLE =>
				ack_register <= IDLE;
				board <= load_board(LEVEL);
				constraints <= load_constraints(LEVEL);
				loader_status_register <= L_LOADING;
			when L_LOADING =>
				if(check_board(LEVEL, board) and check_constraints(LEVEL, constraints)) then --and loader_ack = (loader_ack'range => '1')) then 
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
				line_register <= 0;
				solver_status_register <= S_ANALYZING;
			when S_ANALYZING =>
				analyze(line_register);
				solver_status_register <= S_SIMPLE_BLOCKS;
			when S_SIMPLE_BLOCKS =>
				simple_blocks(line_register);
				solver_status_register <= S_SIMPLE_SPACES;
			when S_SIMPLE_SPACES =>
				simple_spaces(line_register);
				solver_status_register <= S_FINALIZING;
			when S_FINALIZING =>
				if(line_register < MAX_LINE - 1) then
					line_register <= line_register + 1;
					solver_status_register <= S_ANALYZING;
				else
					iteration_register <= iteration_register + 1;
					transposed <= 1 - transposed;
					undefined_cells_register <= get_undefined_cells(board);
					solver_status_register <= S_CHECKING;
				end if;
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
	analyzers : for i in 0 to MAX_LINE - 1 generate
		analyzer : process(CLOCK, RESET_N)
			variable loader_ack_register : std_logic := '0';
			variable clue_line_length : integer := 0;
			variable left_clues_sum : integer;
			variable right_clues_sum : integer;
		begin
			if(RESET_N = '0') then
				loader_ack(i) <= '0';
				loader_ack_register := '0';
			elsif(rising_edge(CLOCK)) then
				if(loader_status_register = L_LOADING) then
					for t in 0 to 1 loop
						if(i < LEVEL_INPUT(LEVEL).dim(1 - t)) then
							
							clue_line_length := get_clue_line_length(level, t, i);
							left_clues_sum := 0;
							right_clues_sum := 0;
							
							for j in 0 to MAX_CLUE_LINE -1 loop
							if(j < clue_line_length) then
								right_clues_sum := right_clues_sum + LEVEL_INPUT(level).clues(t, i, j) + 1;
							end if;
							end loop;
								
							for j in 0 to MAX_CLUE_LINE -1 loop
							if(j < clue_line_length) then
								constraints(t, i, j).size <= LEVEL_INPUT(level).clues(t, i, j);
								
								right_clues_sum := right_clues_sum - LEVEL_INPUT(level).clues(t, i, j) - 1;
								
								constraints(t, i, j).min_start <= left_clues_sum;
								constraints(t, i, j).max_end <= LEVEL_INPUT(level).dim(t) - 1 - right_clues_sum;
								
								left_clues_sum := left_clues_sum + LEVEL_INPUT(level).clues(t, i , j) + 1;
							end if;
							end loop;
							
							--check
							loader_ack_register := '1';
							for j in 0 to MAX_CLUE_LINE -1 loop
							if(j < clue_line_length) then
								if (constraints(t, i, j).size /= LEVEL_INPUT(level).clues(t, i, j)) then
									loader_ack_register := '0';
								end if;
							end if;
							end loop;
							loader_ack(i) <= loader_ack_register;
						else
							loader_ack(i) <= '1';
						end if;
					end loop;
				else
					loader_ack(i) <= '0';
					if(solver_status_register = S_ANALYZING) then
						--analyze(i);
					end if;
				end if;
			end if;
		end process;
	end generate;
	
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
	
*/
end architecture;