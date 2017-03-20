library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.nonogram_package.all;

entity controller is

	port
	(
		CLOCK					: 	in std_logic;
		RESET_N				: 	in std_logic;
		
		SW						:	in std_logic_vector(17 downto 1);
		LEVEL					:	out integer range -1 to MAX_LEVEL - 1;
		
		ACK					:	in status_type;
		STATUS				:	out status_type;
		
		KEY					:	in std_logic_vector(3 downto 2)
	);

end controller;

architecture RTL of controller is

	--signals
	type debounce_status_type is (D_IDLE, BUTTONPRESS, WAITRELEASE);
	signal key2_status	 					: debounce_status_type := D_IDLE;
	signal key3_status 						: debounce_status_type := D_IDLE;
	
	signal solve_iteration_register		: std_logic := '0';
	signal solve_all_register				: std_logic := '0';
	
	type level_update_status_type is (LEVEL_IDLE, LEVEL_UPDATING);
	signal level_register					: integer range -1 to MAX_LEVEL - 1 := -1;
	signal level_update_register			: std_logic := '0';
	signal level_update_status				: level_update_status_type := LEVEL_IDLE;
	
	signal status_register					: status_type := IDLE;

begin
	
	--processes
	key3_debouncer : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			solve_iteration_register <= '0';
			key3_status <= D_IDLE;
		elsif(rising_edge(CLOCK)) then
			case(key3_status) is
				when D_IDLE =>
					if(KEY(3) = '1') then
						key3_status <= BUTTONPRESS;
						solve_iteration_register <= '1';	
					end if;
				when BUTTONPRESS =>
					solve_iteration_register <= '0';
					key3_status <= WAITRELEASE;
				when WAITRELEASE =>
					if(KEY(3) = '0') then 
						key3_status <= D_IDLE;
					end if;
			end case;
		end if;
	end process;
	
	key2_debouncer : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			solve_all_register <= '0';
			key2_status <= D_IDLE;
		elsif(rising_edge(CLOCK)) then
			case(key2_status) is
				when D_IDLE =>
					if(KEY(2) = '1') then
						key2_status <= BUTTONPRESS;
						solve_all_register <= '1';	
					end if;
				when BUTTONPRESS =>
					solve_all_register <= '0';
					key2_status <= WAITRELEASE;
				when WAITRELEASE =>
					if(KEY(2) = '0') then 
						key2_status <= D_IDLE;
					end if;
			end case;
		end if;
	end process;
	
	status_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			status_register <= IDLE;
			STATUS <= IDLE;
		elsif(rising_edge(CLOCK)) then
			/*if(level_update_register = '1') then
				status_register <= LOAD;*/
			if(SW(17 downto 14) = "1000" and level_register /= 0) then
				LEVEL <= 0;
				level_register <= 0;
				status_register <= LOAD;
			elsif(SW(17 downto 14) = "0100" and level_register /= 1) then
				LEVEL <= 1;
				level_register <= 1;
				status_register <= LOAD;
			elsif(SW(17 downto 14) = "0010" and level_register /= 2) then
				LEVEL <= 2;
				level_register <= 2;
				status_register <= LOAD;
			elsif(SW(17 downto 14) = "0001" and level_register /= 3) then
				LEVEL <= 3;
				level_register <= 3;
				status_register <= LOAD;
			elsif(SW(17 downto 14) = "0000") then
				LEVEL <= -1;
				level_register <= -1;
				status_register <= IDLE;
			else
				case(status_register) is
					when IDLE =>
						if(ACK = WON or ACK = LOST) then
							status_register <= ACK;
						elsif(solve_all_register = '1') then
							status_register <= SOLVE_ALL;
						elsif(solve_iteration_register = '1') then
							status_register <= SOLVE_ITERATION;
						else
							status_register <= IDLE;
						end if;
					when LOAD =>
						if(ACK = LOAD) then
							status_register <= IDLE;
						end if;
					when SOLVE_ITERATION | SOLVE_ALL =>
						if(ACK = status_register) then
							status_register <= IDLE;
						elsif(ACK = WON or ACK = LOST) then
							status_register <= ACK;
						end if;
					when WON | LOST =>
						status_register <= status_register;
				end case;
			end if;
			
			STATUS <= status_register;
		end if;
	end process;
	
end architecture;