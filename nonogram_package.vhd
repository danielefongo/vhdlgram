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
	
	constant MAX_LEVEL				: integer := 2;
	constant MAX_ITERATION			: integer := 100;
	
	--TYPES
	attribute enum_encoding	: string;
	
	type status_type is (IDLE, LOAD, SOLVE_ITERATION, SOLVE_ALL, WON, LOST);
	
	--cells
	type cell_type is (INVALID, UNDEFINED, EMPTY, FULL);
	attribute enum_encoding of cell_type : type is "sequential";
	
	type cell_position_type is record
		row	: integer range -1 to (MAX_ROW - 1); -- -1 for invalid cell position
		col	: integer range -1 to (MAX_COLUMN - 1); -- -1 for invalid cell position
	end record;
	
	type cell_array_position_type is array(natural range <>) of cell_position_type;
	
	--lines
	type line_type is array(0 to (MAX_LINE - 1)) of cell_type;
	
	--clues
	subtype clue_type is integer range -1 to MAX_CLUE; -- -1 for invalid clue
	type clue_matrix_type is array(natural range <>, natural range <>) of clue_type; 
	
	--levels
	type level_type is record
		rows				:	integer range 0 to MAX_COLUMN;
		columns			:	integer range 0 to MAX_ROW;
		clue_rows		:	clue_matrix_type(0 to MAX_COLUMN - 1, 0 to MAX_CLUE_ROW - 1);
		clue_columns	: 	clue_matrix_type(0 to MAX_ROW - 1, 0 to MAX_CLUE_COLUMN - 1);
		full_cells		:	cell_array_position_type(0 to MAX_ROW * MAX_COLUMN - 1);
		empty_cells		:	cell_array_position_type(0 to MAX_ROW * MAX_COLUMN - 1);
	end record;
	
	type level_array_type is array(natural range 0 to MAX_LEVEL - 1) of level_type;
	
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

	constant INPUT : level_array_type :=
	(
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

end package body;