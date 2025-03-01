library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-----------------------------------------------------------------
--  Function:
--- MU takes two inputs and mutiplies them
----saves the results in a register 
----sums it up with previous results
----clear signal resets the result to 0
--- For a single P element iterate 8 times.
------------------------------------------------------------------

entity our_MU_unit is 
    port (  clk     : in std_logic;
            rst     : in std_logic;
            MU_enable    : in std_logic;-- enables the MU operation
            clear    : in std_logic; -- resets the results to 0 to start on a new P element

            -- the two inputs for multiplication
            MU_input_X   : in std_logic_vector(7 downto 0);
            MU_input_A : in std_logic_vector(6 downto 0);

            -- sum of multiplication results so far
            MU_result_sum : out std_logic_vector(14 downto 0)
         );
end our_MU_unit;
----------------------------------------------------
architecture behavioral of our_MU_unit is

    signal next_MU_result, current_MU_result : std_logic_vector(14 downto 0);

begin
    ----------------------------------
    -- output logic
    
    -- the output of current calculations are in the next signal
    -- current_results is old results that are used in the multiplicaiton
    -- so its not the output of this cycle

    --MU_result_sum <= next_MU_result;
    MU_result_sum <= current_MU_result;
    ----------------------------------
    -- register process
    process(clk)
    begin
        if rising_edge(clk) then 
            if rst = '1' then -- this is a sychornous reset so 
                              -- this wont give current result a default value before clock
                current_MU_result <= (others => '0');
            else 
                current_MU_result <= next_MU_result;
            end if;
        end if;        
    end process;
    -----------------------------------
    -- combinational logic
    process(MU_input_X, MU_input_A, MU_enable, clear, current_MU_result)
    begin
        --default value
        next_MU_result <= (others => '0');
        -------------------
         if (MU_enable = '1') then
            if (clear = '1') then
                next_MU_result <= MU_input_X * MU_input_A + "000000000000000";
                
            else 
                next_MU_result <= MU_input_X * MU_input_A + current_MU_result;
            end if;
         end if;
         
        --clear signal needs a whole clock cycle on its own
--        if(clear = '1') then
--            next_MU_result <= (others => '0');
--        elsif (MU_enable = '1') then
--            next_MU_result <= MU_input_X * MU_input_A + current_MU_result;
--        end if;
        
    end process;
    -----------------------------------

end behavioral;
---------------------------------------------------------------------------
