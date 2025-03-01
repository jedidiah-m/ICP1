library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity our_shifter is 
    port (  clk               : in std_logic;
            rst               : in std_logic;
            
            -- enable shift or data access operation
            shift_enable      : in std_logic;
            get_input_en   : in std_logic;

            -- address of the register we want to access
            x_col_i         : in std_logic_vector (2 downto 0);

            -- inputs in matlab file
            external_input    : in std_logic_vector(7 downto 0);

            -- output: a single coefficinet of matrix X
            shifter_output_i  : out std_logic_vector(7 downto 0)
         );
end entity; 
----------------------------------------------------------------------------
architecture behavioral of our_shifter is

signal input_x_0,input_x_1,input_x_2,input_x_3,input_x_4,input_x_5,input_x_6,input_x_7 : std_logic_vector(7 downto 0);

begin

    --sequential shift process-------------------------------------
    reg : process  ( clk, rst, shift_enable, external_input, input_x_0, input_x_1, input_x_2, input_x_3, input_x_4,input_x_5, input_x_6) 
    begin 
        if rising_edge(clk) then 

            -- reset condition
            if rst = '1' then
                input_x_0 <= (others => '0');
                input_x_1 <= (others => '0');
                input_x_2 <= (others => '0');
                input_x_3 <= (others => '0');
                input_x_4 <= (others => '0');
                input_x_5 <= (others => '0');
                input_x_6 <= (others => '0');
                input_x_7 <= (others => '0');

            -- if enable is ON then shift input_x_ in the queue 1 step    
            elsif shift_enable = '1' then
                --if we dont want to corrupt the data shift has to get
                --disabled once all 8 data has been pushed in.
                input_x_0 <= external_input;
                input_x_1 <= input_x_0;
                input_x_2 <= input_x_1;
                input_x_3 <= input_x_2;
                input_x_4 <= input_x_3;
                input_x_5 <= input_x_4;
                input_x_6 <= input_x_5;
                input_x_7 <= input_x_6;
            
            -- when enable is OFF keep input_x_ the same
            else 
                input_x_0 <= input_x_0;
                input_x_1 <= input_x_1;
                input_x_2 <= input_x_2;
                input_x_3 <= input_x_3;
                input_x_4 <= input_x_4;
                input_x_5 <= input_x_5;
                input_x_6 <= input_x_6;
                input_x_7 <= input_x_7;
            end if;
        end if;
        
    end process; 
--------------------------------------------------------------------------¨
    -- combinational output which based on an address or index gets you
    -- one data register
    shifter_output : process  (input_x_0, input_x_1, input_x_2, input_x_3, input_x_4,input_x_5, input_x_6, input_x_7, get_input_en, x_col_i) 
    begin 
        shifter_output_i <= "00000000";
        
        -- this data is in reverse order of index its because the
        -- first input is now in the last register
        if get_input_en ='1' then
            case x_col_i is
                when "000" => shifter_output_i <= input_x_7;
                when "001" => shifter_output_i <= input_x_6;
                when "010" => shifter_output_i <= input_x_5;
                when "011" => shifter_output_i <= input_x_4;
                when "100" => shifter_output_i <= input_x_3;
                when "101" => shifter_output_i <= input_x_2;
                when "110" => shifter_output_i <= input_x_1;
                when "111" => shifter_output_i <= input_x_0;
                when others => shifter_output_i <= (others => '0');
            end case;    
        end if;  
    end process; 
end behavioral; 