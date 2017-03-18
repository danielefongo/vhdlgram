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
		LEVEL					:	out integer;
		
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
	
	type level_update_status_type is (L_IDLE, UPDATING);
	signal level_register					: integer range -1 to MAX_LEVEL - 1 := -1;
	signal level_update_register			: std_logic := '0';
	signal level_update_status				: level_update_status_type := L_IDLE;
	
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
	
	level_select : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			level_update_register <= '1';
			level_register <= -1;
			level_update_status <= L_IDLE;
			LEVEL <= level_register;
		elsif(rising_edge(CLOCK)) then 
			
			if(SW(17) = '1') then
				if(level_register /= 0 and level_update_status = L_IDLE) then
					level_update_register <= '1';
					level_update_status <= UPDATING;
				end if;
				level_register <= 0;
			elsif(SW(16) = '1' ) then
				if(level_register /= 1 and level_update_status = L_IDLE) then
					level_update_register <= '1';
					level_update_status <= UPDATING;
				end if;
				level_register <= 1;
			elsif(SW(15) = '1') then
				if(level_register /= 2 and level_update_status = L_IDLE) then
					level_update_register <= '1';
					level_update_status <= UPDATING;
				end if;
				level_register <= 2;
			else
				if(level_register /= -1 and level_update_status = L_IDLE) then
					level_update_register <= '1';
					level_update_status <= UPDATING;
				end if;
				level_register <= -1;
			end if;

			if(level_update_status = UPDATING) then --TODO: check this
				level_update_register <= '0';
				level_update_status <= L_IDLE;
			end if;
			
			LEVEL <= level_register;
		end if;
	end process;
	
	status_update : process(CLOCK, RESET_N)
	begin
		if(RESET_N = '0') then
			status_register <= IDLE;
			STATUS <= status_register;
		elsif(rising_edge(CLOCK)) then
			if(level_update_register = '1') then
				status_register <= LOAD;
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