library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package vga_package is

	--TYPES
	attribute enum_encoding	: string;
	subtype color_type is std_logic_vector(0 to 11);
	
	type vga_char is (CHAR_L, CHAR_E, CHAR_V, CHAR_W, CHAR_O, CHAR_N, CHAR_S, CHAR_T, CHAR_I, CHAR_R, CHAR_A);
	attribute enum_encoding of vga_char : type is "sequential";

	--CONSTANTS
	--screen
	constant VISIBLE_WIDTH    : integer := 640;
	constant VISIBLE_HEIGHT   : integer := 480;

	--vertical sync
	constant VERTICAL_FRONT_PORCH : integer := 10;
	constant VERTICAL_SYNC_PULSE : integer := 2;
	constant VERTICAL_BACK_PORCH : integer := 33;

	--horizontal sync
	constant HORIZONTAL_FRONT_PORCH : integer := 16;
	constant HORIZONTAL_SYNC_PULSE : integer := 96;
	constant HORIZONTAL_BACK_PORCH : integer := 48;

	--VGA screen
	constant TOTAL_H: integer := VERTICAL_FRONT_PORCH + VERTICAL_SYNC_PULSE +VERTICAL_BACK_PORCH + VISIBLE_HEIGHT; --525
	constant TOTAL_W: integer := HORIZONTAL_FRONT_PORCH + HORIZONTAL_SYNC_PULSE +HORIZONTAL_BACK_PORCH + VISIBLE_WIDTH;	--800
	constant WINDOW_HORIZONTAL_START: integer := HORIZONTAL_FRONT_PORCH + HORIZONTAL_SYNC_PULSE; --112
	constant WINDOW_HORIZONTAL_END: integer := HORIZONTAL_FRONT_PORCH + HORIZONTAL_SYNC_PULSE + VISIBLE_WIDTH; --752
	constant WINDOW_VERTICAL_START: integer := VERTICAL_FRONT_PORCH + VERTICAL_SYNC_PULSE;  --12
	constant WINDOW_VERTICAL_END: integer := VERTICAL_FRONT_PORCH + VERTICAL_SYNC_PULSE + VISIBLE_HEIGHT;--492

	--nonogram
	constant CELL_SIZE		:	integer 	:= 9;
	constant CONTENT_SIZE	:	integer		:= 7;
	constant LINE_WIDTH		:	integer		:= CELL_SIZE - CONTENT_SIZE;
	constant PADDING			:	integer		:= CELL_SIZE * 2;

	--colors
	constant BLACK				: 	color_type 	:= X"000";
	constant WHITE				: 	color_type 	:= X"FFF";
	constant RED				: 	color_type 	:= X"F00";
	constant GREEN				: 	color_type 	:= X"0F0";
	constant BLUE				: 	color_type 	:= X"00F";
	constant VIOLET			:	color_type	:= X"F0F";
	constant YELLOW			:	color_type	:= X"FF0";
	constant TEAL				:	color_type	:= X"088";

	constant LINE_COLOR		:	color_type 	:= WHITE;
	constant INVALID_COLOR	:	color_type	:= RED;
	constant UNDEFINED_COLOR:	color_type	:= TEAL;
	constant EMPTY_COLOR		:	color_type	:= WHITE;
	constant FULL_COLOR		:	color_type	:= BLACK;
	constant NUMBER_COLOR 	:	color_type 	:= WHITE;

	--FUNCTIONS
	function draw_digit ( N : integer range -1 to 9; pixel_x: integer range 0 to 6; pixel_y: integer range 0 to 6 ) return boolean;
	function draw_number ( N : integer range -1 to 19; pixel_x: integer range 0 to 6; pixel_y: integer range 0 to 6 ) return boolean;
	function draw_char ( C : vga_char; pixel_x: integer range 0 to 6; pixel_y: integer range 0 to 6 ) return boolean;

end package;

package body vga_package is

	--FUNCTIONS
	function draw_digit( N : integer range -1 to 9; pixel_x: integer range 0 to 6; pixel_y: integer range 0 to 6 ) return boolean is
	begin
		if(N = 0 and (
			(pixel_x = 1) or
			(pixel_x = 4) or
			((pixel_y = 0 or pixel_y = 6) and pixel_x > 0 and pixel_x < 5))) then
			return true;
		elsif(N = 1 and pixel_x = 3) then
			return true;
		elsif(N = 2 and (
			((pixel_y = 0 or pixel_y = 3 or pixel_y = 6) and pixel_x > 0 and pixel_x < 5)	or
			(pixel_x = 4 and (pixel_y = 1 or pixel_y = 2)) or
			(pixel_x = 1 and (pixel_y = 4 or pixel_y = 5)))) then
			return true;
		elsif(N = 3 and (
			(pixel_x = 4) or
			(pixel_x > 0 and pixel_x < 4 and (pixel_y = 0 or pixel_y = 3 or pixel_y = 6)))) then
			return true;
		elsif(N = 4 and (
			(pixel_x = 4) or
			(pixel_x = 1 and pixel_y >= 0 and pixel_y < 4) or
			(pixel_y = 3 and pixel_x > 0 and pixel_x < 4))) then
			return true;
		elsif(N = 5 and (
			((pixel_y = 0 or pixel_y = 3 or pixel_y = 6) and pixel_x > 0 and pixel_x < 5)	or
			(pixel_x = 1 and (pixel_y = 1 or pixel_y = 2)) or
			(pixel_x = 4 and (pixel_y = 4 or pixel_y = 5)))) then
			return true;
		elsif(N = 6 and (
			(pixel_x = 1) or
			((pixel_y = 0 or pixel_y = 3 or pixel_y = 6) and pixel_x > 0 and pixel_x < 5) or
			(pixel_x = 4 and (pixel_y = 4 or pixel_y = 5)))) then
			return true;
		elsif(N = 7 and (
			(pixel_x = 4) or
			(pixel_y = 0 and pixel_x > 0 and pixel_x < 5))) then
			return true;
		elsif(N = 8 and (
			(pixel_x = 1) or
			(pixel_x = 4) or
			((pixel_y = 0 or pixel_y = 3 or pixel_y = 6) and pixel_x > 0 and pixel_x < 5))) then
			return true;
		elsif(N = 9 and (
			(pixel_x = 4) or
			((pixel_y = 0 or pixel_y = 3 or pixel_y = 6) and pixel_x > 0 and pixel_x < 5) or
			(pixel_x = 1 and (pixel_y = 1 or pixel_y = 2)))) then
			return true;
		else
			return false;
		end if;
		return false;
	end draw_digit;

	function draw_number( N : integer range -1 to 19; pixel_x: integer range 0 to 6; pixel_y: integer range 0 to 6 ) return boolean is
	begin
		if( N > 9 ) then
			if(pixel_x = 0) then
				return true;
			else
				return draw_digit( (N - 10), pixel_x - 1, pixel_y);
			end if;
		else
			return draw_digit(N, pixel_x, pixel_y);
		end if;
		return false;
	end draw_number;

	function draw_char( C : vga_char; pixel_x: integer range 0 to 6; pixel_y: integer range 0 to 6 ) return boolean is
	begin
		if(C = CHAR_L and (
			(pixel_x = 1) or
			(pixel_y = 6 and pixel_x /= 0 and pixel_x /= 6))) then
			return true;
		elsif(C = CHAR_E and (
			(pixel_x = 1) or
			(pixel_y = 0 and pixel_x /= 0 and pixel_x /= 6) or
			(pixel_y = 3 and pixel_x /= 0 and pixel_x < 4) or
			(pixel_y = 6 and pixel_x /= 0 and pixel_x /= 6))) then
			return true;
		elsif(C = CHAR_V and (
			(pixel_y < 2 and (pixel_x = 0 or pixel_x = 6)) or
			(pixel_y > 1 and pixel_y < 4 and (pixel_x = 1 or pixel_x = 5)) or
			(pixel_y > 3 and pixel_y /= 6 and (pixel_x = 2 or pixel_x = 4)) or
			(pixel_y = 6 and pixel_x = 3))) then
			return true;
		elsif(C = CHAR_W and (
			pixel_x = 0 or pixel_x = 3 or
			(pixel_y < 2 and pixel_x = 6) or
			(pixel_y > 1 and pixel_y < 4 and (pixel_x = 2 or pixel_x = 5)) or
			(pixel_y > 3 and pixel_y /= 6 and (pixel_x = 1 or pixel_x = 4)))) then
			return true;
		elsif(C = CHAR_O and (
			(pixel_x = 1 and (pixel_y = 1 or pixel_y = 5)) or
			(pixel_x = 5 and (pixel_y = 1 or pixel_y = 5)) or
			(pixel_y > 1 and pixel_y < 5 and (pixel_x = 0 or pixel_x = 6)) or
			(pixel_x > 1 and pixel_x < 5 and (pixel_y = 0 or pixel_y = 6)))) then
			return true;
		elsif(C = CHAR_N and (
			pixel_x = 0 or pixel_x = 5 or
			(pixel_x /= 6 and (pixel_y = pixel_x or pixel_y = pixel_x + 1)))) then
			return true;
		elsif(C = CHAR_S and (
			(pixel_y = 0 and pixel_x > 1 and pixel_x /= 6) or
			(pixel_y = 6 and pixel_x /= 0 and pixel_x < 5) or
			(pixel_y = 3 and pixel_x > 1 and pixel_x < 5) or
			(pixel_x = 1 and (pixel_y = 1 or pixel_y = 2)) or
			(pixel_x = 5 and (pixel_y = 4 or pixel_y = 5)))) then
			return true;
		elsif(C = CHAR_T and (
			(pixel_x = 3) or
			(pixel_y = 0 and pixel_x /= 0 and pixel_x /= 6))) then
			return true;
		elsif(C = CHAR_I and (
			(pixel_x = 3) or
			((pixel_y = 0 or pixel_y = 6) and (pixel_x = 2 or pixel_x = 4)))) then
			return true;
		elsif(C = CHAR_A and (
			(pixel_y = 4 and pixel_x /= 0 and pixel_x /= 6) or
			(pixel_y > 4 and (pixel_x = 0 or pixel_x = 6)) or
			(pixel_y > 2 and pixel_y < 5 and (pixel_x = 1 or pixel_x = 5)) or
			(pixel_y /= 0 and pixel_y < 3 and (pixel_x = 2 or pixel_x = 4)) or
			(pixel_y = 0 and pixel_x = 3))) then
			return true;
		elsif(C = CHAR_R and (
			(pixel_x = 1) or
			((pixel_y = 0 or pixel_y = 3) and pixel_x < 5 and pixel_x /= 0) or
			(pixel_x = 5 and (pixel_y = 1 or pixel_y = 2)) or
			(pixel_x > 2 and pixel_y > 3 and pixel_x + 1 = pixel_y))) then
			return true;
		else
			return false;
		end if;
		return false;
	end draw_char;
end vga_package;
