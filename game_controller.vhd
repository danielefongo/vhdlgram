library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.nonogram_package.all;

entity game_controller is

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
		
end game_controller;

architecture RTL of game_controller is
	
	--TYPES
	type solver_status_type is (S_IDLE, S_SYNCRONIZE, S_ANALYZING_LEFT, S_ANALYZING_RIGHT, S_ANALYZING_BLOCKS, S_ANALYSIS_FORWARD, S_SIMPLE_BLOCKS, S_SIMPLE_SPACES, S_FINALIZING, S_CHECKING);
	attribute enum_encoding of solver_status_type : type is "sequential";
	
	--SIGNALS
	signal solver_status_register			: solver_status_type := S_IDLE;
	signal transposed_register				: integer range 0 to 1 := 0;
	signal index_register					: integer range 0 to MAX_LINE := 0;
	signal iteration_register 				: integer range 0 to MAX_ITERATION;
	signal ack_register						: status_type := IDLE;
	signal clock_divisor						: integer range 0 to WR_PERIOD := 0;
	
	--PROCEDURES
	procedure load_procedure is
	begin
		if(LEVEL = -1) then
			ack_register <= LOAD;
		else
			if(clock_divisor = 0) then
				if(transposed_register = 0) then
					BOARD_QUERY.index <= index_register;
					BOARD_QUERY.transposed <= 0;
					BOARD_INPUT_LINE <= load_board_row(LEVEL, index_register);
					BOARD_W_NOT_R <= '1';
					
					CONSTRAINT_QUERY.index <= index_register;
					CONSTRAINT_QUERY.transposed <= 0;
					CONSTRAINT_INPUT_LINE <= load_constraint_line(LEVEL, transposed_register, index_register);
					CONSTRAINT_W_NOT_R <= '1';
				else
					CONSTRAINT_QUERY.index <= index_register;
					CONSTRAINT_QUERY.transposed <= 1;
					CONSTRAINT_INPUT_LINE <= load_constraint_line(LEVEL, transposed_register, index_register);
					CONSTRAINT_W_NOT_R <= '1';
				end if;
				clock_divisor <= clock_divisor + 1;
			elsif(clock_divisor < WR_PERIOD / 2) then
				clock_divisor <= clock_divisor + 1;
			elsif(clock_divisor < WR_PERIOD) then
				BOARD_W_NOT_R <= '0';
				clock_divisor <= clock_divisor + 1;
			else
				clock_divisor <= 0;
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
						
						iteration_register <= 0;
						ITERATION <= 0;

						ack_register <= LOAD;
					end if;
				end if;
			end if;
		end if;
	end procedure;
	
	procedure simple_blocks is
		variable tmp_board_line : line_type;
	begin
		tmp_board_line := BOARD_OUTPUT_LINE;
		for i in 0 to MAX_CLUE_LINE - 1 loop
		if(CONSTRAINT_OUTPUT_LINE(i).size /= -1) then
			for j in 0 to MAX_LINE - 1 loop
			if(tmp_board_line(j) /= INVALID) then
				if(j > CONSTRAINT_OUTPUT_LINE(i).max_end - CONSTRAINT_OUTPUT_LINE(i).size and 
					j < CONSTRAINT_OUTPUT_LINE(i).min_start + CONSTRAINT_OUTPUT_LINE(i).size) then
					tmp_board_line(j) := FULL;
				end if;
			end if;
			end loop;
		end if;
		end loop;
		
		BOARD_INPUT_LINE <= tmp_board_line;
		BOARD_W_NOT_R <= '1';
	end procedure;
	
	procedure simple_spaces is
		variable tmp_board_line : line_type;
		variable last_constraint_max_end : integer range 0 to MAX_LINE := 0;
	begin
		tmp_board_line := BOARD_OUTPUT_LINE;
		last_constraint_max_end := 0;
		
		for i in 0 to MAX_CLUE_LINE - 1 loop
		if(CONSTRAINT_OUTPUT_LINE(i).size /= -1) then
			for j in 0 to MAX_LINE - 1 loop
			if(tmp_board_line(j) /= INVALID) then
				if(j >= last_constraint_max_end and j < CONSTRAINT_OUTPUT_LINE(i).min_start) then
					tmp_board_line(j) := EMPTY;
				end if;
			end if;
			end loop;
			last_constraint_max_end := CONSTRAINT_OUTPUT_LINE(i).max_end + 1;
		end if;
		end loop;
		
		for j in 0 to MAX_LINE - 1 loop
			if(tmp_board_line(j) /= INVALID and j >= last_constraint_max_end) then
				tmp_board_line(j) := EMPTY;
			end if;
		end loop;	
		
		BOARD_INPUT_LINE <= tmp_board_line;
		BOARD_W_NOT_R <= '1';
	end procedure;
	
	procedure analyze_left is
		variable	tmp_board_line				: line_type;
		variable tmp_constraint_line			: constraint_line_type;
		variable available_size 				: integer range 0 to MAX_LINE := 0;
		variable constraint_sum 				: integer range 0 to MAX_LINE := 0;
		variable current_constraint 			: integer range 0 to MAX_CLUE_LINE - 1 := 0;
		variable field_start 					: integer range -1 to MAX_LINE - 1 := -1;
		variable field_end 						: integer range -1 to MAX_LINE - 1 := -1;
		variable exit_analysis					: boolean := false;
		variable exit_constraints 				: boolean := false;
		variable block_found 					: boolean := false;
	begin

		tmp_board_line := BOARD_OUTPUT_LINE;
		tmp_constraint_line := CONSTRAINT_OUTPUT_LINE;
		
		for i in 0 to MAX_LINE - 1 loop
		if(tmp_board_line(i) = FULL or tmp_board_line(i) = UNDEFINED) then
			available_size := available_size + 1;
		end if;
		end loop;
		
		for i in 0 to MAX_CLUE_LINE - 1 loop
		if(tmp_constraint_line(i).size /= -1) then
			constraint_sum := constraint_sum + tmp_constraint_line(i).size;
		end if;
		end loop;
		
		for i in 0 to MAX_LINE - 1 loop
		if(tmp_board_line(i) /= INVALID and exit_analysis = false) then
			case(tmp_board_line(i)) is
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
					exit_constraints := false;
					if(field_start /= -1 and field_end /= -1) then
						for j in 0 to MAX_CLUE_LINE - 1 loop
						if(j >= current_constraint and tmp_constraint_line(j).size /= -1 and exit_analysis = false and exit_constraints = false) then
							if(field_end - field_start + 1 >= tmp_constraint_line(current_constraint).size) then
								if(tmp_constraint_line(current_constraint).min_start < field_start) then
									tmp_constraint_line(current_constraint).min_start := field_start;
								end if;
								
								if(block_found = false and available_size - (field_end - field_start + 1) >= constraint_sum) then
									exit_analysis := true;
								else --univocal
									if(tmp_constraint_line(current_constraint).max_end > field_end) then
										tmp_constraint_line(current_constraint).max_end := field_end;
									end if;
									
									if(field_end - field_start + 1 = tmp_constraint_line(current_constraint).size) then
										available_size := available_size - tmp_constraint_line(current_constraint).size;
									else
										available_size := available_size - tmp_constraint_line(current_constraint).size - 1;
									end if;
									
									field_start := field_start + tmp_constraint_line(current_constraint).size + 1;
									constraint_sum := constraint_sum - tmp_constraint_line(current_constraint).size;
									current_constraint := current_constraint + 1;
									block_found := false;
									
									if(field_end - field_start < 0) then
										exit_constraints := true;
									end if;
								end if;
							else
								exit_constraints := true;
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
		
		CONSTRAINT_INPUT_LINE <= tmp_constraint_line;
		CONSTRAINT_W_NOT_R <= '1';
	end procedure;
	
	procedure analyze_right is
		variable tmp_board_line					: line_type;
		variable tmp_constraint_line			: constraint_line_type;
		variable available_size 				: integer range 0 to MAX_LINE := 0;
		variable constraint_sum 				: integer range 0 to MAX_LINE := 0;
		variable current_constraint 			: integer range 0 to MAX_CLUE_LINE - 1 := 0;
		variable field_start 					: integer range -1 to MAX_LINE - 1:= -1;
		variable field_end 						: integer range -1 to MAX_LINE - 1:= -1;
		variable exit_analysis					: boolean := false;
		variable exit_constraints 				: boolean := false;
		variable block_found 					: boolean := false;
	begin
		tmp_board_line := BOARD_OUTPUT_LINE;
		tmp_constraint_line := CONSTRAINT_OUTPUT_LINE;
		
		for i in 0 to MAX_LINE - 1 loop
		if(tmp_board_line(i) = FULL or tmp_board_line(i) = UNDEFINED) then
			available_size := available_size + 1;
		end if;
		end loop;
		
		for i in 0 to MAX_CLUE_LINE - 1 loop
		if(tmp_constraint_line(i).size /= -1) then
			constraint_sum := constraint_sum + tmp_constraint_line(i).size;
			current_constraint := current_constraint + 1;
		end if;
		end loop;
		
		current_constraint := current_constraint - 1;
		
		for i in MAX_LINE - 1 downto 0 loop
		if(tmp_board_line(i) /= INVALID and exit_analysis = false) then
			case(tmp_board_line(i)) is
				when FULL =>
					block_found := true;
					if(field_end = -1) then
						field_end := i;
					end if;
					field_start := i;
				when UNDEFINED =>
					if(field_end = -1) then
						field_end := i;
					end if;
					field_start := i;
				when EMPTY =>
					exit_constraints := false;
					if(field_start /= -1 and field_end /= -1) then
						for j in MAX_CLUE_LINE - 1 downto 0 loop
						if(j <= current_constraint and tmp_constraint_line(j).size /= -1 and exit_analysis = false and exit_constraints = false) then
							if(field_end - field_start + 1 >= tmp_constraint_line(current_constraint).size) then
								if(tmp_constraint_line(current_constraint).max_end > field_end) then
									tmp_constraint_line(current_constraint).max_end := field_end;
								end if;
								
								if(block_found = false and available_size - (field_end - field_start + 1) >= constraint_sum) then
									exit_analysis := true;
								else --univocal
									if(tmp_constraint_line(current_constraint).min_start < field_start) then
										tmp_constraint_line(current_constraint).min_start := field_start;
									end if;
									
									if(field_end - field_start + 1 = tmp_constraint_line(current_constraint).size) then
										available_size := available_size - tmp_constraint_line(current_constraint).size;
									else
										available_size := available_size - tmp_constraint_line(current_constraint).size - 1;
									end if;
									
									field_end := field_end - tmp_constraint_line(current_constraint).size - 1;
									constraint_sum := constraint_sum - tmp_constraint_line(current_constraint).size;
									current_constraint := current_constraint - 1;
									block_found := false;
									
									if(field_end - field_start < 0) then
										exit_constraints := true;
									end if;
								end if;
							else
								exit_constraints := true;
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
		
		CONSTRAINT_INPUT_LINE <= tmp_constraint_line;
		CONSTRAINT_W_NOT_R <= '1';
	end procedure;
	
	procedure analyze_blocks is
		variable tmp_board_line 				: line_type;
		variable tmp_constraint_line 			: constraint_line_type;
		variable field_start 					: integer range -1 to MAX_LINE - 1 := -1;
		variable field_end 						: integer range -1 to MAX_LINE - 1 := -1;
		variable blockfield_start 				: integer range -1 to MAX_LINE - 1 := -1;
		variable blockfield_end 				: integer range -1 to MAX_LINE - 1 := -1;
		variable last_univocal_blockfield_start : integer range -1 to MAX_LINE - 1 := -1;
		variable last_univocal_blockfield_end 	: integer range -1 to MAX_LINE - 1 := -1;
		variable last_univocal_constraint 		: integer range -1 to MAX_CLUE_LINE - 1 := -1;
		variable last_univocal 					: boolean := true;
		variable constraint_counter 			: integer range 0 to MAX_CLUE_LINE := 0;
		variable current_constraint 			: integer range 0 to MAX_CLUE_LINE - 1 := 0;
	begin
		tmp_board_line := BOARD_OUTPUT_LINE;	
		tmp_constraint_line := CONSTRAINT_OUTPUT_LINE;

		for i in 0 to MAX_LINE - 1 loop
		if(tmp_board_line(i) /= INVALID) then
			case(tmp_board_line(i)) is
				when FULL =>
					if(field_start = -1) then
						field_start := i;
					end if;
					field_end := i;
					if(blockfield_start = -1) then
						blockfield_start := i;
					end if;
					blockfield_end := i;
				when UNDEFINED | EMPTY =>
					if(tmp_board_line(i) = UNDEFINED) then
						if(field_start = -1) then
							field_start := i;
						end if;
						field_end := i;
					end if;
					
					if(last_univocal = true and blockfield_start /= -1 and blockfield_end /= -1) then
						constraint_counter := 0;
						for j in 0 to MAX_CLUE_LINE - 1 loop
						if(tmp_constraint_line(j).size /= -1 and tmp_constraint_line(j).min_start <= blockfield_start and tmp_constraint_line(j).max_end >= blockfield_end) then
							constraint_counter := constraint_counter + 1;
							current_constraint := j;
						end if;
						end loop;
						
						if(constraint_counter = 1) then
							if(last_univocal_blockfield_start /= -1 and last_univocal_blockfield_end /= -1) then
								if(current_constraint = last_univocal_constraint) then
									if(tmp_constraint_line(current_constraint).max_end > last_univocal_blockfield_start + tmp_constraint_line(current_constraint).size - 1) then
										tmp_constraint_line(current_constraint).max_end := last_univocal_blockfield_start + tmp_constraint_line(current_constraint).size - 1;
									end if;
								elsif(last_univocal_blockfield_end = blockfield_start - 2) then
									tmp_constraint_line(last_univocal_constraint).max_end := last_univocal_blockfield_end;
									tmp_constraint_line(current_constraint).min_start := blockfield_start;
								end if;
							end if;
							
							if(tmp_constraint_line(current_constraint).min_start < blockfield_end - tmp_constraint_line(current_constraint).size + 1) then
								tmp_constraint_line(current_constraint).min_start := blockfield_end - tmp_constraint_line(current_constraint).size + 1;
							end if;
							
							if(tmp_board_line(i) = UNDEFINED) then
								if(tmp_constraint_line(current_constraint).min_start < field_start) then
									tmp_constraint_line(current_constraint).min_start := field_start;
								end if;
							else
								if(tmp_constraint_line(current_constraint).max_end > field_end) then
									tmp_constraint_line(current_constraint).max_end := field_end;
								end if;
							end if;
							
							if(tmp_constraint_line(current_constraint).max_end > blockfield_start + tmp_constraint_line(current_constraint).size - 1) then
								tmp_constraint_line(current_constraint).max_end := blockfield_start + tmp_constraint_line(current_constraint).size - 1;
							end if;
							
							last_univocal_blockfield_start := blockfield_start;
							last_univocal_blockfield_end := blockfield_end;
							last_univocal_constraint := current_constraint;
							last_univocal := true;
							
						else
							last_univocal := false;
						end if;
					end if;
					
					blockfield_start := -1;
					blockfield_end := -1;
					
					if(tmp_board_line(i) = EMPTY) then
						last_univocal := true;
						last_univocal_constraint := -1;
						last_univocal_blockfield_start := -1;
						last_univocal_blockfield_end := -1;
						field_start := -1;
						field_end := -1;
					end if;
					
				when others =>
			end case;
		end if;
		end loop;
		
		CONSTRAINT_INPUT_LINE <= tmp_constraint_line;
		CONSTRAINT_W_NOT_R <= '1';
	end procedure;
	
	procedure analysis_forward is
		variable tmp_constraint_line 			: constraint_line_type;
		variable last_constraint_min_start		: integer range -1 to MAX_LINE - 1;
		variable last_constraint_max_end 		: integer range -1 to MAX_LINE - 1 := -1;
		variable last_constraint_size 			: integer range -1 to MAX_LINE;
	begin
		tmp_constraint_line := CONSTRAINT_OUTPUT_LINE;

		last_constraint_min_start := tmp_constraint_line(0).min_start;
		last_constraint_size := tmp_constraint_line(0).size;
		for i in 1 to MAX_CLUE_LINE - 1 loop
		if(tmp_constraint_line(i).size /= -1) then
			if(tmp_constraint_line(i).min_start < last_constraint_min_start + last_constraint_size + 1) then
				tmp_constraint_line(i).min_start := last_constraint_min_start + last_constraint_size + 1;
			end if;
			
			last_constraint_size := tmp_constraint_line(i).size;
			last_constraint_min_start := tmp_constraint_line(i).min_start;
		end if;
		end loop;
		
		for i in MAX_CLUE_LINE - 1 downto 0 loop
		if(tmp_constraint_line(i).size /= -1) then
			if(last_constraint_max_end = -1) then
				last_constraint_max_end := tmp_constraint_line(i).max_end;
				last_constraint_size := tmp_constraint_line(i).size;
			else
				if(tmp_constraint_line(i).max_end > last_constraint_max_end - last_constraint_size - 1) then
					tmp_constraint_line(i).max_end := last_constraint_max_end - last_constraint_size - 1;
				end if;
				
				last_constraint_size := tmp_constraint_line(i).size;
				last_constraint_max_end := tmp_constraint_line(i).max_end;
			end if;
		end if;
		end loop;
		
		CONSTRAINT_INPUT_LINE <= tmp_constraint_line;
		CONSTRAINT_W_NOT_R <= '1';
	end procedure;
	
begin
	
	--PROCESSES
	status_update : process(CLOCK, RESET_N)	
	begin
		if(RESET_N = '0') then
			ack_register <= IDLE;
			iteration_register <= 0;
			ITERATION <= 0;
			transposed_register <= 0;
			index_register <= 0;
			clock_divisor <= 0;
			solver_status_register <= S_IDLE;
			BOARD_W_NOT_R <= '0';
			CONSTRAINT_W_NOT_R <= '0';
		elsif(rising_edge(CLOCK)) then
			case(STATUS) is
				when IDLE =>
					transposed_register <= 0;
					index_register <= 0;
					clock_divisor <= 0;
					solver_status_register <= S_IDLE;
					BOARD_W_NOT_R <= '0';
					CONSTRAINT_W_NOT_R <= '0';
					ack_register <= IDLE;
				when LOAD =>
					load_procedure;
					
				when SOLVE_ITERATION | SOLVE_ALL =>
					case(solver_status_register) is
						when S_IDLE =>
							index_register <= 0;
							transposed_register <= iteration_register mod 2;
							
							BOARD_W_NOT_R <= '0';
							BOARD_QUERY.index <= 0;
							BOARD_QUERY.transposed <= iteration_register mod 2;
							CONSTRAINT_W_NOT_R <= '0';
							CONSTRAINT_QUERY.index <= 0;
							CONSTRAINT_QUERY.transposed <= iteration_register mod 2;
								
							solver_status_register <= S_SYNCRONIZE;
						
						when S_SYNCRONIZE =>
							if(clock_divisor < WR_PERIOD - 1) then
								BOARD_W_NOT_R <= '0';
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								clock_divisor <= 0;
								solver_status_register <= S_ANALYZING_LEFT;
							end if;
						
						when S_ANALYZING_LEFT =>
							if(clock_divisor = 0) then
			
								analyze_left;
			
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD / 2) then
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD) then
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= 0;
								solver_status_register <= S_ANALYZING_RIGHT;
							end if;
							
						when S_ANALYZING_RIGHT =>
							if(clock_divisor = 0) then
			
								analyze_right;

								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD / 2) then
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD) then
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= 0;
								solver_status_register <= S_ANALYZING_BLOCKS;
							end if;
							
						when S_ANALYZING_BLOCKS =>
							if(clock_divisor = 0) then
								
								analyze_blocks;

								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD / 2) then
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD) then
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= 0;
								solver_status_register <= S_ANALYSIS_FORWARD;
							end if;
						
						when S_ANALYSIS_FORWARD =>
							if(clock_divisor = 0) then
			
								analysis_forward;

								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD / 2) then
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD) then
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								CONSTRAINT_W_NOT_R <= '0';
								clock_divisor <= 0;
								solver_status_register <= S_SIMPLE_BLOCKS;
							end if;
						
						when S_SIMPLE_BLOCKS =>
							if(clock_divisor = 0) then
								
								simple_blocks;
								
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD / 2) then
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD) then
								BOARD_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								BOARD_W_NOT_R <= '0';
								clock_divisor <= 0;
								solver_status_register <= S_SIMPLE_SPACES;
							end if;
							
						when S_SIMPLE_SPACES =>
							if(clock_divisor = 0) then
								
								simple_spaces;
								
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD / 2) then
								clock_divisor <= clock_divisor + 1;
							elsif(clock_divisor < WR_PERIOD) then
								BOARD_W_NOT_R <= '0';
								clock_divisor <= clock_divisor + 1;
							else
								BOARD_W_NOT_R <= '0';
								clock_divisor <= 0;
								solver_status_register <= S_FINALIZING;
							end if;
							
						when S_FINALIZING =>
							BOARD_W_NOT_R <= '0';
							CONSTRAINT_W_NOT_R <= '0';
							
							if(index_register < MAX_LINE - 1) then
								BOARD_QUERY.index <= index_register + 1;
								CONSTRAINT_QUERY.index <= index_register + 1;
								
								index_register <= index_register + 1;
								solver_status_register <= S_SYNCRONIZE;
							else
								ITERATION <= iteration_register + 1;
								
								index_register <= 0;
								BOARD_QUERY.index <= 0;
								BOARD_QUERY.transposed <= (iteration_register + 1) mod 2;
								CONSTRAINT_QUERY.index <= 0;
								CONSTRAINT_QUERY.transposed <= (iteration_register + 1) mod 2;
							
								transposed_register <= (iteration_register + 1) mod 2;
								iteration_register <= iteration_register + 1;
								solver_status_register <= S_CHECKING;
							end if;
							
						when S_CHECKING =>
							if(UNDEFINED_CELLS = 0) then
								ack_register <= WON;
								solver_status_register <= S_IDLE; 
							elsif(iteration_register >= MAX_ITERATION - 1) then
								ack_register <= LOST;
								solver_status_register <= S_IDLE; 
							else
								if(STATUS = SOLVE_ITERATION) then
									ack_register <= SOLVE_ITERATION; 
								end if;
								solver_status_register <= S_IDLE;
							end if;
					end case;
				when WON | LOST =>
					ack_register <= ack_register;
			end case;

		end if;
		ITERATION <= iteration_register;
		ACK <= ack_register;
	end process;
	
end architecture;