library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package nonogram_package is

	--CONSTANTS
	constant MAX_ROW					: integer := 40;
	constant MAX_COLUMN				: integer := 30;
	constant MAX_LINE					: integer := 40; -- MAX(MAX_ROW, MAX_COLUMN)
	
	constant MAX_CLUE					: integer := 19;
	constant MAX_CLUE_ROW			: integer := 20; -- CEIL(MAX_ROW / 2)
	constant MAX_CLUE_COLUMN		: integer := 15; -- CEIL(MAX_COLUMN / 2)
	constant MAX_CLUE_LINE			: integer := 20; -- CEIL(MAX_LINE / 2)
	
	constant MAX_LEVEL				: integer := 3;
	constant MAX_ITERATION			: integer := 100;
	
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
	type clue_matrix_type is array(integer range <>, integer range <>) of clue_type; 
	
	--levels
	type level_type is record
		rows				:	integer range 0 to MAX_COLUMN;
		columns			:	integer range 0 to MAX_ROW;
		clue_rows		:	clue_matrix_type(0 to MAX_COLUMN - 1, 0 to MAX_CLUE_ROW - 1);
		clue_columns	: 	clue_matrix_type(0 to MAX_ROW - 1, 0 to MAX_CLUE_COLUMN - 1);
		full_cells		:	cell_array_position_type(0 to MAX_ROW * MAX_COLUMN - 1);
		empty_cells		:	cell_array_position_type(0 to MAX_ROW * MAX_COLUMN - 1);
	end record;
	
	type level_array_type is array(integer range 0 to MAX_LEVEL - 1) of level_type;
	
	
	
	--FUNCTIONS
	
	--board
	function get_board_line(board : board_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return line_type;
	function load_board(level : integer range 0 to MAX_LEVEl - 1) return board_type;
	
	--clues
	function get_clue_row_length(level : integer; index : integer range 0 to MAX_COLUMN) return integer;
	function get_clue_column_length(level : integer; index : integer range 0 to MAX_ROW) return integer;
	
	
	

	
	
	
	
	
	
	
	
	
	
	--CONSTANTS
	constant EMPTY_LEVEL : level_type :=
	(
		rows 				=> 0,
		columns			=> 0,
		clue_rows		=> 
		(
			others => (others => -1)
		),
		clue_columns	=> 
		(
			others => (others => -1)
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
			rows 				=> 4,
			columns			=> 5,
			clue_rows		=> 
			(
				(5, others => -1),
				(1,1, others => -1),
				(1,1, others => -1),
				(1,1, others => -1),
				others => (others => -1)
			),
			clue_columns	=> 
			(
				(1, others => -1),
				(4, others => -1),
				(1, others => -1),
				(4, others => -1),
				(1, others => -1),
				others => (others => -1)
			),
			full_cells		=>
			(
				(0,0),
				others => (-1, -1)
			),
			empty_cells		=>
			(
				(2,1),
				others => (-1, -1)
			)
		),
		(
			rows 				=> 3,
			columns			=> 3,
			clue_rows		=> 
			(
				(1,1, others => -1),
				(1, others => -1),
				(1,1, others => -1),
				others => (others => -1)
			),
			clue_columns	=> 
			(
				(1,1, others => -1),
				(1, others => -1),
				(1,1, others => -1),
				others => (others => -1)
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
		others => EMPTY_LEVEL
	);
	
end package;

package body nonogram_package is
	
	--FUNCTIONS
	--board
	function get_board_line(board : board_type; transposed : integer range 0 to 1; index : integer range 0 to MAX_LINE) return line_type is
		variable result : line_type := (others => INVALID);
		variable max_i : integer := 0;
	begin
		if(transposed = 0) then
			max_i := MAX_ROW - 1;
		else
			max_i := MAX_COLUMN - 1;
		end if;
		
		for i in 0 to max_i loop
			if(transposed = 0) then
				result(i) := board(i, index);
			else
				result(i) := board(index, i);
			end if;
			if(result(i) = INVALID) then
				return result;
			end if;
		end loop;
		return result;
	end function;
	
	function load_board(level : integer range 0 to MAX_LEVEl - 1) return board_type is
	variable result : board_type := (others => (others => INVALID));
	begin
		for x in 0 to MAX_ROW loop
			exit when(x >= LEVEL_INPUT(LEVEL).columns);
			for y in 0 to MAX_COLUMN loop
				exit when(y >= LEVEL_INPUT(LEVEL).rows);
				result(x, y) := UNDEFINED;
			end loop;
		end loop;
		
		for i in 0 to MAX_ROW * MAX_COLUMN - 1 loop
			exit when(LEVEL_INPUT(LEVEL).full_cells(i) = (-1,-1));
			result(LEVEL_INPUT(LEVEL).full_cells(i).x, LEVEL_INPUT(LEVEL).full_cells(i).y) := FULL;
		end loop;
		
		for i in 0 to MAX_ROW * MAX_COLUMN - 1 loop
			exit when(LEVEL_INPUT(LEVEL).empty_cells(i) = (-1,-1));
			result(LEVEL_INPUT(LEVEL).empty_cells(i).x, LEVEL_INPUT(LEVEL).empty_cells(i).y) := EMPTY;
		end loop;
		
		return result;
	end function;
	
	--clues
	function get_clue_row_length(level : integer range 0 to MAX_LEVEL - 1; index : integer range 0 to MAX_COLUMN) return integer is
		variable result : integer := 0;
	begin
		if(LEVEL_INPUT(level).rows <= index) then
			return -1;
		else	
			for i in 0 to MAX_CLUE_ROW loop
			if(LEVEL_INPUT(level).clue_rows(index, i) > 0) then
				result := result + 1;
			else
				return result;
			end if;
		end loop;
		end if;
	end function;
	
	function get_clue_column_length(level : integer range 0 to MAX_LEVEL - 1; index : integer range 0 to MAX_ROW) return integer is
		variable result : integer := 0;
	begin
		if(LEVEL_INPUT(level).columns <= index) then
			return -1;
		else	
			for i in 0 to MAX_CLUE_COLUMN loop
			if(LEVEL_INPUT(level).clue_columns(index, i) > 0) then
				result := result + 1;
			else
				return result;
			end if;
		end loop;
		end if;
	end function;
	
end package body;