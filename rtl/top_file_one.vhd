library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_file_one is
     
   Port (   
            -- these need to go to controller
            -- controller gives back 6 outputs: all go to ram controller for write OP
            clk         : in std_logic;
            rst         : in std_logic;
            valid_input : in std_logic;
            -- this input acts as both input to controller for writing data and
            -- as address input to ram for reading data
            external_input_data : in std_logic_vector(7 downto 0);

            -- these go into RAM for read OP
            read_command: in std_logic; 
            ready       : out std_logic;
            top_file_output : out std_logic_vector(4 downto 0)
         );
end top_file_one;

architecture Behavioral of top_file_one is

-- SIGNAL DEFINITIONS

    signal results_p1,results_p2    : std_logic_vector(14 downto 0);
    signal results_p3,results_p4    : std_logic_vector(14 downto 0);
    signal ctrl_idle_internal         : std_logic;
    signal load                     : std_logic;
    signal finished_reading         : std_logic;
    signal read_command_to_ram      : std_logic;
-- COMPONENT DEFINITION

    component controller_with_shift is 
    port (     
            -- multiply operation inputs -----------
            clk           : in std_logic;
            rst           : in std_logic;
            external_input_x: in std_logic_vector(7 downto 0);
            valid_input   : in std_logic;

            -- read operation inputs ---------------
            finished_reading : in std_logic;
            read_command  : in std_logic;

            -- multiply operation outputs-----------
            ctrl_idle_ready_to_read  : out std_logic;
            load          : out std_logic;   
            results_p1    : out std_logic_vector(14 downto 0);
            results_p2    : out std_logic_vector(14 downto 0);
            results_p3    : out std_logic_vector(14 downto 0);
            results_p4    : out std_logic_vector(14 downto 0)
         );
    end component;

    component ram_controller is 
    port ( 
            clk           : in std_logic;
            rst           : in std_logic;
            
            ----- reading from --------------
            read_command              : in std_logic; -- start the read process    
            finished_reading          : out std_logic; -- Read finished, RAM is free
            is_ctrl_idle   : in std_logic; -- flag to read            
            external_read_address     : in std_logic_vector(7 downto 0); -- assume its write_address to read         
            output_port               : out std_logic_vector(4 downto 0); -- read output: 15 bit, given 5 bits at a time

            ----- writing to RAM ------------
            load_command    : in std_logic; -- activates the write operation   
            external_data_1 : in std_logic_vector(14 downto 0); -- data to write
            external_data_2 : in std_logic_vector(14 downto 0);
            external_data_3 : in std_logic_vector(14 downto 0);
            external_data_4 : in std_logic_vector(14 downto 0)
         );
    end component;
    
begin
    -- the ready signals from either controller is mapped to the output ready signal here 
     ready <= ctrl_idle_internal;
    read_command_to_ram <= read_command;

    Controller_1 : controller_with_shift
        port map(  
            
            clk               => clk, 
            rst               => rst,    
            external_input_x  => external_input_data,
            valid_input       => valid_input,  
            
            ----------------------------------------
            read_command =>   read_command_to_ram,
            finished_reading => finished_reading,
            ----------------------------------------
            ctrl_idle_ready_to_read => ctrl_idle_internal, 
            
            load              => load,         
            results_p1        => results_p1, 
            results_p2        => results_p2,
            results_p3        => results_p3,  
            results_p4        => results_p4 
         );

    RAM_controller_1 : ram_controller 
    port map(  
            clk                       => clk,        
            rst                       => rst,          
             
            ----- reading from --------------
            read_command              => read_command_to_ram,        
            finished_reading          => finished_reading,
            is_ctrl_idle              => ctrl_idle_internal,
            external_read_address     => external_input_data,      
            output_port               => top_file_output,         

            ----- writing to RAM ------------
            load_command              => load,
            external_data_1           => results_p1,
            external_data_2           => results_p2,
            external_data_3           => results_p3,
            external_data_4           => results_p4
         );

end Behavioral;
