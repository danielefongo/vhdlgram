library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vga_package.all;
use work.nonogram_package.all;

entity vga_view is
	
	port 
	(
		CLOCK					: 	in std_logic;
		RESET_N				: 	in std_logic;
		VGA_HS				: 	out std_logic;
		VGA_VS				: 	out std_logic;
		VGA_R					: 	out std_logic_vector(7 downto 0);
		VGA_G					: 	out std_logic_vector(7 downto 0);
		VGA_B					: 	out std_logic_vector(7 downto 0);
		VGA_BLANK_N			: 	out std_logic;
		VGA_SYNC_N			: 	out std_logic;
		
		ROW_DESCRIPTION	:	in	line_type;
		ROW_INDEX			: 	out integer;
		
		LEVEL					: 	in integer;
		STATUS				:	in status_type
	);
	
	--procedures
	procedure send_color ( color : color_type ) is
	begin
		VGA_R <= color(0 to 7);
		VGA_G <= color(8 to 15);
		VGA_B <= color(16 to 23);
	end send_color;
	
end;

architecture RTL of vga_view is

begin
		
	--processes
	draw : process(CLOCK, RESET_N)
		variable old_x					: integer range 0 to TOTAL_W := 0;
		variable old_y					: integer range 0 to TOTAL_H := 0;
		variable x						: integer range 0 to VISIBLE_WIDTH := 0;
		variable y						: integer range 0 to VISIBLE_HEIGHT := 0;
		variable rows					: integer range 0 to MAX_COLUMN;
		variable columns				: integer range 0 to MAX_ROW;
		variable cell_x				: integer range 0 to CELL_SIZE - 1;
		variable cell_y				: integer range 0 to CELL_SIZE - 1;
		variable clue_x				: integer range 0 to MAX_ROW := 0;
		variable clue_y				: integer range 0 to MAX_COLUMN := 0;
		variable clue					: clue_type;
		
	begin
		
		if(RESET_N = '0') then
			old_x := 0;
			old_y := 0;
			x := 0;
			y := 0;
			VGA_HS <= '0';
			VGA_VS <= '0';
			VGA_SYNC_N <= '1';
			VGA_BLANK_N <= '0';
			send_color(BLACK);
		elsif rising_edge(CLOCK) then
			
			VGA_BLANK_N <= '1';
			VGA_SYNC_N <= '0';
			
			--Vertical sync
			if (old_y < VERTICAL_SYNC_PULSE) then 
				VGA_VS <= '0';
			else
				VGA_VS <= '1';
			end if;
			
			--Horizontal sync
			if (old_x < HORIZONTAL_SYNC_PULSE) then 
				VGA_HS <= '0';
			else
				VGA_HS <= '1';
			end if;
			
			--invalid level
			if(level < 0) then
				send_color(BLACK);
			else --valid level
				rows := LEVEL_INPUT(level).dim(1);
				columns := LEVEL_INPUT(level).dim(0);
				
				--inside the visible window
				if(old_x >= WINDOW_HORIZONTAL_START and old_x < WINDOW_HORIZONTAL_END and old_y >= WINDOW_VERTICAL_START and old_y < WINDOW_VERTICAL_END) then
					x := old_x - WINDOW_HORIZONTAL_START;
					y := old_y - WINDOW_VERTICAL_START;
					
					--draw window
					if(x >= PADDING and x < VISIBLE_WIDTH - PADDING and y >= PADDING and y < VISIBLE_HEIGHT - PADDING) then
						
						--draw table
						if(x - PADDING < CELL_SIZE * columns + LINE_WIDTH and y - PADDING < CELL_SIZE * rows + LINE_WIDTH) then
							
							cell_x := (x - PADDING) mod CELL_SIZE;
							cell_y := (y - PADDING) mod CELL_SIZE;
							
							if(cell_x < LINE_WIDTH or cell_y < LINE_WIDTH) then
								send_color(LINE_COLOR);
							else
								case(ROW_DESCRIPTION((x - PADDING) / CELL_SIZE)) is
									when INVALID =>
										send_color(INVALID_COLOR);
									when UNDEFINED =>
										send_color(UNDEFINED_COLOR);
									when EMPTY =>
										send_color(EMPTY_COLOR);
									when FULL =>
										send_color(FULL_COLOR);
								end case;
							end if;
						else --not draw table
						
							--right side of the table			
							if(x > 2 * PADDING + CELL_SIZE * columns and x <= 2 * PADDING + CELL_SIZE * columns + CELL_SIZE * get_clue_line_length(level, 0, (y - PADDING) / CELL_SIZE) and y < PADDING + CELL_SIZE * rows) then
								
								clue_x := (x - 2 * PADDING - CELL_SIZE * columns) / CELL_SIZE;
								clue_y := (y - PADDING) / CELL_SIZE;
								clue := LEVEL_INPUT(level).clues(0, clue_y, clue_x);
								cell_x := (x - 2 * PADDING - CELL_SIZE * columns) mod CELL_SIZE;
								cell_y := (y - PADDING) mod CELL_SIZE;
								
								if(clue > 0 and cell_x >= LINE_WIDTH and cell_y >= LINE_WIDTH and draw_number(clue, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) then
									send_color(NUMBER_COLOR);
								else
									send_color(BLACK);
								end if;
								
							--bottom side of the table
							elsif(y > 2 * PADDING + CELL_SIZE * rows and y <= 2 * PADDING + CELL_SIZE * rows + CELL_SIZE * get_clue_line_length(level, 1, (x - PADDING) / CELL_SIZE) and x < PADDING + CELL_SIZE * columns) then
								
								clue_x := (x - PADDING) / CELL_SIZE;
								clue_y := (y - 2 * PADDING - CELL_SIZE * rows) / CELL_SIZE;
								clue := LEVEL_INPUT(level).clues(1, clue_x, clue_y);
								cell_x := (x - PADDING) mod CELL_SIZE;
								cell_y := (y - 2 * PADDING - CELL_SIZE * rows) mod CELL_SIZE;
								
								if(clue > 0 and cell_x >= LINE_WIDTH and cell_y >= LINE_WIDTH and draw_number(clue, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) then
									send_color(NUMBER_COLOR);
								else
									send_color(BLACK);
								end if;
							
							-- TODO: elsif show_status
							
							else --rest of the window
								send_color(BLACK); --TODO: change to black.
							end if;
						end if;
					end if;
				else --outside visible screen
					send_color(BLACK);
				end if;
			end if;
			
			--update coordinates
			if(old_x = TOTAL_W - 1) then			
				if(old_y = TOTAL_H - 1) then 
					old_y := 0;
				else
					old_y := old_y + 1;
				end if;
				old_x := 0;
			else
				old_x := old_x + 1;
			end if;
			
			ROW_INDEX <= (y - PADDING) / CELL_SIZE;
			
		end if;
	end process;
	
end architecture;