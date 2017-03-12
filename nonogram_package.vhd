library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.vga_package.all;

package nonogram_package is
	constant COLUMNS					:	positive	:= 10;
	constant ROWS						:	positive	:= 10;
	constant BOARD_SIZE				:	positive	:= 10; -- TODO: implement a MAX function here!
	constant CLUES_ROWS				:	positive	:=	5; -- ceil(ROWS / 2)
	constant CLUES_COLUMNS			: 	positive	:=	5; -- ceil(COLUMNS / 2)
	constant CLUES_SIZE				: 	positive := 5; -- TODO: implement a MAX function here!

	-- cells
	type cell	is (FULL, EMPTY, UNDEFINED);
	type cell_position is record
		row	: integer range 0 to (ROWS - 1);	
		col	: integer range 0 to (COLUMNS - 1);
	end record;
	
	attribute enum_encoding	: string;
	attribute enum_encoding of cell_position : type is "sequential"; -- sequential (binary) --> 00, 01, 10
	
	-- board
	type board_array_type is array(natural range <>, natural range <>) of cell;
	type board_type is record
		cells	:	board_array_type(0 to (ROWS - 1), 0 to (COLUMNS - 1));
	end record;
	
	-- clues
	subtype clue is integer;
	type clues_array_type is array(natural range <>, natural range <>) of integer range	0 to BOARD_SIZE; -- Be careful. Possible overflow here!!
	type clues_board_type is record
		rows	:	clues_array_type(0 to (ROWS - 1), 0 to (CLUES_COLUMNS - 1));
		cols	: 	clues_array_type(0 to (COLUMNS - 1), 0 to (CLUES_ROWS - 1));
	end record;
	
	-- constraints
	type constraint is record
		size			:	integer; -- TODO: Think a more meaningful term.
		min_start	:	integer;
		max_end		: 	integer;
	end record;
	type constraints_array_type is array (natural range <>, natural range <>) of constraint;
	type constraints_board_type is record
		rows	:	constraints_array_type(0 to (ROWS - 1), 0 to (CLUES_COLUMNS - 1));
		cols	:	constraints_array_type(0 to (COLUMNS - 1), 0 to (CLUES_ROWS - 1));
	end record;
	
	-- queries
	type line_enum is (ROW, COL);
	
	type line_query is record
		index			:	integer range 0 to BOARD_SIZE; -- Be careful. Possible overflow here!!
		line_type	: 	line_enum;
	end record;
	
	type clues_query is record
		index			: 	integer range 0 to BOARD_SIZE; -- Be careful. Possible overflow here!!
		line_type	: 	line_enum;
	end record;
	
	type constraints_query is record
		index			: 	integer range 0 to BOARD_SIZE; -- Be careful. Possible overflow here!!
		line_type	: 	line_enum;
	end record;
	
	-- clues definition
	constant INPUT_CLUES	:	clues_board_type :=
	(
		rows	=> ((5,0,0,0,0), (4,2,0,0,0), (3,4,0,0,0), (1,4,2,0,0), (7,0,0,0,0), (1,1,0,0,0), (1,1,0,0,0), (1,1,0,0,0), (1,1,0,0,0), (10,0,0,0,0)),
		cols	=> ((1,0,0,0,0), (2,1,0,0,0), (2,1,1,0,0), (5,2,1,0,0), (2,3,2,0,0), (5,1,0,0,0), (1,4,2,0,0), (3,1,2,1,0), (4,1,0,0,0), (1,1,0,0,0))
	);
	
--===== VIRTUAL DEFINITIONS =======================================================================================================================================
	
	-- lines
	type line_type is array(0 to (BOARD_SIZE - 1)) of cell; -- Be careful. Possible overflow here!!
	type clues_type is array(0 to (CLUES_SIZE - 1)) of clue; -- Be careful. Possible overflow here!!
	type constraints_type is array(0 to (CLUES_SIZE - 1)) of constraint; -- Be careful. Possible overflow here!!
		
--===== FUNCTION DEFINITIONS =======================================================================================================================================

	function get_line(board: board_type; query: line_query) return line_type;
	function get_clues(clues: clues_board_type; query: clues_query) return clues_type;
	function get_constraints(constraints: constraints_board_type; query: constraints_query) return constraints_type;
	function get_constraints_length(constraints: constraints_type) return integer;
	function init_constraints(clues: clues_board_type) return constraints_board_type;
	
	
end package;

package body nonogram_package is
	
	function get_line(board: board_type; query: line_query) return line_type is
		variable result : line_type;
	begin
		case (query.line_type) is
			when ROW =>
				for i in 0 to (ROWS - 1) loop
					result(i) := board.cells(i, query.index);
				end loop;
			when COL =>
				for i in 0 to (COLUMNS - 1) loop
					result(i) := board.cells(query.index, i);
				end loop;
		end case;
		return result;
	end;
	
	function get_clues(clues: clues_board_type; query: clues_query) return clues_type is
		variable result : clues_type;
	begin
  		case (query.line_type) is
  			when ROW =>
  				for i in 0 to (CLUES_ROWS - 1) loop
					result(i) := clues.rows(query.index, i);
				end loop;
  			when COL =>
  				for i in 0 to (CLUES_COLUMNS - 1) loop
					result(i) := clues.cols(query.index, i);
				end loop;
  		end case;
  		return result;
	end;
	
	function get_constraints(constraints: constraints_board_type; query: constraints_query) return constraints_type is
		variable result : constraints_type;
	begin
		case (query.line_type) is
			when ROW =>
				for i in 0 to (CLUES_ROWS - 1) loop
					result(i) := constraints.rows(query.index, i);
				end loop;
			when COL =>
				for i in 0 to (CLUES_COLUMNS - 1) loop
					result(i) := constraints.cols(query.index, i);
				end loop;
		end case;
		return result;
	end;
	
	function get_constraints_length(constraints: constraints_type) return integer is
		variable result : integer := 0;
	begin
		for i in constraints'range loop
			if constraints(i).size > 0 then
				result := result + 1;
			else
				return result;
			end if;
		end loop;
	end;
	
	function init_constraints(clues: clues_board_type) return constraints_board_type is
		variable result	: constraints_board_type;
	begin
		for i in 0 to (ROWS - 1) loop
			for j in 0 to (CLUES_COLUMNS - 1) loop
				result.rows(i, j).size := clues.rows(i, j);
				result.rows(i, j).min_start := 0;
				result.rows(i, j).max_end	:= COLUMNS - 1;
			end loop;
		end loop;
		for i in 0 to (COLUMNS - 1) loop
			for j in 0 to (CLUES_ROWS - 1) loop
				result.cols(i, j).size := clues.cols(i, j);
				result.cols(i, j).min_start := 0;
				result.cols(i, j).max_end	:= ROWS - 1;
			end loop;
		end loop;
		
		return result;
	end;
	
end package body;