library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity missile is
port(MOVE_CLK      :in std_logic;
     HCount        :in std_logic_vector(10 downto 0);
     VCount        :in std_logic_vector(10 downto 0);
     MISSILE_BUTTON:in std_logic;
     ALIEN_HIT     :in std_logic_vector(2 downto 0);
     PLAYER_POS_H  :in std_logic_vector(10 downto 0);--get from player
     MISSILE_OUT   :out std_logic;--send to alien
     MISSILE_POS_H :out std_logic_vector(10 downto 0);--send to alien
     MISSILE_POS_V :out std_logic_vector(10 downto 0);--send to alien
     VGA_MISSILE_EN:out std_logic);--whether show on screen
end missile;

architecture behave of missile is
signal MPOS_H    :std_logic_vector(10 downto 0):="00000000000";
signal MPOS_V    :std_logic_vector(10 downto 0):="01000100101";
signal missile_en:std_logic:='0';
signal OUT_POS_V :std_logic_vector(10 downto 0);
constant MISSILE_HEIGHT:integer:= 16;
constant MISSILE_WIDTH :integer:= 4;
begin
MISSILE_OUT<=missile_en;
MISSILE_POS_H<=MPOS_H;
MISSILE_POS_V<=MPOS_V;
-------------------------------------------------
MOVEMENT:process(MOVE_CLK)--calculate the movement of alien
begin
if (rising_edge(MOVE_CLK))then--the movement of missile and process of out of range
  if(missile_en='1')then
    if(VCount<MPOS_V or VCount>(MPOS_V+MISSILE_HEIGHT))then
    --make sure the missile will not change it position while scan its area
      if(MPOS_V>200)then
        MPOS_V<=MPOS_V-8;
        MPOS_H<=OUT_POS_V+10;
      end if;
    end if;
  elsif(missile_en='0')then
    MPOS_V<="01000100101";
  end if;
end if;
end process MOVEMENT;

RESET:process(MPOS_V,MISSILE_BUTTON,ALIEN_HIT)
begin
if(missile_en='1')then
  if(MPOS_V<200)then
    missile_en<='0';
  elsif(ALIEN_HIT(0)='1' or ALIEN_HIT(1)='1' or ALIEN_HIT(2)='1')then--if any alien has been hit
    missile_en<='0';
  end if;
elsif missile_en='0' then
  if(MISSILE_BUTTON='0')then--if the button of missile be pressed
    OUT_POS_V<=PLAYER_POS_H;
    missile_en<='1';
  end if;
end if;
end process RESET;
------------------------------------------------
MISSILE_SHOW:process(HCount,VCount)
begin
vga_missile_en<='0';
if(MISSILE_EN='1')then
  if(VCount>(MPOS_V-1) and VCount<(MPOS_V+MISSILE_HEIGHT+1))then
    if(HCount>(MPOS_H-1) and HCount<(MPOS_H+MISSILE_WIDTH+1))then
      vga_missile_en<='1';
    end if;
  end if;
end if;
end process MISSILE_SHOW;

end behave;