library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity alien is
port(MOVE_CLK:     in std_logic;
     MISSILE_POS_H:in std_logic_vector(10 downto 0);
     MISSILE_POS_V:in std_logic_vector(10 downto 0);
     HCount:       in std_logic_vector(10 downto 0);
     VCount:       in std_logic_vector(10 downto 0);
     INIT_POS_H:   in std_logic_vector(10 downto 0);--decide where an alien appear after be resetted
     ALIEN_HIT:    out std_logic;--if alien was hit, send 1 to missile
     VGA_ALIEN_EN: out std_logic;--whether show on screen
     ALIEN_WON:    out std_logic:='0');--if a alien touch the bottom, game over
end alien;

architecture behave of alien is
signal MOV_DIR        :std_logic;--0 to right,1 to left
signal POS_H          :std_logic_vector(10 downto 0):=INIT_POS_H;--such as "00000001010";
signal POS_V          :std_logic_vector(10 downto 0):="00011001000";
signal ALIEN_EN       :std_logic;
signal ALIEN_CLK_COUNT:std_logic_vector(2 downto 0);

constant ALIEN_HEIGHT  :integer:= 32;
constant ALIEN_WIDTH   :integer:= 32;
constant MISSILE_HEIGHT:integer:= 16;
constant MISSILE_WIDTH :integer:= 4;
begin

HIT_OR_WIN:process(MOVE_CLK)--check if alien hit by missile
begin
if rising_edge(MOVE_CLK)then
  ALIEN_EN<='1';
  ALIEN_WON<='0';
  ALIEN_HIT<='0';
  if((MISSILE_POS_H+MISSILE_WIDTH)>POS_H and
     MISSILE_POS_H<(POS_H+ALIEN_WIDTH) and
     (MISSILE_POS_V+MISSILE_HEIGHT)>POS_V and
     MISSILE_POS_V<(POS_V+ALIEN_HEIGHT))then--if missile hit the alien
     ALIEN_EN<='0';
     ALIEN_HIT<='1';
  elsif(POS_V>480)then
     ALIEN_EN<='0';
     ALIEN_WON<='1';
  end if;
end if;
end process HIT_OR_WIN;

MOVEMENT_AND_RST:process(MOVE_CLK)--calculate the movement of alien
begin
if rising_edge(MOVE_CLK)then
  if(ALIEN_EN='0')then
    POS_H<=INIT_POS_H;--such as"00000001010";--=10;
    POS_V<="00011001000";--=200;
  elsif(ALIEN_EN='1')then
    if(ALIEN_CLK_COUNT/="111")then
      ALIEN_CLK_COUNT<=ALIEN_CLK_COUNT+1;
    else
      ALIEN_CLK_COUNT<="000";
	  if(MOV_DIR='0')then--move to right
	    if(POS_H<800-96)then
	      POS_H<=POS_H+16;
	    else
	      MOV_DIR<='1';
	    end if;
	  else
	    if(POS_H>32)then
	      POS_H<=POS_H-16;
	    else
	      MOV_DIR<='0';
	    end if;
	  end if;
	  POS_V<=POS_V+1;
    end if;
  end if;
end if;
end process MOVEMENT_AND_RST;

ALIEN_SHOW:process(HCount,VCount)
begin
vga_alien_en<='0';
if(ALIEN_EN='1')then
	if(VCount>POS_V+3 and VCount<POS_V+6)then
	  if((HCount>POS_H+5 and Hcount<POS_H+8)or(HCount>POS_H+22 and Hcount<POS_H+25))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount>POS_V+6 and VCount<POS_V+10)then
	  if((HCount>POS_H+8 and Hcount<POS_H+11)or(HCount>POS_H+19 and Hcount<POS_H+22))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount>POS_V+9 and VCount<POS_V+12)then
	  if((HCount>POS_H+5 and Hcount<POS_H+25))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount=POS_V+12)then
	  if((HCount>POS_H+5 and Hcount<POS_H+8)or(HCount>POS_H+11 and Hcount<POS_H+19)or
	     (HCount>POS_H+22 and Hcount<POS_H+25))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount=POS_V+13)then
	  if((HCount>POS_H+2 and Hcount<POS_H+8)or(HCount>POS_H+11 and Hcount<POS_H+19)or
	     (HCount>POS_H+22 and Hcount<POS_H+28))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount>POS_V+13 and VCount<POS_V+16)then
	  if((HCount>POS_H+3 and Hcount<POS_H+8)or(HCount>POS_H+11 and Hcount<POS_H+19)or
	     (HCount>POS_H+22 and Hcount<POS_H+28))then
	      vga_alien_en<='1';
	  end if;
	elsif(VCount>POS_V+15 and VCount<POS_V+18)then
	  if((HCount>POS_H+0 and Hcount<POS_H+30))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount>POS_V+17 and VCount<POS_V+21)then
	  if((HCount>POS_H+0 and Hcount<POS_H+2)or(HCount>POS_H+5 and Hcount<POS_H+25)or
	     (HCount>POS_H+28 and Hcount<POS_H+30))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount>POS_V+20 and VCount<POS_V+24)then
	  if((HCount>POS_H+0 and Hcount<POS_H+2)or(HCount>POS_H+5 and Hcount<POS_H+8)or
	     (HCount>POS_H+22 and Hcount<POS_H+25)or(HCount>POS_H+28 and Hcount<POS_H+30))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount=POS_V+25)then
	  if((HCount>POS_H+8 and Hcount<POS_H+13)or(HCount>POS_H+17 and Hcount<POS_H+22))then
	    vga_alien_en<='1';
	  end if;
	elsif(VCount=POS_V+26)then
	  if((HCount>POS_H+8 and Hcount<POS_H+14)or(HCount>POS_H+17 and Hcount<POS_H+22))then
	    vga_alien_en<='1';
	  end if;
	end if;
end if;
end process ALIEN_SHOW;

end behave;
