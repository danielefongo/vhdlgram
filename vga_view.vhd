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
		QUERY					: 	out query_type;
		
		CONSTRAINT_LINE	: 	in constraint_line_type;
		CONSTRAINT_QUERY	: 	out query_type;
			
		LEVEL					: 	in integer range -1 to MAX_LEVEL;
		STATUS				:	in status_type
	);
	
end;

architecture RTL of vga_view is

	--PROCEDURES
	procedure send_color ( color : color_type ) is
	begin
		VGA_R <= color(0 to 7);
		VGA_G <= color(8 to 15);
		VGA_B <= color(16 to 23);
	end send_color;

begin
		
	--PROCESSES
	draw : process(CLOCK, RESET_N)
		variable old_x					: integer range 0 to TOTAL_W := 0;
		variable old_y					: integer range 0 to TOTAL_H := 0;
		variable x						: integer range 0 to VISIBLE_WIDTH := 0;
		variable y						: integer range 0 to VISIBLE_HEIGHT := 0;
		variable rows					: integer range 0 to MAX_LINE;
		variable columns				: integer range 0 to MAX_LINE;
		variable cell_x				: integer range 0 to CELL_SIZE - 1;
		variable cell_y				: integer range 0 to CELL_SIZE - 1;
		variable clue_x				: integer range 0 to MAX_LINE - 1 := 0;
		variable clue_y				: integer range 0 to MAX_LINE - 1 := 0;
		variable clue					: integer range -1 to MAX_CLUE;
		
	begin
		if(RESET_N = '0') then
			old_x := 0;
			old_y := 0;
			x := 0;
			y := 0;
			QUERY <= (0, -1);
			CONSTRAINT_QUERY <= (0, -1);
			VGA_HS <= '0';
			VGA_VS <= '0';
			VGA_SYNC_N <= '1';
			VGA_BLANK_N <= '0';
			send_color(BLACK);
		elsif rising_edge(CLOCK) then
			
			VGA_BLANK_N <= '1';
			VGA_SYNC_N <= '0';
			
			--vertical sync
			if (old_y < VERTICAL_SYNC_PULSE) then 
				VGA_VS <= '0';
			else
				VGA_VS <= '1';
			end if;
			
			--horizontal sync
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
							if(x > 2 * PADDING + CELL_SIZE * columns and x <= 2 * PADDING + CELL_SIZE * columns + CELL_SIZE * MAX_CLUE_LINE and y < PADDING + CELL_SIZE * rows) then
								
								clue_x := (x - 2 * PADDING - CELL_SIZE * columns) / CELL_SIZE;
								clue := CONSTRAINT_LINE(clue_x).size;
								
								cell_x := (x - 2 * PADDING - CELL_SIZE * columns) mod CELL_SIZE;
								cell_y := (y - PADDING) mod CELL_SIZE;
								
								if(clue > -1 and cell_x >= LINE_WIDTH and cell_y >= LINE_WIDTH and draw_number(clue, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) then
									send_color(NUMBER_COLOR);
								else
									send_color(BLACK);
								end if;
								
							--bottom side of the table
							elsif(y > 2 * PADDING + CELL_SIZE * rows and y <= 2 * PADDING + CELL_SIZE * rows + CELL_SIZE * MAX_CLUE_LINE and x < PADDING + CELL_SIZE * columns) then
								
								clue_y := (y - 2 * PADDING - CELL_SIZE * rows) / CELL_SIZE;
								clue := CONSTRAINT_LINE(clue_y).size;
								
								cell_x := (x - PADDING) mod CELL_SIZE;
								cell_y := (y - 2 * PADDING - CELL_SIZE * rows) mod CELL_SIZE;
								
								if(clue > -1 and cell_x >= LINE_WIDTH and cell_y >= LINE_WIDTH and draw_number(clue, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) then
									send_color(NUMBER_COLOR);
								else
									send_color(BLACK);
								end if;
							
							--TODO: elsif show_status
							
							else --rest of the window
								send_color(BLACK);
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
			
			QUERY.transposed <= 0;
			if((y - PADDING) / CELL_SIZE < MAX_LINE) then
				QUERY.index <= (y - PADDING) / CELL_SIZE;
			end if;
			
			if(x > 2 * PADDING + CELL_SIZE * columns and x <= 2 * PADDING + CELL_SIZE * columns + CELL_SIZE * MAX_CLUE_LINE and y > PADDING and y < PADDING + CELL_SIZE * rows) then
				CONSTRAINT_QUERY.transposed <= 0;
				CONSTRAINT_QUERY.index <= (y - PADDING) / CELL_SIZE;
			elsif(y > 2 * PADDING + CELL_SIZE * rows and y <= 2 * PADDING + CELL_SIZE * rows + CELL_SIZE * MAX_CLUE_LINE and x < PADDING + CELL_SIZE * columns) then
				CONSTRAINT_QUERY.transposed <= 1;
				CONSTRAINT_QUERY.index <= (x - PADDING) / CELL_SIZE;
			end if;	
			
		end if;
	end process;
	
end architecture;