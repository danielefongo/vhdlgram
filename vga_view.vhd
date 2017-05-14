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
		VGA_R					: 	out std_logic_vector(3 downto 0);
		VGA_G					: 	out std_logic_vector(3 downto 0);
		VGA_B					: 	out std_logic_vector(3 downto 0);
		--VGA_BLANK_N			: 	out std_logic;
		--VGA_SYNC_N			: 	out std_logic;

		ROW_DESCRIPTION	:	in	line_type;
		QUERY					: 	out query_type;

		CONSTRAINT_LINE	: 	in constraint_line_type;
		CONSTRAINT_QUERY	: 	out query_type;

		LEVEL					: 	in integer range -1 to MAX_LEVEL;
		ITERATION			: in integer range 0 to MAX_ITERATION;
		STATUS				:	in status_type
	);

end;

architecture RTL of vga_view is

	--PROCEDURES
	procedure send_color ( color : color_type ) is
	begin
		VGA_R <= color(0 to 3);
		VGA_G <= color(4 to 7);
		VGA_B <= color(8 to 11);
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
		variable status_x				: integer range 0 to VISIBLE_WIDTH / CELL_SIZE := 0;
		variable status_y				: integer range 0 to VISIBLE_HEIGHT / CELL_SIZE := 0;
		
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
			--VGA_SYNC_N <= '1';
			--VGA_BLANK_N <= '0';
			send_color(BLACK);
		elsif rising_edge(CLOCK) then

			--VGA_BLANK_N <= '1';
			--VGA_SYNC_N <= '0';

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

							--show status and level
							elsif(y > 2 * PADDING + CELL_SIZE * rows and x > 2 * PADDING + CELL_SIZE * columns) then

								--variable usage optimization
								status_x := (x - 2 * PADDING - CELL_SIZE * columns) / CELL_SIZE;
								status_y := (y - 2 * PADDING - CELL_SIZE * rows) / CELL_SIZE;

								cell_x := (x - 2 * PADDING - CELL_SIZE * columns) mod CELL_SIZE;
								cell_y := (y - 2 * PADDING - CELL_SIZE * rows) mod CELL_SIZE;

								if(cell_x >= LINE_WIDTH and cell_y >= LINE_WIDTH) then
									--DRAW LEVEL
									if(status_y = 1) then
										if(((status_x = 1 or status_x = 5) and draw_char(CHAR_L, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											((status_x = 2 or status_x = 4) and draw_char(CHAR_E, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 3 and draw_char(CHAR_V, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH))) then
											send_color(TEAL);
										elsif(status_x = 12 and draw_number(LEVEL, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) then
											send_color(WHITE);
										else
											send_color(BLACK);
										end if;
									--DRAW ITERATION
									elsif(status_y = 2) then
										if(((status_x = 1 or status_x = 7) and draw_char(CHAR_I, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											((status_x = 2 or status_x = 6) and draw_char(CHAR_T, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 3 and draw_char(CHAR_E, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 4 and draw_char(CHAR_R, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 5 and draw_char(CHAR_A, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 8 and draw_char(CHAR_O, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 9 and draw_char(CHAR_N, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH))) then
											send_color(TEAL);
										elsif((status_x = 11 and ITERATION > 9 and draw_digit(ITERATION / 10, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 12 and draw_digit(ITERATION mod 10, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH))) then
											send_color(WHITE);
										else
											send_color(BLACK);
										end if;
									--DRAW STATUS
									elsif(status_y = 4 and STATUS = WON) then
										if((status_x = 10 and draw_char(CHAR_W, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 11 and draw_char(CHAR_O, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 12 and draw_char(CHAR_N, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH))) then
											send_color(GREEN);
										else
											send_color(BLACK);
										end if;
									elsif(status_y = 4 and STATUS = LOST) then
										if((status_x = 9 and draw_char(CHAR_L, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 10 and draw_char(CHAR_O, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 11 and draw_char(CHAR_S, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH)) or
											(status_x = 12 and draw_char(CHAR_T, cell_x - LINE_WIDTH, cell_y - LINE_WIDTH))) then
											send_color(RED);
										else
											send_color(BLACK);
										end if;
									else
										send_color(BLACK);
									end if;
								else
									send_color(BLACK);
								end if;

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
