library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity player is
port(MOVE_CLK:in std_logic;
     HCount         :in std_logic_vector(10 downto 0);
     VCount         :in std_logic_vector(10 downto 0);
     PLAYER_BUTTON_A:in std_logic;
     PLAYER_BUTTON_B:in std_logic;
     PLAYER_H       :out std_logic_vector(10 downto 0);--send to missile
     VGA_PLAYER_EN  :out std_logic);--whether show on screen
end player;

architecture behave of player is
signal POS_H        :std_logic_vector(10 downto 0):="00110010000";--to make it at the middlie of screen
signal MOV_DIR      :std_logic_vector(1 downto 0):="00";
signal MOV_DIR_COUNT:std_logic_vector(2 downto 0):="000";
begin
PLAYER_H<=POS_H;
MOV_DIR<=PLAYER_BUTTON_A&PLAYER_BUTTON_B;
-------------------------------------------------------------------
process(MOVE_CLK)
begin
if(MOV_DIR_COUNT/="111")then
  MOV_DIR_COUNT<=MOV_DIR_COUNT+1;
else
  MOV_DIR_COUNT<="010";
  if(MOV_DIR="01")then
    if(POS_H>33)then
      POS_H<=POS_H-16;
    end if;
  elsif(MOV_DIR="10")then
    if(POS_H<730)then
      POS_H<=POS_H+16;
    end if;
  end if;
end if;
end process;
---------------------------------------------------------
PLAYER_SHOW:process(HCount,VCount)
begin
vga_player_en<='0';
if(VCount>549 and VCount<559)then
  if(HCount>(POS_H+8-1) and Hcount<(POS_H+16+1))then
    vga_player_en<='1';
  end if;
elsif(VCount>558 and VCount<563)then
  if(HCount>(POS_H-1) and HCount<(POS_H+24+1))then
    vga_player_en<='1';
  end if;
end if;
end process PLAYER_SHOW;

end behave;