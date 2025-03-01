library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

 
entity controller_with_shift is 
    port (  clk           : in std_logic;
            rst           : in std_logic;
            ----------------------------------------
            external_input_x: in std_logic_vector(7 downto 0);
            valid_input   : in std_logic;
            ----- read_operation -------------------
            -- read OP
            -- this operation does nothing in controller other than passing through to RAM ctrl
            -- which immediately starts reading -- the address will get passed through TOP file
            -- directly to RAM and does not go through the controller
            read_command  : in  std_logic;
            finished_reading : in std_logic;
            ----------------------------------------
            ctrl_idle_ready_to_read  : out std_logic;
            load          : out std_logic;   
            results_p1    : out std_logic_vector(14 downto 0);
            results_p2    : out std_logic_vector(14 downto 0);
            results_p3    : out std_logic_vector(14 downto 0);
            results_p4    : out std_logic_vector(14 downto 0)
         );
end controller_with_shift; 

architecture behavioral of controller_with_shift is
---------------------------------------------------------------------------------------------------
-- SIGNALS

    type state_type is (idle, shift_state, multiply_state, flush_results, read_state); --not sure about this.
    signal current_state : state_type := idle;
    signal next_state : state_type;

    --shift register
    signal total_shift_counter              : std_logic_vector (4 downto 0) := "00000";
    signal next_total_shift_counter         : std_logic_vector (4 downto 0):= "00000";
    signal selected_shifter                 : std_logic_vector (1 downto 0) := "00";
    signal next_selected_shifter            : std_logic_vector (1 downto 0);
    signal shift_enable_1, shift_enable_2, shift_enable_3, shift_enable_4 : std_logic;
    signal get_input_en_1, get_input_en_2, get_input_en_3, get_input_en_4 : std_logic;
    signal shifter_output_i_1, shifter_output_i_2, shifter_output_i_3, shifter_output_i_4   : std_logic_vector(7 downto 0);
    signal shifter_delayed_input, next_shifter_delayed_input   : std_logic_vector(7 downto 0);   

    -- increment a row (8 times) connect them to signal x_col_i
    signal x_col_i_unit_12, next_x_col_i_unit_12 : std_logic_vector (2 downto 0):= "000";
    signal x_col_i_unit_34, next_x_col_i_unit_34 : std_logic_vector (2 downto 0):= "000";  
    signal x_col_i                          : std_logic_vector(2 downto 0):= "000";
    signal A_col, next_A_col                : std_logic_vector(2 downto 0):= "000";

    --ROM
    signal rom_address, next_rom_address    : std_logic_vector(3 downto 0):= "0000";
    signal ROM_out_A_coef                   : std_logic_vector(13 downto 0);
    signal increment_ROM_flag ,next_increment_ROM_flag : std_logic:= '0';

    --MU units
    signal MU_enable                        : std_logic;
    signal clear, next_clear                : std_logic:= '0';
    signal MU_input_X_1, MU_input_X_2       : std_logic_vector(7 downto 0);
    signal MU_input_A                       : std_logic_vector(6 downto 0);
    signal MU_result_sum_1, MU_result_sum_2 : std_logic_vector(14 downto 0);
    --toggle flag to swith MU units
    signal switch_MU_units ,next_switch_MU_units : std_logic:= '0';
    --signal to track MU results for simulator
 
    signal results_p1_MU ,results_p2_MU: std_logic_vector(14 downto 0);
    signal next_results_p1_MU ,next_results_p2_MU: std_logic_vector(14 downto 0);

    signal results_p3_MU, results_p4_MU: std_logic_vector(14 downto 0);
    signal next_results_p3_MU ,next_results_p4_MU: std_logic_vector(14 downto 0);
    -- Load=1 means resutls ready for RAM
    signal current_load ,next_load : std_logic:= '0';
    -- Latch=1 means the first two MU unit results are ready
    signal current_latch_result ,next_latch_result : std_logic_vector (1 downto 0):= "00";
    -- state to take the last two results of the P matrix before going back to idle state
    signal flush_counter ,next_flush_counter: std_logic_vector (1 downto 0):= "00";

     
-- COMPs 
---------------------------------------------------------------------------------------------------
 
    component our_shifter is 
        port (  clk             : in std_logic;
                rst             : in std_logic;
                shift_enable    : std_logic;
                get_input_en    : in std_logic;
                x_col_i     : in std_logic_vector (2 downto 0);
                external_input  : in std_logic_vector(7 downto 0);
                shifter_output_i: out std_logic_vector(7 downto 0)
             );
    end component; 

    component our_MU_unit is
        port (  clk          : in std_logic;
                rst          : in std_logic;
                MU_enable    : in std_logic;
                clear        : in std_logic; 
                MU_input_X   : in std_logic_vector(7 downto 0);
                MU_input_A   : in std_logic_vector(6 downto 0);
                MU_result_sum: out std_logic_vector(14 downto 0)
             );
    end component;


    component A_ROM  is
        port (  clk            : in std_logic;
                rom_address    : in std_logic_vector(3 downto 0);
                ROM_out_A_coef : out std_logic_vector(13 downto 0)
            );
    end component;

---------------------------------------------------------------------------------------------------
begin
------------------------------------------
-- output block 
-- 4 registers save the column and then send it to RAM
output: process (MU_result_sum_1,MU_result_sum_2,next_results_p1_MU, next_results_p2_MU, next_results_p3_MU, next_results_p4_MU, current_load, current_latch_result)
begin
        if (current_load = '1') then
            results_p1 <= next_results_p1_MU;
            results_p2 <= next_results_p2_MU; 
            results_p3 <= next_results_p3_MU;
            results_p4 <= next_results_p4_MU;
            load       <= current_load;
        else 
            results_p1 <= (others =>'0');
            results_p2 <= (others =>'0');
            results_p3 <= (others =>'0');
            results_p4 <= (others =>'0');
            load       <= '0';
        end if;
        --------------------------------------------------------
        -- counter is inside the multiply state 
            if  current_latch_result ="01" then 
                next_results_p1_MU <= MU_result_sum_1; 
                next_results_p2_MU <= MU_result_sum_2; 
                
            elsif current_latch_result ="10" then 
                next_results_p3_MU <= MU_result_sum_1; 
                next_results_p4_MU <= MU_result_sum_2;
                next_load <= '1'; -- this causes load to activate 1 clk cycle after results are latches
                            -- we have to do this since now the MU results are delayed by one
                            -- clock cycle, and they get latched 1 clk delayed so have to be loaded
                            -- with 2 clk cycle delays
            else 
                --we do not need to reset next_results_MU values
                next_load <= '0';
            end if;
end process; 

---------------------------------------------------------------------------------------------------
    state_logic : process(current_state, x_col_i_unit_34, valid_input,total_shift_counter,shifter_output_i_1, shifter_output_i_2, shifter_output_i_3, shifter_output_i_4, flush_counter, read_command, next_A_col, finished_reading)
    begin 
        -- default values and default r <-- r operation
        ctrl_idle_ready_to_read <= '0';
        next_state <= current_state;
        -----------------------------
        case current_state is
            when idle =>
                -----------
            	ctrl_idle_ready_to_read <= '1';
                -----------
                
                if (valid_input = '1') then 
                    next_state <= shift_state;
                elsif (read_command = '1') then 
                    next_state <= read_state;
                end if; 
            ---------------------------------------
            when shift_state =>
                -- 32 clock cycles 
                if (total_shift_counter = "11111") then --31
                    next_state <= multiply_state;
                    
                end if;
            ---------------------------------------
            when multiply_state =>  
            -- we use next value to avoid waisting a cycle
                if next_A_col="100" then
                    next_state <= flush_results;
                else
                    next_state <= multiply_state;
                end if;
            ---------------------------------------   
            when flush_results =>
                if flush_counter = "01" then
                    next_state <= idle;
                else 
                    next_state <= flush_results;  
                end if;
            ---------------------------------------
            when read_state =>
            -- no operation here just control signals
            -- one way to exit: ready_ram_read_finished =1
                if(finished_reading = '1') then 
                    next_state <= idle;
                end if;

        end case;               
    end process;
---------------------------------------------------------------------------------------------------
our_shifter_controller : process(clear, rom_address,get_input_en_1,get_input_en_2,get_input_en_3,get_input_en_4,shift_enable_1,shift_enable_2,shift_enable_3,shift_enable_4,external_input_x,x_col_i_unit_12, x_col_i_unit_34, selected_shifter, total_shift_counter, current_state, shifter_output_i_1, shifter_output_i_2, shifter_output_i_3, shifter_output_i_4, clk, flush_counter, next_flush_counter, next_latch_result,current_latch_result, switch_MU_units, increment_rom_flag, ROM_out_A_coef, A_col)
begin 
    -- default all shifters disabled
    shift_enable_1 <= '0';
    shift_enable_2 <= '0';
    shift_enable_3 <= '0';
    shift_enable_4 <= '0';

    -- no data retrieval in shift state
    get_input_en_1 <= '0';
    get_input_en_2 <= '0';
    get_input_en_3 <= '0';
    get_input_en_4 <= '0';
    next_latch_result <= "00";


    next_selected_shifter <= selected_shifter;
    next_flush_counter  <= "00"; 
    next_total_shift_counter <= total_shift_counter;
    --delay input sampling by 1 clk cycle
    next_shifter_delayed_input <= external_input_x;

    case current_state is
        when idle =>
        -- reset operations
            -- we want these to keep staying reset with future clk cycles as long
            -- as we are in idle state
            next_clear <= '1';
            next_rom_address <= "0000";
            next_increment_rom_flag  <='0';
            next_switch_MU_units <='0';
            next_A_col <="000";

        when shift_state =>
            -------------------------------
            --toggle between shifters
            next_selected_shifter <= selected_shifter + 1;
            --count total data inputs (max 32)
            next_total_shift_counter <= total_shift_counter +1;
            -------------------------------
            case selected_shifter is 
                when "00" =>
                    shift_enable_1 <= '1';
                when "01" =>
                    shift_enable_2 <= '1';
                when "10" =>
                    shift_enable_3 <= '1';
                when "11" =>
                    shift_enable_4 <= '1';
                when others => 
            end case;

            if (total_shift_counter = "11111") then --31
                next_total_shift_counter <= "00000";
                
            end if;
            -------------------------------
        when multiply_state =>
            -- we want clear to stay 0 only in this state so we cant have it in the default assignment
            -- but also here if gets overridden whenever needed.
            next_clear <= '0';
            --in parallel
            MU_enable <= '1';            
            -- first check in controller if all 4 A columns are done
            --YES: next_state:idle
            --NO: next_state_multiply
            
            

                ---X-iteration, switch condition and X-input
                if switch_MU_units = '0' then
                        -------MU 1 and 2 ------------------------
                        -- choose MU12_X inputs
                        get_input_en_1 <= '1';
                        get_input_en_2 <= '1';
                        MU_input_x_1 <= shifter_output_i_1; 
                        MU_input_x_2 <= shifter_output_i_2;
                        
                        -----------------------------------------
                        --counters increment i index
                        next_x_col_i_unit_12 <= x_col_i_unit_12 + 1;
                        x_col_i <= x_col_i_unit_12;
                        -- keep other counter zero
                        next_x_col_i_unit_34 <= (others => '0');
                        -- toggle every cycle to increment ROM every 2 cycles
                        next_increment_rom_flag <= not increment_rom_flag; 
                        -----------------------------------------
                        -- choose MU12_A inputs
                        if increment_rom_flag ='1' then
                            next_rom_address <= rom_address +1;
                            MU_input_A <= ROM_out_A_coef (6 downto 0);
                        else
                            MU_input_A <= ROM_out_A_coef (13 downto 7);
                        end if;
                        -----------------------------------------
                        -- Switch and reset every 8th cycles:
                        if x_col_i_unit_12 = "111" then
                            next_switch_MU_units <= not switch_MU_units; 
                            next_clear <='1';
                            -- here always reset ROM adress to use again for MU 3 and 4
                            next_rom_address <= rom_address -3;
                            -- track for simulator
                            next_latch_result <= "01";
                        end if; 
                        -----------------------------------------
                else -- switch <= 1
                        -------MU 3 and 4 ------------------------
                        -- choose MU34_X input
                        get_input_en_3 <= '1';
                        get_input_en_4 <= '1';
                        MU_input_x_1 <= shifter_output_i_3; 
                        MU_input_x_2 <= shifter_output_i_4;
                        -----------------------------------------
                        --counters increment i index
                        next_x_col_i_unit_34 <= x_col_i_unit_34 + 1;
                        x_col_i <= x_col_i_unit_34;
                        -- keep other counter zero
                        next_x_col_i_unit_12 <= (others => '0');
                        -- toggle every cycle to increment ROM every 2 cycles
                        next_increment_rom_flag <= not increment_rom_flag; 
                        -----------------------------------------
                        -- choose MU34 A_input
                        if increment_rom_flag ='1' then
                            next_rom_address <= rom_address +1;
                            MU_input_A <= ROM_out_A_coef (6 downto 0);
                        else
                            MU_input_A <= ROM_out_A_coef (13 downto 7);
                        end if;
                        -----------------------------------------
                        -- check switch condition
                        if x_col_i_unit_34 = "111" then
                            next_switch_MU_units <= not switch_MU_units;
                            next_clear <='1';
                            -- here always increment A column, ROM adress now continues
                            next_A_col <= A_col +1;
                            -- track for simulator
                            next_latch_result <= "10";    
                        end if; 
                        -----------------------------------------   
                end if;
             --------------------------------------------------------------
        when flush_results =>
            next_flush_counter <= flush_counter +1;
            
        when read_state =>
            
        when others =>
    end case;
end process; 
------------------------------------------------------------
-- below we have the following:
-- shifters
-- counter register
-- state register
----------------------------------------------
---internal registers with sync reset 

reg : process  (clk,rst ) 
begin 
    if rising_edge(clk) then 
        if rst = '1' then

            selected_shifter    <= (others => '0');
            total_shift_counter <= (others => '0');
            shifter_delayed_input <=(others => '0');
            ------ROM-----------------------
            x_col_i_unit_12     <= (others => '0'); 
            x_col_i_unit_34     <= (others => '0');      
            A_col               <= (others => '0');
            rom_address         <= (others => '0');
            ------MU-----------------------            
            switch_MU_units     <= '0'; 
            increment_ROM_flag  <= '0';
            clear               <= '0';  
            ------RAM-----------------------
            results_p1_MU       <= (others => '0');
            results_p2_MU       <= (others => '0');
            results_p3_MU       <= (others => '0');
            results_p4_MU       <= (others => '0');
            current_load                <= '0';
            current_latch_result        <= "00";
            flush_counter       <= (others => '0'); 
        else 
            selected_shifter    <= next_selected_shifter;
            total_shift_counter <= next_total_shift_counter;
            shifter_delayed_input<= next_shifter_delayed_input;
            -----------------------------
            x_col_i_unit_12     <= next_x_col_i_unit_12;
            x_col_i_unit_34     <= next_x_col_i_unit_34;
            A_col               <= next_A_col;
            rom_address         <= next_rom_address;
            -----------------------------
            switch_MU_units     <= next_switch_MU_units;
            increment_ROM_flag  <= next_increment_ROM_flag; 
            clear               <= next_clear; 
            -----------------------------
            results_p1_MU       <= next_results_p1_MU; 
            results_p2_MU       <= next_results_p2_MU; 
            results_p3_MU       <= next_results_p3_MU; 
            results_p4_MU       <= next_results_p4_MU; 
            current_load        <= next_load;
            current_latch_result<= next_latch_result;
            flush_counter       <= next_flush_counter;      
        end if;
    end if;
    
end process;  
----------------------------------------------
-- FSM register
state_reg : process  ( clk, rst, next_state ) 
begin 
    if rst = '1' then
        current_state <= idle;
    elsif rising_edge(clk) then 
        current_state <= next_state;
    end if;
end process; 
----------------------------------------------
our_shifter_1 : our_shifter
port map(  
    clk     => clk,
    rst     => rst,
    shift_enable => shift_enable_1,
    get_input_en =>   get_input_en_1,  
    x_col_i =>       x_col_i,   
    external_input =>     shifter_delayed_input,
    shifter_output_i =>  shifter_output_i_1
);
----------------------------------------------
our_shifter_2 : our_shifter
port map(  
    clk     => clk,
    rst     => rst,
    shift_enable => shift_enable_2,
    get_input_en =>   get_input_en_2,  
    x_col_i =>       x_col_i,   
    external_input =>     shifter_delayed_input,
    shifter_output_i =>  shifter_output_i_2
);
----------------------------------------------
our_shifter_3 : our_shifter
port map(  
    clk     => clk,
    rst     => rst,
    shift_enable => shift_enable_3,
    get_input_en =>   get_input_en_3,  
    x_col_i =>       x_col_i,   
    external_input =>     shifter_delayed_input,
    shifter_output_i =>  shifter_output_i_3
);
----------------------------------------------
our_shifter_4 : our_shifter
port map(  
    clk     => clk,
    rst     => rst,
    shift_enable => shift_enable_4,
    get_input_en =>   get_input_en_4,  
    x_col_i =>       x_col_i,   
    external_input =>     shifter_delayed_input,
    shifter_output_i =>  shifter_output_i_4
    );
----------------------------------------------
our_MU_unit_1 : our_MU_unit
port map(  
    clk     => clk,
    rst     => rst,
    MU_enable => MU_enable,
    clear => clear,
    MU_input_X => MU_input_X_1,
    MU_input_A => MU_input_A,
    MU_result_sum => MU_result_sum_1 
    );
----------------------------------------------
our_MU_unit_2 : our_MU_unit
port map(  
    clk     => clk,
    rst     => rst,
    MU_enable => MU_enable,
    clear => clear,
    MU_input_X => MU_input_X_2,
    MU_input_A => MU_input_A,
    MU_result_sum => MU_result_sum_2 
    );
----------------------------------------------
A_ROM_comp : A_ROM
port map (  
    clk     => clk,
    rom_address => next_rom_address,
    ROM_out_A_coef =>  ROM_out_A_coef
    );
----------------------------------------------

end behavioral;