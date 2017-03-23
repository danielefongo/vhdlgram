
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package nonogram_package is

	--CONSTANTS
	constant MAX_ROW					: integer := 10;
	constant MAX_COLUMN				: integer := 10;
	constant MAX_LINE					: integer := 10; -- MAX(MAX_ROW, MAX_COLUMN)
	
	constant MAX_CLUE_ROW			: integer := 5; -- CEIL(MAX_ROW / 2)
	constant MAX_CLUE_COLUMN		: integer := 5; -- CEIL(MAX_COLUMN / 2)
	constant MAX_CLUE_LINE			: integer := 5; -- CEIL(MAX_LINE / 2)
	
	constant MAX_CLUE					: integer := 19;
	constant MAX_LEVEL				: integer := 4;
	constant MAX_ITERATION			: integer := 30;
	
	--TYPES
	attribute enum_encoding	: string;
	
	type status_type is (IDLE, LOAD, SOLVE_ITERATION, SOLVE_ALL, WON, LOST);
	
	--cells
	type cell_type is (INVALID, UNDEFINED, EMPTY, FULL);
	attribute enum_encoding of cell_type : type is "sequential";
	
	type cell_position_type is record
		x				: integer range -1 to (MAX_ROW - 1); -- -1 for invalid cell position
		y				: integer range -1 to (MAX_COLUMN - 1); -- -1 for invalid cell position
	end record;
	
	type cell_array_position_type is array(integer range <>) of cell_position_type;
	
	--board
	type board_type is array(integer range 0 to MAX_ROW - 1, integer range 0 to MAX_COLUMN - 1) of cell_type;
	
	--lines
	type line_type is array(0 to (MAX_LINE - 1)) of cell_type;
	
	--clues
	subtype clue_type is integer range -1 to MAX_CLUE; -- -1 for invalid clue
	type clue_matrix_type is array(integer range <>, integer range <>, integer range <>) of clue_type; 

	--constraints
	type constraint_type is record
		size				: integer range -1 to MAX_CLUE;
		min_start		: integer range 0 to MAX_LINE - 1;
		max_end			: integer range 0 to MAX_LINE - 1;
	end record;
	type constraint_line_type is array(integer range 0 to MAX_CLUE_LINE - 1) of constraint_type;
	type constraint_matrix_type is array(integer range 0 to 1, integer range 0 to MAX_LINE - 1, integer range 0 to MAX_CLUE_LINE) of constraint_type;
	
	--levels
	type dim_type is array(integer range <>) of integer range 0 to MAX_LINE - 1;
	type level_type is record
		dim				: 	dim_type(0 to 1); --Be careful. Max real dimension is 30x40.
		clues				:	clue_matrix_type(0 to 1, 0 to MAX_LINE - 1, 0 to MAX_CLUE_LINE - 1);
		full_cells		:	cell_array_position_type(0 to MAX_ROW * MAX_COLUMN - 1);
		empty_cells		:	cell_array_position_type(0 to MAX_ROW * MAX_COLUMN - 1);
	end record;
	type level_array_type is array(integer range 0 to MAX_LEVEL - 1) of level_type;
	
	--FUNCTIONS
	--board
	function get_board_line(board : board_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return line_type;
	function load_board(level : integer range -1 to MAX_LEVEl - 1) return board_type;
	function check_board(level : integer range -1 to MAX_LEVEl - 1; board : board_type) return boolean;
	function get_undefined_cells(board : board_type) return integer;
	
	--clues
	function get_clue_line_length(level : integer range 0 to MAX_LEVEL - 1; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return integer;
	
	--constraints
	--function get_constraint_line(constraints : constraint_matrix_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return constraint_line_type;
	function load_constraints(level : integer range 0 to MAX_LEVEL - 1) return constraint_matrix_type;
	function check_constraints(level : integer range 0 to MAX_LEVEL - 1; constraints : constraint_matrix_type) return boolean;
	
	--CONSTANTS
	constant EMPTY_LEVEL : level_type :=
	(
		dim 				=> (0,0),
		clues				=> 
		(
			(others => (others => -1)),
			(others => (others => -1))
		),
		full_cells		=>
		(
			others => (-1, -1)
		),
		empty_cells		=>
		(
			others => (-1, -1)
		)
	);

	constant LEVEL_INPUT : level_array_type :=
	(
		(
			dim 				=> (5,4),
			clues				=> 
			(
				(
					(5, others => -1),
					(1,1, others => -1),
					(1,1, others => -1),
					(1,1, others => -1),
					others => (others => -1)
				),
				(
					(1, others => -1),
					(4, others => -1),
					(1, others => -1),
					(4, others => -1),
					(1, others => -1),
					others => (others => -1)
				)
			),
			full_cells		=>
			(
				others => (-1, -1)
			),
			empty_cells		=>
			(
				others => (-1, -1)
			)
		),
		(
			dim 				=> (3,3),
			clues				=> 
			(
				(
					(1,1, others => -1),
					(1, others => -1),
					(1,1, others => -1),
					others => (others => -1)
				),
				(
					(1,1, others => -1),
					(1, others => -1),
					(1,1, others => -1),
					others => (others => -1)
				)
			),
			full_cells		=>
			(
				(0,0),
				others => (-1, -1)
			),
			empty_cells		=>
			(
				(1,2),
				others => (-1, -1)
			)
		),
		(
			dim 				=> (9,10),
			clues				=> 
			(
				(
					(1,1, others => -1),
					(3,3, others => -1),
					(1,1,1, others => -1),
					(1,1, others => -1),
					(1,1, others => -1),
					(1,1, others => -1),
					(1,1, others => -1),
					(1,1, others => -1),
					(3, others => -1),
					(1, others => -1),
					others => (others => -1)
				),
				(
					(4, others => -1),
					(1,1, others => -1),
					(2,1, others => -1),
					(1,1, others => -1),
					(1,2, others => -1),
					(1,1, others => -1),
					(2,1, others => -1),
					(1,1, others => -1),
					(4, others => -1),
					others => (others => -1)
				)
			),
			full_cells		=>
			(
				others => (-1, -1)
			),
			empty_cells		=>
			(
				others => (-1, -1)
			)
		),
		others => EMPTY_LEVEL
	);
	
end package;

package body nonogram_package is
	
	--FUNCTIONS
	--board
	function get_board_line(board : board_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return line_type is
		variable result : line_type := (others => INVALID);
	begin
		for i in 0 to MAX_LINE - 1 loop
			if(transposed = 0 and i < MAX_ROW) then
				result(i) := board(i, index);
			elsif(transposed = 1 and i < MAX_COLUMN) then
				result(i) := board(index, i);
			end if;
		end loop;
		return result;
	end function;
	
	function load_board(level : integer range -1 to MAX_LEVEl - 1) return board_type is
		variable result : board_type := (others => (others => INVALID));
	begin
		if(level > -1) then
			for x in 0 to MAX_ROW - 1 loop
				for y in 0 to MAX_COLUMN - 1 loop
					if(x < LEVEL_INPUT(level).dim(0) and y < LEVEL_INPUT(level).dim(1)) then 
						result(x, y) := UNDEFINED;
					end if;
				end loop;
			end loop;
			
			for i in 0 to MAX_ROW * MAX_COLUMN - 1 loop
				if(LEVEL_INPUT(level).empty_cells(i).x /= -1 and LEVEL_INPUT(level).empty_cells(i).y /= -1) then
					result(LEVEL_INPUT(level).empty_cells(i).x, LEVEL_INPUT(level).empty_cells(i).y) := EMPTY;
				end if;
			end loop;
			
			for i in 0 to MAX_ROW * MAX_COLUMN - 1 loop
				if(LEVEL_INPUT(level).full_cells(i).x /= -1 and LEVEL_INPUT(level).full_cells(i).y /= -1) then
					result(LEVEL_INPUT(level).full_cells(i).x, LEVEL_INPUT(level).full_cells(i).y) := FULL;
				end if;
			end loop;
		end if;
		
		return result;
	end function;
	
	function check_board(level : integer range -1 to MAX_LEVEl - 1; board : board_type) return boolean is
		variable result : boolean := true;
	begin
		if(level < 0) then
			return false;
		else
			for x in 0 to MAX_ROW - 1 loop
				for y in 0 to MAX_COLUMN - 1 loop
					if(x < LEVEL_INPUT(level).dim(0) and y < LEVEL_INPUT(level).dim(1)) then 
						if(board(x,y) = INVALID) then
							result := false;
						end if;
					end if;
				end loop;
			end loop;
			
			if(result = false) then
				return result;
			end if;
			
			for i in 0 to MAX_ROW * MAX_COLUMN - 1 loop
				if(LEVEL_INPUT(level).empty_cells(i).x /= -1 and LEVEL_INPUT(level).empty_cells(i).y /= -1) then
					if(board(LEVEL_INPUT(level).empty_cells(i).x, LEVEL_INPUT(level).empty_cells(i).y) /= EMPTY) then
						result := false;
					end if;
				end if;
			end loop;
			
			if(result = false) then
				return result;
			end if;
			
			for i in 0 to MAX_ROW * MAX_COLUMN - 1 loop
				if(LEVEL_INPUT(level).full_cells(i).x /= -1 and LEVEL_INPUT(level).full_cells(i).y /= -1) then
					if(board(LEVEL_INPUT(level).full_cells(i).x, LEVEL_INPUT(level).full_cells(i).y) /= FULL) then
						result := false;
					end if;
				end if;
			end loop;
		end if;
	
		return result;
	end function;
	
	function get_undefined_cells(board : board_type) return integer is
		variable result : integer range 0 to MAX_ROW * MAX_COLUMN := 0;
	begin
		for x in 0 to MAX_ROW - 1 loop
			for y in 0 to MAX_COLUMN - 1 loop
				if(board(x, y) = UNDEFINED) then
					result := result + 1;
				end if;
			end loop;
		end loop;
		return result;
	end function;
	
	--clues
	function get_clue_line_length(level : integer range 0 to MAX_LEVEL - 1; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return integer is
		variable result : integer := 0;
	begin
		if((LEVEL_INPUT(level).dim(1) <= index and transposed = 0) or (LEVEL_INPUT(level).dim(0) <= index and transposed = 1)) then
			return -1;
		else	
			for i in 0 to MAX_CLUE_LINE loop
				if(LEVEL_INPUT(level).clues(transposed, index, i) > 0) then
					result := result + 1;
				else
					return result;
				end if;
			end loop;
		end if;
	end function;
	
	--constraints
	function load_constraints(level : integer range 0 to MAX_LEVEL - 1) return constraint_matrix_type is
		variable result : constraint_matrix_type := (others => (others => (others => (-1,0,0))));
		variable left_clues_sum : integer;
		variable right_clues_sum : integer;
		variable clue_line_length : integer;
	begin
		for t in 0 to 1 loop
			for i in 0 to MAX_LINE - 1 loop
			if(i < LEVEL_INPUT(level).dim(1 - t)) then
				
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
					result(t, i, j).size := LEVEL_INPUT(level).clues(t, i, j);
					
					right_clues_sum := right_clues_sum - LEVEL_INPUT(level).clues(t, i, j) - 1;
					
					result(t, i, j).min_start := left_clues_sum;
					result(t, i, j).max_end := LEVEL_INPUT(level).dim(t) - 1 - right_clues_sum;
					
					left_clues_sum := left_clues_sum + LEVEL_INPUT(level).clues(t, i , j) + 1;
				end if;
				end loop;	
			end if;
			end loop;
		end loop;
		return result;
	end function;
	
	function check_constraints(level : integer range 0 to MAX_LEVEL - 1; constraints : constraint_matrix_type) return boolean is
		variable result : boolean := true;
		variable clue_line_length : integer;
	begin
		for t in 0 to 1 loop
			for i in 0 to MAX_LINE - 1 loop
			if(i < LEVEL_INPUT(level).dim(1 - t)) then
				clue_line_length := get_clue_line_length(level, t, i);
				for j in 0 to MAX_CLUE_LINE -1 loop
				if(j < clue_line_length) then
					if(constraints(t, i, j).size /= LEVEL_INPUT(level).clues(t, i, j)) then
						result := false;
					end if;
				end if;
				end loop;	
			end if;
			end loop;
		end loop;
		return result;
	end function;
		
end package body;