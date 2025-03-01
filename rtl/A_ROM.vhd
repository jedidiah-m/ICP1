library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity A_ROM is 
    port (  
            clk            : in std_logic;
            -- no reset needed as these are hard coded and cannot be reset

            -- address to retrieve ROM coefficients
            rom_address    : in std_logic_vector(3 downto 0);

            -- counts from 0 to 15, half of each number is a coefficient
            ROM_out_A_coef: out std_logic_vector(13 downto 0)
                      
         );
end A_ROM;

architecture behavioral of A_ROM is
    signal current_rom_out,next_rom_out : std_logic_vector(13 downto 0);

begin
    -- ROM output, gives a single coefficient
    ROM_out_A_coef  <= current_rom_out;
    
    process(clk)
    begin
        if rising_edge(clk) then
            current_rom_out <= next_rom_out;
        end if;
    end process;

    read_rom: process(rom_address,clk)
	   
        begin
        case rom_address is
            when "0000" => next_rom_out <= "00000110010110"; -- 3 22  406
            when "0001" => next_rom_out <= "00010110000001"; -- 11 1  1409
            when "0010" => next_rom_out <= "00010000000011"; -- 8 3   1027
            when "0011" => next_rom_out <= "00000010000010"; -- 1 2   130
            when "0100" => next_rom_out <= "00010000001111"; -- 8 15  1039
            when "0101" => next_rom_out <= "00000100000100"; -- 2 4   260
            when "0110" => next_rom_out <= "00011000000110"; -- 12 6  1572
            when "0111" => next_rom_out <= "00000010000010"; -- 1 2   130
            when "1000" => next_rom_out <= "00100100101000"; -- 18 40 2344
            when "1001" => next_rom_out <= "00000110000010"; -- 3 2   386
            when "1010" => next_rom_out <= "00100000001001"; -- 16 9  2057
            when "1011" => next_rom_out <= "00000010000010"; -- 1 2   130
            when "1100" => next_rom_out <= "00000010001010"; -- 1 10  138
            when "1101" => next_rom_out <= "00001000000000"; -- 4 0   512
            when "1110" => next_rom_out <= "00000100001100"; -- 2 12  268
            when "1111" => next_rom_out <= "00000010000010"; -- 1 2   130
            when others => next_rom_out <= (others => '0');
            end case;
        end process;

end behavioral;