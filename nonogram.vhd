library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.nonogram_package.all;

entity nonogram is

   port
	(
		CLOCK_50            	: in  std_logic;

		SW                  	: in  std_logic_vector(9 downto 0);

		KEY                 	: in  std_logic_vector(3 downto 0);

		VGA_R               	: out std_logic_vector(3 downto 0);
		VGA_G               	: out std_logic_vector(3 downto 0);
		VGA_B               	: out std_logic_vector(3 downto 0);
		VGA_HS              	: out std_logic;
		VGA_VS              	: out std_logic;
		--VGA_SYNC_N				: out std_logic;
		--VGA_BLANK_N				: out std_logic;
		--VGA_CLK					: out std_logic;

		--HEX7						: out std_logic_vector(6 downto 0);
		--HEX6						: out std_logic_vector(6 downto 0);
		HEX3						: out std_logic_vector(6 downto 0);
		HEX2						: out std_logic_vector(6 downto 0);
		HEX1						: out std_logic_vector(6 downto 0);
		HEX0						: out std_logic_vector(6 downto 0);

		LEDG						: out std_logic_vector(7 downto 0);
		LEDR						: out std_logic_vector(9 downto 0)
	);

end nonogram;

architecture RTL of nonogram is

	--SIGNALS
	signal clock						: std_logic;
	signal vga_clock					: std_logic;
	signal reset_n						: std_logic;
	signal reset_sync					: std_logic;
	signal level						: integer range -1 to MAX_LEVEL - 1;
	signal status						: status_type;
	signal ack							: status_type;
	signal view_board_query			: query_type;
	signal view_board_line			: line_type;
	signal view_constraint_query	: query_type;
	signal view_constraint_line	: constraint_line_type;

	signal board_query				: query_type;
	signal board_w_not_r				: std_logic;
	signal board_in_line				: line_type;
	signal board_out_line			: line_type;
	signal constraint_query			: query_type;
	signal constraint_w_not_r		: std_logic;
	signal constraint_in_line		: constraint_line_type;
	signal constraint_out_line		: constraint_line_type;
	signal iteration					: integer range 0 to MAX_ITERATION;
	signal undefined_cells			: integer range 0 to MAX_LINE * MAX_LINE;

begin

	--ENTITIES
	--pll
	pll: entity work.PLL
		port map
		(
				inclk0	=> CLOCK_50,
				c0			=> clock,
				c1			=> vga_clock
		);

	--views
	vga_view : entity work.vga_view
		port map
		(
			CLOCK						=> vga_clock,
			RESET_N					=> reset_n,
			VGA_R						=> VGA_R,
			VGA_G						=> VGA_G,
			VGA_B						=> VGA_B,
			VGA_HS					=> VGA_HS,
			VGA_VS					=> VGA_VS,
			--VGA_SYNC_N				=> VGA_SYNC_N,
			--VGA_BLANK_N				=> VGA_BLANK_N,

			ROW_DESCRIPTION		=> view_board_line,
			QUERY						=> view_board_query,

			CONSTRAINT_LINE		=> view_constraint_line,
			CONSTRAINT_QUERY		=> view_constraint_query,

			LEVEL						=> level,
			ITERATION       => iteration,
			STATUS					=> status
		);

	hex_view : entity work.hex_view
		port map
		(
			CLOCK						=> vga_clock,
			RESET_N					=> reset_n,

			--ITERATION				=> iteration,
			UNDEFINED_CELLS		=> undefined_cells,

			--HEX7						=> HEX7,
			--HEX6						=> HEX6,
			HEX3						=> HEX3,
			HEX2						=> HEX2,
			HEX1						=> HEX1,
			HEX0						=> HEX0
		);

	--controllers
	input_controller : entity work.input_controller
		port map
		(
			CLOCK						=> clock,
			RESET_N					=> reset_n,

			SW							=> SW(9 downto 1),
			LEVEL						=> level,

			ACK						=> ack,
			STATUS					=> status,

			KEY						=> KEY(3 downto 2)
		);

	game_controller : entity work.game_controller
		port map
		(
			CLOCK							=> clock,
			RESET_N						=> reset_n,

			LEVEL							=> level,
			STATUS						=> status,
			ACK							=> ack,

			ITERATION					=> iteration,

			BOARD_QUERY					=> board_query,
			BOARD_W_NOT_R				=> board_w_not_r,
			BOARD_INPUT_LINE			=> board_in_line,
			BOARD_OUTPUT_LINE			=> board_out_line,
			UNDEFINED_CELLS			=> undefined_cells,

			CONSTRAINT_QUERY			=> constraint_query,
			CONSTRAINT_W_NOT_R		=> constraint_w_not_r,
			CONSTRAINT_INPUT_LINE	=> constraint_in_line,
			CONSTRAINT_OUTPUT_LINE	=> constraint_out_line
		);

	--datapaths
	board_datapath : entity work.board_datapath
		port map
		(
			CLOCK						=> clock,
			RESET_N					=> reset_n,

			QUERY						=> board_query,
			W_NOT_R					=> board_w_not_r,
			INPUT_LINE				=> board_in_line,
			OUTPUT_LINE				=> board_out_line,

			VIEW_QUERY				=> view_board_query,
			VIEW_OUTPUT_LINE		=> view_board_line,

			UNDEFINED_CELLS		=> undefined_cells
		);

	constraints_datapath : entity work.constraints_datapath
		port map
		(
			CLOCK						=> clock,
			RESET_N					=> reset_n,

			QUERY						=> constraint_query,
			W_NOT_R					=> constraint_w_not_r,
			INPUT_LINE				=> constraint_in_line,
			OUTPUT_LINE				=> constraint_out_line,

			VIEW_QUERY				=> view_constraint_query,
			VIEW_OUTPUT_LINE		=> view_constraint_line
		);

	--PROCESSES
	reset : process(clock)
	begin
		if(rising_edge(clock)) then
			reset_sync <= SW(0);
			reset_n <= reset_sync;
		end if;
	end process;

	/*
	vga_clock_forward : process(vga_clock)
	begin
		VGA_CLK <= vga_clock;
	end process;
	*/
	
	--DEBUGGING
	--TODO: remove this
	led_status_debug : process(clock, reset_n)
	begin
		if(reset_n = '0') then
			LEDG <= "00000000";
		elsif(rising_edge(clock)) then
			case(status) is
				when IDLE =>
					LEDG <= "01000000";
				when LOAD =>
					LEDG <= "00100000";
				when SOLVE_ITERATION =>
					LEDG <= "00010000";
				when SOLVE_ALL =>
					LEDG <= "00001000";
				when WON	=>
					LEDG <= "00000100";
				when LOST =>
					LEDG <= "00000010";
			end case;
		end if;
	end process;

	led_level_debug : process(clock, reset_n)
	begin
		if(reset_n = '0') then
			LEDR <= (others => '0');
		elsif(rising_edge(clock)) then
			case(level) is
				when -1 =>
					LEDR(0) <= '1';
					LEDR(9 downto 1) <= (others => '0');
				when 0 =>
					LEDR(9) <= '1';
					LEDR(8 downto 0) <= (others => '0');
				when 1 =>
					LEDR(9 downto 8) <= "01";
					LEDR(7 downto 0) <= (others => '0');
				when 2 =>
					LEDR(9 downto 7) <= "001";
					LEDR(6 downto 0) <= (others => '0');
				when 3 =>
					LEDR(9 downto 6) <= "0001";
					LEDR(5 downto 0) <= (others => '0');
				when 4 =>
					LEDR(9 downto 5) <= "00001";
					LEDR(4 downto 0) <= (others => '0');
				when 5 =>
					LEDR(9 downto 4) <= "000001";
					LEDR(3 downto 0) <= (others => '0');
				when 6 =>
					LEDR(9 downto 3) <= "0000001";
					LEDR(2 downto 0) <= (others => '0');
				when 7 =>
					LEDR(9 downto 2) <= "00000001";
					LEDR(1 downto 0) <= (others => '0');
			end case;
		end if;
	end process;

end architecture;
