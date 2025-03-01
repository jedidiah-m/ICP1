library ieee;
use ieee.std_logic_1164.all;
use STD.textio.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all; 
--------------------------------
entity tb_with_ram is
end tb_with_ram;
--------------------------------
architecture Behavioral of tb_with_ram is
----------------------------------------------
     signal clk  : std_logic  := '0';
     signal rst  : std_logic  := '0';
     signal external_input_x  : std_logic_vector(7 downto 0);
     --signal valid_input       :  std_logic:= '1'; -- for write operation
     signal valid_input       :  std_logic:= '0';
     signal ready             : std_logic:= '0';
     signal load              : std_logic:= '0';
     signal results_p1, results_p2, results_p3, results_p4 : std_logic_vector(14 downto 0);
 
     -- read op signals
     signal read_command     : std_logic:= '0';
     signal top_file_output           : std_logic_vector(4 downto 0);
    -- read file signals
     constant period : time := 100 ns;
     file input_file : text;

-------------------------------------------
begin
  -------------------------------------------

    clk <= not(clk) after period*0.5;
    rst <= '1', '0' after 2*period;
    
  -- Instantiate the design under test
  dut: entity work.top_file_one(behavioral)
    port map (
          -- write operation
          clk               => clk,
          rst	              => rst,
          valid_input       => valid_input,
          external_input_data => external_input_x,

          -- read operation
          read_command      => read_command,
          ready             => ready,
          top_file_output   => top_file_output
          );
  --- uncomment this part for write operation
  ------ stimuli for write operation  ----------------------
        write_input : process
          variable v_ILINE     : line;
          variable v_SPACE     : character;
          variable variable_input : std_logic_vector(7 downto 0);
          variable count       : integer:=0;
        
          begin  
              wait until rst = '0' and ready = '1';
              valid_input <= '1', '0' after 2*period;
              read_command <= '0';

              if count <= 160 then 
                  file_open(input_file, "C:\Users\Jedid\Documents\input_stimuli.txt",  read_mode);
                  while not endfile(input_file) loop
                      count := count +1;
                      readline(input_file,v_ILINE);
                      read(V_ILINE,variable_input);
                      external_input_x <= variable_input;
                      wait for period;
                      --------------------------
                      if((count mod 32)= 0 and count/32 /=5 ) then 
                              wait until ready = '1';
                              valid_input <= '1';
                              count := count +1;
                              readline(input_file,v_ILINE);
                              read(V_ILINE,variable_input);
                              external_input_x <= variable_input;
                              wait for period; 
                              valid_input <= '0';
                      end if; 
                      ---------------------------
                  end loop;
                  file_close(input_file);
              else
                valid_input <= '0';
                external_input_x <= "10001100"; -- 140
                                                -- left half: 8 
                                                -- right half: 12
                read_command <='1', '0' after period;
                
              end if;       
        end process;
    
    
---------stimuli for read operation  -------------------------
--read_proc: process
--  begin  
--      --- setup
--      wait until rst = '0' and ready = '1';
--      valid_input <= '0' after 2*period;
--      wait for period;
--      read_command <= '1';
--      --read_command <='1', '0' after period;

--      ----stimuli
--      external_input_x <= "00000000"; -- 0
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000001"; -- 1
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000010"; -- 2
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000011"; -- 3
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000100"; -- 4
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000101"; -- 5
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000110"; -- 6
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00000111"; -- 7
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00001000"; -- 8
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00001001"; -- 9
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00001010"; -- 10
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00001011"; -- 11
--      wait for period;
--      wait until ready = '1';
      
--      valid_input <= '1';
      
--      external_input_x <= "00001100"; -- 12
--      wait for period;
--      wait until ready = '1';
      
--      valid_input <= '0';
      
--      external_input_x <= "00001101"; -- 13
--      wait for period;
--      wait until ready = '1';  
      
--      external_input_x <= "00001110"; -- 14
--      wait for period;
--      wait until ready = '1';
      
--      external_input_x <= "00001111"; -- 15
--      wait for period;
--      wait until ready = '1';
      
--      --------- 
--    end process;
    -- test inputs (middle number) for read and expected values at the output (left: binary 5 bit output. Right: decimal 5 bit output)			
--00000	01100	10110	406	    0	12	22
--00001	01100	00001	1406	1	12	1
--00001	00000	00011	1027	1	0	3
--00000	00100	00010	130	    0	4	2
--00001	00000	01111	1039	0	1	15
--00000	01000	00100	260	    0	8	4
--00001	10000	00110	1572	1	16	6
--00000	00100	00010	130	    0	4	2
--00010	01001	01000	2344	2	9	8
--00000	01100	00010	386	    0	12	2
--00010	00000	01001	2057	2	0	9
--00000	00100	00010	130	    0	4	2
--wait	wait	wait	wait	wait	wait	wait
--00000	00100	01010	138	    0	4	10
--00000	10000	00000	512	    0	16	0
--00000	01000	01100	268	    0	8	12
--00000	00100	00010	130	    0	4	2

end Behavioral;
----------------------------------