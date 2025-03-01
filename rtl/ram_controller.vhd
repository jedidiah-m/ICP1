library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

entity ram_controller is
 port(   
            clk           : in std_logic;
            rst           : in std_logic;
            
            ----- reading from --------------
            read_command                : in std_logic; -- start the read process   
            finished_reading            : out std_logic; -- Read finished, RAM is free
            
            --controller_is_ready_for_read
            is_ctrl_idle                : in std_logic; -- flag to read          
            external_read_address       : in std_logic_vector(7 downto 0); 
            -- wait_read_address that comes straight from top file   

            output_port                 : out std_logic_vector(4 downto 0); -- read output: 15 bit, given 5 bits at a time

            ----- writing to RAM ------------ 
            load_command    : in std_logic; -- activates the write operation   
            external_data_1 : in std_logic_vector(14 downto 0); -- data to write
            external_data_2 : in std_logic_vector(14 downto 0);
            external_data_3 : in std_logic_vector(14 downto 0);
            external_data_4 : in std_logic_vector(14 downto 0)
        );
end ram_controller;

architecture Behavioral of ram_controller is
-- signals-------------------------
      type state_type is (start_state, write_state_2, write_state_3, write_state_4, wait_state, read_state);
      signal current_state: state_type;
      signal next_state   : state_type;
 
      signal LOW          : std_logic:='0'; 
      signal HIGH         : std_logic:='1'; 
      signal write_enable : std_logic;
      signal RY           : std_logic;   -- dont know what it is, READ enable?
      signal is_output_valid :std_logic; -- added to see valid portion of output in tb

      -- address_to_wrapper is used for both read and write operations
      -- it has three options:
                --during write it is: write_address
                --during read it is : externa_input from top file if in read state
                                  --: or wait_read_add if in wait state
      signal address_to_wrapper                 : std_logic_vector(7 downto 0);
      signal write_address, next_write_address  : std_logic_vector(7 downto 0);
      signal wait_read_address, next_wait_read_address: std_logic_vector(7 downto 0);
      signal wait_flag, next_wait_flag                : std_logic:='0';

      -- data in and out of wrapper
        -- In: during write it is the P elements of result matrix, during read it should be 0
        -- OUT: during write 0, during read it should be P element we want to read
      signal wrapper_input_data, ram_wrapper_output : std_logic_vector(31 downto 0);

      -- counter and register to break up read_output
      signal five_bit_counter, next_five_bit_counter : std_logic_vector(1 downto 0); 
      signal wrapper_out_10_bits, next_wrapper_out_10_bits: std_logic_vector(9 downto 0);

      -- the first P element is fed to wrapper directly the other 3 are latched to 
      -- add in succeeding clock cycles
      signal p_2_temp_register, p_2_next          : std_logic_vector(14 downto 0);
      signal p_3_temp_register, p_3_next          : std_logic_vector(14 downto 0);
      signal p_4_temp_register, p_4_next          : std_logic_vector(14 downto 0);

    -- components------------------------------
    -- i Have made a fake wrapper for test bench
    -- this part is the same but it points to fake wrapper in the project
    -- so replace it in the project with real wrapper and real ram components
    component SRAM_SP_WRAPPER is
      port (
        ClkxCI  : in  std_logic;                                -- Clk
        CSxSI   : in  std_logic;  -- put as always LOW, test  -- Active LOW  -- chip enable
        WExSI   : in  std_logic;                                --             -- Write_enable 
        AddrxDI : in  std_logic_vector (7 downto 0);            --write_address
        RYxSO   : out std_logic;                                           -- read enable I assume
        DataxDI : in  std_logic_vector (31 downto 0);           --Data in
        DataxDO : out std_logic_vector (31 downto 0)            --Data out
        );
    end component;
begin
----------------------------------
    HIGH <= '1';
    LOW  <= '0'; -- to enable different signals 
    ------------------------------
    -- RAM controller
    state_logic : process(current_state, write_address, five_bit_counter, p_2_temp_register, p_3_temp_register, p_4_temp_register, is_ctrl_idle, read_command, ram_wrapper_output, load_command, wrapper_out_10_bits, external_read_address, external_data_1,  next_wait_read_address,wait_read_address, wait_flag)

    begin 
        -- dafault r <-- r operations
        address_to_wrapper          <= write_address;

        -- reset write_address at the end otherwise keep it the same by default
        if(write_address="10100000") then -- 160
            next_write_address      <= (others => '0');
        else 
            next_write_address      <= write_address;
        end if;

        next_state                  <= current_state;
        next_five_bit_counter       <= five_bit_counter;
        next_wrapper_out_10_bits    <= wrapper_out_10_bits;
        next_wait_read_address      <= wait_read_address;

        -- default values 
        write_enable                <= HIGH; -- write disabled: active low 
        finished_reading            <= '0';
        wrapper_input_data          <= (others => '0'); 
        ------------------------------------------
        output_port <= (others => '0');
        is_output_valid <= '0';
        ----------------------------------------------------------------------
        case current_state is

            -- here we choose if we want to write or read
            when start_state =>
                ----------------------
                if(load_command='1') then 
                    -- if load_command =1:
                                -- next state: save 2 
                                -- in the next clock cycle we do the following:
                                    -- increment write_address
                                    -- enable write
                                    -- pad P element with 0s and push it into wrapper_input 
                    
                    next_state <= write_state_2;
                    next_write_address <= write_address + 1;
                    write_enable <= '0';
                    wrapper_input_data <= "00000000000000000" & external_data_1; -- there is no P1_reg
              
                elsif read_command='1' then
                        if is_ctrl_idle='1' then -- read state directly
                            address_to_wrapper <= external_read_address;
                            next_wait_read_address <= external_read_address; -- we use this
                                                                    -- address once and next times
                                                                    -- we use the latched address
                            next_state <= read_state;
                            next_five_bit_counter <="00";
                            next_wait_flag <= '0';
                        else    -- wait state then read state
                                -- we give address to wrapper later when system is idle
                            next_wait_read_address <= external_read_address;
                            next_state <= wait_state;
                            next_five_bit_counter <="00";
                        end if; 
                end if;
                ----------------------
            --------------------------------------------------------
            when write_state_2 =>
                -- in this state we have one exit: save_3
                -- increment internal_ram address
                -- we enable write

                -- finally push P2 temp_register into wrapper
                next_state          <= write_state_3;
                next_write_address    <= write_address + 1;
                write_enable        <= LOW;

                wrapper_input_data <= "00000000000000000" & p_2_temp_register; -- 17 0s 0 15 bit P reg = 32 bits
            --------------------------------------------------------
            when write_state_3 =>
                next_state          <= write_state_4;
                next_write_address    <= write_address + 1;
                write_enable        <= LOW;

                wrapper_input_data <= "00000000000000000" & p_3_temp_register;
            --------------------------------------------------------
            when write_state_4 =>
                next_state          <= start_state;
                next_write_address    <= write_address + 1;
                write_enable        <= LOW;
                wrapper_input_data   <= "00000000000000000" & p_4_temp_register;
            --------------------------------------------------------
            -- state that keeps read address saved in case main controller is not idle yet
            when wait_state =>
                if is_ctrl_idle='1' then 

                    next_state <= read_state;
                    address_to_wrapper <= wait_read_address;
                    next_wait_flag <='1';
                else 
                    next_state <= wait_state;
                end if;
            --------------------------------------------------------
            -- break up the output in 3 five_bit parts and send to output port
            when read_state => 
                -- this flag is used to determined if we are coming form start state or wait state
                if next_wait_flag = '1' then -- from wait state we land here

                    next_wait_flag <='0'; -- reset so next clock cycle we skip this part
                    next_five_bit_counter <= five_bit_counter +1;
                    address_to_wrapper <= wait_read_address; 
                    --output: send 5 bits to port and latch the next 10 bits
                    output_port <= ram_wrapper_output(14 downto 10);
                    next_wrapper_out_10_bits <= ram_wrapper_output (9 downto 0);
                    is_output_valid <= '1';

                    next_state <= read_state;
                else
                        
                    if (five_bit_counter ="00") then -- from start state we land here        
                        -------------------- 
                        next_five_bit_counter <= five_bit_counter +1;
                        is_output_valid <= '1';
                        output_port <= ram_wrapper_output(14 downto 10);
                        address_to_wrapper <= wait_read_address;
                        next_wrapper_out_10_bits <= ram_wrapper_output (9 downto 0);
                        next_state <= read_state;
                        --------------------
                    elsif(five_bit_counter = "01") then -- if five_bit_counter = 1
                        --------------------
                        next_five_bit_counter <= five_bit_counter +1;
                        address_to_wrapper <= wait_read_address;
                        
                        output_port <= wrapper_out_10_bits(9 downto 5);
                        is_output_valid <= '1';

                        next_state <= read_state;
                        --------------------
                    else  
                        --------------------
                        next_five_bit_counter <= "00"; -- reset 5 bit counter
                        address_to_wrapper <= wait_read_address;

                        output_port <= wrapper_out_10_bits(4 downto 0); -- take last 5 bits
                        is_output_valid <= '1';
                        
                        finished_reading <= '1';
                        next_state <= start_state;
                        --------------------
                    end if;
                end if; 
        end case;
    end process;

---instantiations-------------------------------

-- RAM wrapper -----------
  RAM_component : SRAM_SP_WRAPPER 
  port map(
    ClkxCI  => clk,
    CSxSI   => LOW,
    WExSI   => write_enable,
    AddrxDI => address_to_wrapper,
    RYxSO   => RY,
    DataxDI => wrapper_input_data,
    DataxDO => ram_wrapper_output
    );

--- next_value logic for temp_registers ----------------------
  reg_logic : process(load_command, external_data_2, external_data_3, external_data_4, p_2_temp_register, p_3_temp_register, p_4_temp_register)
  begin
      -- temp_register next logic
      -- Path 1: load_command <='1': connect to external inpt
      -- path 2: load_command <='0': r <-- r opertaion

          p_2_next <= p_2_temp_register;
          p_3_next <= p_3_temp_register;
          p_4_next <= p_4_temp_register;

      if(load_command='1') then
          p_2_next <= external_data_2;
          p_3_next <= external_data_3;
          p_4_next <= external_data_4;
      end if;
  end process;

---internal temp_registers with sync reset------------
  reg : process  (clk,rst ) 
  begin 
      if rising_edge(clk) then 
          if rst = '1' then
            -- read operation
            five_bit_counter      <= (others => '0');
            wait_flag             <= '0';
            wrapper_out_10_bits   <= (others => '0');
            wait_read_address     <= (others => '0');
            
            --write operation
            write_address         <= (others => '0');
            p_2_temp_register     <= (others => '0');
            p_3_temp_register     <= (others => '0');
            p_4_temp_register     <= (others => '0');

          else 
            -- read operation
            five_bit_counter      <= next_five_bit_counter;
            wait_flag             <= next_wait_flag;
            wrapper_out_10_bits   <= next_wrapper_out_10_bits; 
            wait_read_address     <= next_wait_read_address;
            
            --write operation
            write_address         <= next_write_address;
            p_2_temp_register     <= p_2_next;
            p_3_temp_register     <= p_3_next;
            p_4_temp_register     <= p_4_next;

          end if;
      end if;
  end process;  
  
  -- FSM temp_register-------------------------------
  state_reg : process  ( clk, rst, next_state ) 
  begin 
      if rst = '1' then
          current_state <= start_state;
      elsif rising_edge(clk) then 
          current_state <= next_state;
      end if;
  end process;
-------------------------------------------------
end Behavioral;
