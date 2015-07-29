library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity random is
port(CLK:  in std_logic;
     D_IN: in std_logic;
     Q_OUT:out std_logic_vector(2 downto 0));
end random;

architecture behave of random is
signal Q1,Q2,Q3,Q4:std_logic;
begin
Q_OUT<=((Q1 XOR Q3)XOR(Q2 XOR Q4)) & Q1 & Q4;

process(CLK)
begin
if rising_edge(CLK)then
  Q1<=D_IN;
  Q2<=Q1;
  Q3<=Q2;
  Q4<=Q3;
end if;
end process;

end behave;