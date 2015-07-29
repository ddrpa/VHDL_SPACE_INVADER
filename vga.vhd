library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity vga is
port(RST:     in std_logic;--KEY0
     CLK:     in std_logic;
     BUTTON_A:in std_logic;--KEY3--move left
     BUTTON_B:in std_logic;--KEY2--missile out
     BUTTON_C:in std_logic;--KEY1--move right
     VGA_CLK: out std_logic;
     RV:      out std_logic_vector(9 downto 0);
     GV:      out std_logic_vector(9 downto 0);
     BV:      out std_logic_vector(9 downto 0);
     VS:      out std_logic;--Vertical Sync
     HS:      out std_logic;--Horizontal Sync
     BLANK:   out std_logic;
     SYNC:    out std_logic);
end vga;
---------------------------------------------------------------------
architecture behave of vga is
component random
port(CLK:  in std_logic;
     D_IN: in std_logic;
     Q_OUT:out std_logic_vector(2 downto 0));
end component;

component alien
port(MOVE_CLK:     in std_logic;
     MISSILE_POS_H:in std_logic_vector(10 downto 0);
     MISSILE_POS_V:in std_logic_vector(10 downto 0);
     HCount:       in std_logic_vector(10 downto 0);
     VCount:       in std_logic_vector(10 downto 0);
     INIT_POS_H:   in std_logic_vector(10 downto 0);--decide where an alien appear after be resetted
     ALIEN_HIT:    out std_logic;--if alien was hit, send 1 to missile
     VGA_ALIEN_EN: out std_logic;--whether show on screen
     ALIEN_WON:    out std_logic:='0');--if a alien touch the bottom, game over
end component;

component player
port(MOVE_CLK:in std_logic;
     HCount:         in std_logic_vector(10 downto 0);
     VCount:         in std_logic_vector(10 downto 0);
     PLAYER_BUTTON_A:in std_logic;
     PLAYER_BUTTON_B:in std_logic;
     PLAYER_H:       out std_logic_vector(10 downto 0);--send to missile
     VGA_PLAYER_EN:  out std_logic);--whether show on screen
end component;

component missile
port(MOVE_CLK:      in std_logic;
     HCount:        in std_logic_vector(10 downto 0);
     VCount:        in std_logic_vector(10 downto 0);
     MISSILE_BUTTON:in std_logic;
     ALIEN_HIT:     in std_logic_vector(2 downto 0);
     PLAYER_POS_H:  in std_logic_vector(10 downto 0);--get from player
     MISSILE_OUT:   out std_logic;--send to alien
     MISSILE_POS_H: out std_logic_vector(10 downto 0);--send to alien
     MISSILE_POS_V: out std_logic_vector(10 downto 0);--send to alien
     VGA_MISSILE_EN:out std_logic);--whether show on screen
end component;
------------------------------800X600,72Hz,50MHz-------------------------------
constant H_PIXELS    :integer:=800;
constant H_FRONTPORCH:integer:=56;
constant H_SYNCTIME  :integer:=120;
constant H_BACKPROCH :integer:=64;
constant H_SYNCSTART :integer:=H_PIXELS+H_FRONTPORCH;
constant H_SYNCEND   :integer:=H_SYNCSTART+H_SYNCTIME;
constant H_PERIOD    :integer:=H_SYNCEND+H_BACKPROCH;
constant V_LINES     :integer:=600;
constant V_FRONTPORCH:integer:=37;
constant V_SYNCTIME  :integer:=6;
constant V_BACKPROCH :integer:=23;
constant V_SYNCSTART :integer:=V_LINES+V_FRONTPORCH;
constant V_SYNCEND   :integer:=V_SYNCSTART+V_SYNCTIME;
constant V_PERIOD    :integer:=V_SYNCEND+V_BACKPROCH;
signal HSync  :std_logic;
signal VSync  :std_logic;
signal HCount :std_logic_vector(10 downto 0);
signal VCount :std_logic_vector(10 downto 0);
signal HEnable:std_logic;
signal VEnable:std_logic;
signal ColorR :std_logic_vector(9 downto 0);
signal ColorG :std_logic_vector(9 downto 0);
signal ColorB :std_logic_vector(9 downto 0);
---------------------------------------------------------------------
--player
signal player_pos_h      :std_logic_vector(10 downto 0);
signal vga_player_en     :std_logic;
signal PLAYER_LIFE       :std_logic_vector(10 downto 0):="01100011111";--=>hp=799
signal vga_player_life_en:std_logic;
---------------------------------------------------------------------
--game logic
signal gameover_en    :std_logic:='0';
signal vga_gameover_en:std_logic:='0';
---------------------------------------------------------------------
--random_gen
signal rand1_val:std_logic_vector(2 downto 0);
signal rand2_val:std_logic_vector(2 downto 0);
signal rand3_val:std_logic_vector(2 downto 0);
signal rand4_val:std_logic_vector(2 downto 0);
---------------------------------------------------------------------
--another random_gen
signal random_count_gen     :std_logic_vector(10 downto 0);
signal random_count_gen_mode:std_logic:='0';
---------------------------------------------------------------------
--screen framework of game
signal vga_framework_en:std_logic;
---------------------------------------------------------------------
--alien
signal vga_alien_en:std_logic_vector(2 downto 0);
signal alien_won       :std_logic_vector(2 downto 0);
signal alien_hit_state :std_logic_vector(2 downto 0);
signal alien_init_pos_1:std_logic_vector(10 downto 0):="00000000100";
signal alien_init_pos_2:std_logic_vector(10 downto 0):="00001000000";
signal alien_init_pos_3:std_logic_vector(10 downto 0):="00011111000";
signal if_alien_goal   :std_logic;
---------------------------------------------------------------------
--star
signal vga_star_en:std_logic;
---------------------------------------------------------------------
--game logic clock
signal move_clk_count:std_logic_vector(4 downto 0);
signal move_clk      :std_logic;
---------------------------------------------------------------------
--missile
signal missile_en    :std_logic:='0';
signal missile_pos_h :std_logic_vector(10 downto 0);
signal missile_pos_v :std_logic_vector(10 downto 0);
signal vga_missile_en:std_logic;
---------------------------------------------------------------------
begin

rand1:random port map(HSync,CLK,rand1_val);
rand2:random port map(HSync,CLK,rand2_val);
rand3:random port map(HSync,CLK,rand3_val);
rand4:random port map(HSync,CLK,rand4_val);
alien_1:alien port map(move_clk,missile_pos_h,missile_pos_v,
                       HCount,VCount,alien_init_pos_1,alien_hit_state(0),
                       vga_alien_en(0),alien_won(0));
alien_2:alien port map(move_clk,missile_pos_h,missile_pos_v,
                       HCount,VCount,alien_init_pos_2,alien_hit_state(1),
                       vga_alien_en(1),alien_won(1));
alien_3:alien port map(move_clk,missile_pos_h,missile_pos_v,
                       HCount,VCount,alien_init_pos_3,alien_hit_state(2),
                       vga_alien_en(2),alien_won(2));
missile_1:missile port map(move_clk,HCount,VCount,BUTTON_B,alien_hit_state,
                           player_pos_h,missile_en,missile_pos_h,
                           missile_pos_v,vga_missile_en);
player_1:player port map(move_clk,HCount,VCount,BUTTON_A,BUTTON_C,
                         player_pos_h,vga_player_en);
---------------------------------------------------------------------
RV<=ColorR;
GV<=ColorG;
BV<=ColorB;
VGA_CLK<=CLK;
BLANK<='1';
SYNC<='0';
---------------------------------------------------------------------
MOVE_CLOCK:process(VSync)
begin
if rising_edge(VSync)then
  if(move_clk_count<1)then--test speed=1, normal speed=15
    move_clk<='0';
    move_clk_count<=move_clk_count+1;
  else
    move_clk_count<=(others=>'0');
    move_clk<='1';
  end if;
end if;
end process MOVE_CLOCK;

RAND_GEN:process(VSync)
begin
if rising_edge(VSync)then
  if(random_count_gen_mode='0')then
    if(random_count_gen<"11111111110")then
      random_count_gen<=random_count_gen+1;
    else
      random_count_gen<="11111111110";
      random_count_gen_mode<='1';
    end if;
  else
    if(random_count_gen>"00000000001")then
      random_count_gen<=random_count_gen-1;
    else
      random_count_gen<="00000000000";
      random_count_gen_mode<='0';
    end if;
  end if;
end if;
end process RAND_GEN;

H_SYNC_SIG:process(RST,CLK)
begin
if RST='0' then
  HCount<=(OTHERS=>'0');
  HSync<='0';
elsif rising_edge(CLK) then
  if HCount<H_PERIOD then
    HCount<=HCount+1;
    HSync<='0';
  else
    HCount<=(OTHERS=>'0');
    HSync<='1';
  end if;
end if;
end process H_SYNC_SIG;

V_SYNC_SIG:process(RST,HSync)
begin
if RST='0' then
  VCount<=(OTHERS=>'0');
  VSync<='0';
elsif rising_edge(HSync) then
  if VCount<V_PERIOD then
    VCount<=Vcount+1;
    VSync<='0';
  else
    VCount<=(OTHERS=>'0');
    VSync<='1';
  end if;
end if;
end process V_SYNC_SIG;

H_SYNC_OUT:process(RST,CLK)
begin
if RST='0' then
  HS<='1';
elsif rising_edge(CLK) then
  if (HCount>=(H_PIXELS+H_FRONTPORCH) and HCount<
      (H_PIXELS+H_FRONTPORCH+H_SYNCTIME)) then
    HS<='0';
  else
    HS<='1';
  end if;
end if;
end process H_SYNC_OUT;

V_SYNC_OUT:process(RST,HSync)
begin
if RST='0' then
  VS<='1';
elsif rising_edge(HSync) then
  if (VCount>=(V_LINES+V_FRONTPORCH) and VCount<
      (V_LINES+V_FRONTPORCH+V_SYNCTIME)) then
    VS<='0';
  else
    VS<='1';
  end if;
end if;
end process V_SYNC_OUT;

H_EN:process(RST,CLK,HCount)
begin
if rising_edge(CLK) then
  if RST='0' then
    HEnable<='0';
  elsif HCount>=H_PIXELS then
    HEnable<='0';
  else
    HEnable<='1';
  end if;
end if;
end process H_EN;

V_EN:process(RST,CLK,VCount)
begin
if rising_edge(CLK) then
  if RST='0' then
    VEnable<='0';
  elsif VCount>=V_LINES then
    VEnable<='0';
  else
    VEnable<='1';
  end if;
end if;
end process V_EN;
-----------------------------screen----------------------------------
FRAMEWORK:process(HCount,VCount)
begin
vga_framework_en<='0';
  if(VCount=26)then
    if((HCount>59 and Hcount<66)or(HCount>202 and Hcount<209)or
       (HCount>271 and Hcount<271)or(HCount>682 and Hcount<686))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=27)then
    if((HCount>55 and Hcount<70)or(HCount>89 and Hcount<117)or
       (HCount>149 and Hcount<161)or(HCount>198 and Hcount<214)or
       (HCount>234 and Hcount<271)or(HCount>295 and Hcount<306)or
       (HCount>314 and Hcount<326)or(HCount>347 and Hcount<357)or
       (HCount>363 and Hcount<376)or(HCount>396 and Hcount<408)or
       (HCount>427 and Hcount<439)or(HCount>462 and Hcount<488)or
       (HCount>512 and Hcount<549)or(HCount>557 and Hcount<586)or
       (HCount>617 and Hcount<630)or(HCount>650 and Hcount<662)or
       (HCount>678 and Hcount<690)or(HCount>741 and Hcount<752))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=28)then
    if((HCount>53 and Hcount<73)or(HCount>90 and Hcount<121)or
       (HCount>150 and Hcount<160)or(HCount>195 and Hcount<216)or
       (HCount>235 and Hcount<271)or(HCount>296 and Hcount<304)or
       (HCount>315 and Hcount<325)or(HCount>349 and Hcount<356)or
       (HCount>365 and Hcount<374)or(HCount>398 and Hcount<406)or
       (HCount>428 and Hcount<438)or(HCount>463 and Hcount<493)or
       (HCount>513 and Hcount<549)or(HCount>558 and Hcount<590)or
       (HCount>619 and Hcount<628)or(HCount>652 and Hcount<660)or
       (HCount>676 and Hcount<692)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=29)then
    if((HCount>51 and Hcount<76)or(HCount>91 and Hcount<123)or
       (HCount>150 and Hcount<159)or(HCount>193 and Hcount<218)or
       (HCount>236 and Hcount<271)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<325)or(HCount>349 and Hcount<355)or
       (HCount>366 and Hcount<374)or(HCount>398 and Hcount<405)or
       (HCount>428 and Hcount<437)or(HCount>464 and Hcount<495)or
       (HCount>514 and Hcount<549)or(HCount>559 and Hcount<592)or
       (HCount>620 and Hcount<628)or(HCount>652 and Hcount<659)or
       (HCount>674 and Hcount<694)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=30)then
    if((HCount>50 and Hcount<78)or(HCount>91 and Hcount<124)or
       (HCount>150 and Hcount<159)or(HCount>191 and Hcount<220)or
       (HCount>236 and Hcount<271)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<325)or(HCount>349 and Hcount<355)or
       (HCount>366 and Hcount<374)or(HCount>398 and Hcount<405)or
       (HCount>428 and Hcount<437)or(HCount>464 and Hcount<497)or
       (HCount>514 and Hcount<549)or(HCount>559 and Hcount<593)or
       (HCount>620 and Hcount<628)or(HCount>652 and Hcount<659)or
       (HCount>673 and Hcount<695)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=31)then
    if((HCount>49 and Hcount<81)or(HCount>91 and Hcount<125)or
       (HCount>150 and Hcount<160)or(HCount>190 and Hcount<222)or
       (HCount>236 and Hcount<271)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<326)or(HCount>349 and Hcount<355)or
       (HCount>367 and Hcount<374)or(HCount>398 and Hcount<404)or
       (HCount>428 and Hcount<438)or(HCount>464 and Hcount<498)or
       (HCount>514 and Hcount<549)or(HCount>559 and Hcount<594)or
       (HCount>621 and Hcount<628)or(HCount>652 and Hcount<658)or
       (HCount>672 and Hcount<696)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=32)then
    if((HCount>48 and Hcount<80)or(HCount>91 and Hcount<126)or
       (HCount>150 and Hcount<160)or(HCount>189 and Hcount<226)or
       (HCount>236 and Hcount<271)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<327)or(HCount>349 and Hcount<355)or
       (HCount>367 and Hcount<374)or(HCount>397 and Hcount<404)or
       (HCount>428 and Hcount<438)or(HCount>464 and Hcount<499)or
       (HCount>514 and Hcount<549)or(HCount>559 and Hcount<595)or
       (HCount>621 and Hcount<628)or(HCount>651 and Hcount<658)or
       (HCount>671 and Hcount<697)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=33)then
    if((HCount>48 and Hcount<56)or(HCount>70 and Hcount<80)or
       (HCount>91 and Hcount<127)or(HCount>149 and Hcount<160)or
       (HCount>188 and Hcount<200)or(HCount>214 and Hcount<225)or
       (HCount>236 and Hcount<271)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<328)or(HCount>349 and Hcount<355)or
       (HCount>368 and Hcount<375)or(HCount>397 and Hcount<404)or
       (HCount>427 and Hcount<438)or(HCount>464 and Hcount<500)or
       (HCount>514 and Hcount<549)or(HCount>559 and Hcount<595)or
       (HCount>622 and Hcount<629)or(HCount>651 and Hcount<658)or
       (HCount>670 and Hcount<679)or(HCount>688 and Hcount<698)or
       (HCount>737 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=34)then
    if((HCount>47 and Hcount<54)or(HCount>73 and Hcount<79)or
       (HCount>91 and Hcount<98)or(HCount>118 and Hcount<127)or
       (HCount>149 and Hcount<161)or(HCount>187 and Hcount<198)or
       (HCount>217 and Hcount<225)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<329)or
       (HCount>349 and Hcount<355)or(HCount>368 and Hcount<375)or
       (HCount>396 and Hcount<403)or(HCount>427 and Hcount<439)or
       (HCount>464 and Hcount<471)or(HCount>490 and Hcount<501)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>587 and Hcount<596)or(HCount>622 and Hcount<629)or
       (HCount>650 and Hcount<657)or(HCount>669 and Hcount<678)or
       (HCount>690 and Hcount<698)or(HCount>737 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=35)then
    if((HCount>47 and Hcount<53)or(HCount>75 and Hcount<79)or
       (HCount>91 and Hcount<98)or(HCount>120 and Hcount<127)or
       (HCount>148 and Hcount<161)or(HCount>187 and Hcount<196)or
       (HCount>219 and Hcount<224)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<330)or
       (HCount>349 and Hcount<355)or(HCount>369 and Hcount<376)or
       (HCount>396 and Hcount<403)or(HCount>426 and Hcount<439)or
       (HCount>464 and Hcount<471)or(HCount>492 and Hcount<501)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>589 and Hcount<596)or(HCount>623 and Hcount<630)or
       (HCount>650 and Hcount<657)or(HCount>669 and Hcount<677)or
       (HCount>691 and Hcount<699)or(HCount>737 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=36)then
    if((HCount>47 and Hcount<53)or(HCount>76 and Hcount<78)or
       (HCount>91 and Hcount<98)or(HCount>120 and Hcount<128)or
       (HCount>148 and Hcount<162)or(HCount>186 and Hcount<195)or
       (HCount>220 and Hcount<223)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<330)or
       (HCount>349 and Hcount<355)or(HCount>369 and Hcount<376)or
       (HCount>395 and Hcount<402)or(HCount>426 and Hcount<440)or
       (HCount>464 and Hcount<471)or(HCount>493 and Hcount<502)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>589 and Hcount<596)or(HCount>623 and Hcount<630)or
       (HCount>649 and Hcount<656)or(HCount>668 and Hcount<676)or
       (HCount>692 and Hcount<700)or(HCount>737 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=37)then
    if((HCount>46 and Hcount<53)or(HCount>77 and Hcount<78)or
       (HCount>91 and Hcount<98)or(HCount>121 and Hcount<128)or
       (HCount>147 and Hcount<153)or(HCount>156 and Hcount<162)or
       (HCount>185 and Hcount<194)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<331)or
       (HCount>349 and Hcount<355)or(HCount>369 and Hcount<377)or
       (HCount>395 and Hcount<402)or(HCount>425 and Hcount<431)or
       (HCount>434 and Hcount<440)or(HCount>464 and Hcount<471)or
       (HCount>494 and Hcount<502)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>590 and Hcount<597)or
       (HCount>623 and Hcount<631)or(HCount>649 and Hcount<656)or
       (HCount>668 and Hcount<675)or(HCount>693 and Hcount<700)or
       (HCount>737 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=38)then
    if((HCount>46 and Hcount<53)or(HCount>91 and Hcount<98)or
       (HCount>121 and Hcount<128)or(HCount>147 and Hcount<153)or
       (HCount>156 and Hcount<163)or(HCount>185 and Hcount<193)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<332)or(HCount>349 and Hcount<355)or
       (HCount>370 and Hcount<377)or(HCount>395 and Hcount<401)or
       (HCount>425 and Hcount<431)or(HCount>434 and Hcount<441)or
       (HCount>464 and Hcount<471)or(HCount>495 and Hcount<503)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>590 and Hcount<597)or(HCount>624 and Hcount<631)or
       (HCount>649 and Hcount<655)or(HCount>667 and Hcount<675)or
       (HCount>693 and Hcount<700)or(HCount>737 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=39)then
    if((HCount>46 and Hcount<53)or(HCount>91 and Hcount<98)or
       (HCount>121 and Hcount<128)or(HCount>146 and Hcount<152)or
       (HCount>156 and Hcount<163)or(HCount>184 and Hcount<192)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>324 and Hcount<333)or
       (HCount>349 and Hcount<355)or(HCount>370 and Hcount<378)or
       (HCount>394 and Hcount<401)or(HCount>424 and Hcount<430)or
       (HCount>434 and Hcount<441)or(HCount>464 and Hcount<471)or
       (HCount>496 and Hcount<503)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>590 and Hcount<597)or
       (HCount>624 and Hcount<632)or(HCount>648 and Hcount<655)or
       (HCount>667 and Hcount<674)or(HCount>694 and Hcount<701)or
       (HCount>737 and Hcount<740)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=40)then
    if((HCount>46 and Hcount<53)or(HCount>91 and Hcount<98)or
       (HCount>121 and Hcount<128)or(HCount>146 and Hcount<152)or
       (HCount>157 and Hcount<164)or(HCount>184 and Hcount<192)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>325 and Hcount<334)or
       (HCount>349 and Hcount<355)or(HCount>371 and Hcount<378)or
       (HCount>394 and Hcount<400)or(HCount>424 and Hcount<430)or
       (HCount>435 and Hcount<442)or(HCount>464 and Hcount<471)or
       (HCount>496 and Hcount<503)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>590 and Hcount<597)or
       (HCount>625 and Hcount<632)or(HCount>648 and Hcount<654)or
       (HCount>667 and Hcount<674)or(HCount>694 and Hcount<701)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=41)then
    if((HCount>47 and Hcount<55)or(HCount>91 and Hcount<98)or
       (HCount>120 and Hcount<128)or(HCount>145 and Hcount<151)or
       (HCount>157 and Hcount<164)or(HCount>184 and Hcount<191)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>326 and Hcount<335)or
       (HCount>349 and Hcount<355)or(HCount>371 and Hcount<379)or
       (HCount>393 and Hcount<400)or(HCount>423 and Hcount<429)or
       (HCount>435 and Hcount<442)or(HCount>464 and Hcount<471)or
       (HCount>496 and Hcount<504)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>589 and Hcount<596)or
       (HCount>625 and Hcount<633)or(HCount>647 and Hcount<654)or
       (HCount>666 and Hcount<674)or(HCount>694 and Hcount<701)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=42)then
    if((HCount>47 and Hcount<63)or(HCount>91 and Hcount<98)or
       (HCount>120 and Hcount<127)or(HCount>145 and Hcount<151)or
       (HCount>158 and Hcount<165)or(HCount>184 and Hcount<191)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>327 and Hcount<336)or
       (HCount>349 and Hcount<355)or(HCount>372 and Hcount<379)or
       (HCount>393 and Hcount<399)or(HCount>423 and Hcount<429)or
       (HCount>436 and Hcount<443)or(HCount>464 and Hcount<471)or
       (HCount>497 and Hcount<504)or(HCount>514 and Hcount<521)or
       (HCount>540 and Hcount<540)or(HCount>559 and Hcount<566)or
       (HCount>589 and Hcount<596)or(HCount>626 and Hcount<633)or
       (HCount>647 and Hcount<653)or(HCount>666 and Hcount<673)or
       (HCount>694 and Hcount<701)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=43)then
    if((HCount>47 and Hcount<70)or(HCount>91 and Hcount<98)or
       (HCount>118 and Hcount<127)or(HCount>144 and Hcount<150)or
       (HCount>158 and Hcount<165)or(HCount>183 and Hcount<190)or
       (HCount>236 and Hcount<262)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>328 and Hcount<337)or
       (HCount>349 and Hcount<355)or(HCount>372 and Hcount<379)or
       (HCount>392 and Hcount<399)or(HCount>422 and Hcount<428)or
       (HCount>436 and Hcount<443)or(HCount>464 and Hcount<471)or
       (HCount>497 and Hcount<504)or(HCount>514 and Hcount<540)or
       (HCount>559 and Hcount<566)or(HCount>587 and Hcount<596)or
       (HCount>626 and Hcount<633)or(HCount>646 and Hcount<653)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=44)then
    if((HCount>48 and Hcount<74)or(HCount>91 and Hcount<127)or
       (HCount>144 and Hcount<150)or(HCount>159 and Hcount<166)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<262)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>329 and Hcount<338)or(HCount>349 and Hcount<355)or
       (HCount>373 and Hcount<380)or(HCount>392 and Hcount<398)or
       (HCount>422 and Hcount<428)or(HCount>437 and Hcount<444)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<540)or(HCount>559 and Hcount<596)or
       (HCount>627 and Hcount<634)or(HCount>646 and Hcount<652)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=45)then
    if((HCount>48 and Hcount<76)or(HCount>91 and Hcount<126)or
       (HCount>143 and Hcount<149)or(HCount>159 and Hcount<166)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<262)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>330 and Hcount<339)or(HCount>349 and Hcount<355)or
       (HCount>373 and Hcount<380)or(HCount>391 and Hcount<398)or
       (HCount>421 and Hcount<427)or(HCount>437 and Hcount<444)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<540)or(HCount>559 and Hcount<595)or
       (HCount>627 and Hcount<634)or(HCount>645 and Hcount<652)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=46)then
    if((HCount>49 and Hcount<77)or(HCount>91 and Hcount<125)or
       (HCount>143 and Hcount<149)or(HCount>160 and Hcount<167)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<262)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>331 and Hcount<340)or(HCount>349 and Hcount<355)or
       (HCount>374 and Hcount<381)or(HCount>391 and Hcount<398)or
       (HCount>421 and Hcount<427)or(HCount>438 and Hcount<445)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<540)or(HCount>559 and Hcount<594)or
       (HCount>628 and Hcount<635)or(HCount>645 and Hcount<652)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=47)then
    if((HCount>50 and Hcount<78)or(HCount>91 and Hcount<124)or
       (HCount>142 and Hcount<149)or(HCount>160 and Hcount<167)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<262)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>332 and Hcount<341)or(HCount>349 and Hcount<355)or
       (HCount>374 and Hcount<381)or(HCount>390 and Hcount<397)or
       (HCount>420 and Hcount<427)or(HCount>438 and Hcount<445)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<540)or(HCount>559 and Hcount<593)or
       (HCount>628 and Hcount<635)or(HCount>644 and Hcount<651)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=48)then
    if((HCount>52 and Hcount<79)or(HCount>91 and Hcount<123)or
       (HCount>142 and Hcount<148)or(HCount>161 and Hcount<168)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<262)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>333 and Hcount<342)or(HCount>349 and Hcount<355)or
       (HCount>375 and Hcount<382)or(HCount>390 and Hcount<397)or
       (HCount>420 and Hcount<426)or(HCount>439 and Hcount<446)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<540)or(HCount>559 and Hcount<592)or
       (HCount>629 and Hcount<636)or(HCount>644 and Hcount<651)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=49)then
    if((HCount>54 and Hcount<80)or(HCount>91 and Hcount<121)or
       (HCount>141 and Hcount<148)or(HCount>161 and Hcount<168)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<262)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>334 and Hcount<343)or(HCount>349 and Hcount<355)or
       (HCount>375 and Hcount<382)or(HCount>390 and Hcount<396)or
       (HCount>419 and Hcount<426)or(HCount>439 and Hcount<446)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<540)or(HCount>559 and Hcount<590)or
       (HCount>629 and Hcount<636)or(HCount>644 and Hcount<650)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=50)then
    if((HCount>59 and Hcount<80)or(HCount>91 and Hcount<117)or
       (HCount>141 and Hcount<147)or(HCount>162 and Hcount<169)or
       (HCount>183 and Hcount<190)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>335 and Hcount<344)or(HCount>349 and Hcount<355)or
       (HCount>375 and Hcount<383)or(HCount>389 and Hcount<396)or
       (HCount>419 and Hcount<425)or(HCount>440 and Hcount<447)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<587)or
       (HCount>629 and Hcount<637)or(HCount>643 and Hcount<650)or
       (HCount>666 and Hcount<673)or(HCount>695 and Hcount<702)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=51)then
    if((HCount>68 and Hcount<81)or(HCount>91 and Hcount<98)or
       (HCount>140 and Hcount<169)or(HCount>184 and Hcount<191)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>336 and Hcount<345)or
       (HCount>349 and Hcount<355)or(HCount>376 and Hcount<383)or
       (HCount>389 and Hcount<395)or(HCount>418 and Hcount<447)or
       (HCount>464 and Hcount<471)or(HCount>497 and Hcount<504)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>578 and Hcount<586)or(HCount>630 and Hcount<637)or
       (HCount>643 and Hcount<649)or(HCount>666 and Hcount<673)or
       (HCount>694 and Hcount<701)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=52)then
    if((HCount>73 and Hcount<81)or(HCount>91 and Hcount<98)or
       (HCount>140 and Hcount<170)or(HCount>184 and Hcount<191)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>337 and Hcount<346)or
       (HCount>349 and Hcount<355)or(HCount>376 and Hcount<383)or
       (HCount>388 and Hcount<395)or(HCount>418 and Hcount<448)or
       (HCount>464 and Hcount<471)or(HCount>496 and Hcount<504)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>579 and Hcount<587)or(HCount>630 and Hcount<637)or
       (HCount>642 and Hcount<649)or(HCount>667 and Hcount<674)or
       (HCount>694 and Hcount<701)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=53)then
    if((HCount>74 and Hcount<81)or(HCount>91 and Hcount<98)or
       (HCount>139 and Hcount<170)or(HCount>184 and Hcount<192)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>338 and Hcount<347)or
       (HCount>349 and Hcount<355)or(HCount>377 and Hcount<384)or
       (HCount>388 and Hcount<394)or(HCount>417 and Hcount<448)or
       (HCount>464 and Hcount<471)or(HCount>496 and Hcount<503)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>580 and Hcount<587)or(HCount>631 and Hcount<638)or
       (HCount>642 and Hcount<648)or(HCount>667 and Hcount<674)or
       (HCount>694 and Hcount<701)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=54)then
    if((HCount>75 and Hcount<81)or(HCount>91 and Hcount<98)or
       (HCount>139 and Hcount<171)or(HCount>184 and Hcount<192)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>339 and Hcount<355)or
       (HCount>377 and Hcount<384)or(HCount>387 and Hcount<394)or
       (HCount>417 and Hcount<449)or(HCount>464 and Hcount<471)or
       (HCount>496 and Hcount<503)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>581 and Hcount<588)or
       (HCount>631 and Hcount<638)or(HCount>641 and Hcount<648)or
       (HCount>667 and Hcount<674)or(HCount>694 and Hcount<701)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=55)then
    if((HCount>75 and Hcount<81)or(HCount>91 and Hcount<98)or
       (HCount>138 and Hcount<171)or(HCount>185 and Hcount<193)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>340 and Hcount<355)or
       (HCount>378 and Hcount<385)or(HCount>387 and Hcount<393)or
       (HCount>416 and Hcount<449)or(HCount>464 and Hcount<471)or
       (HCount>495 and Hcount<503)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>581 and Hcount<589)or
       (HCount>632 and Hcount<639)or(HCount>641 and Hcount<647)or
       (HCount>667 and Hcount<675)or(HCount>693 and Hcount<700)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=56)then
    if((HCount>75 and Hcount<81)or(HCount>91 and Hcount<98)or
       (HCount>138 and Hcount<144)or(HCount>164 and Hcount<172)or
       (HCount>185 and Hcount<194)or(HCount>221 and Hcount<223)or
       (HCount>236 and Hcount<243)or(HCount>297 and Hcount<304)or
       (HCount>316 and Hcount<322)or(HCount>341 and Hcount<355)or
       (HCount>378 and Hcount<393)or(HCount>416 and Hcount<422)or
       (HCount>442 and Hcount<450)or(HCount>464 and Hcount<471)or
       (HCount>494 and Hcount<502)or(HCount>514 and Hcount<521)or
       (HCount>559 and Hcount<566)or(HCount>582 and Hcount<590)or
       (HCount>632 and Hcount<647)or(HCount>668 and Hcount<675)or
       (HCount>693 and Hcount<700)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=57)then
    if((HCount>48 and Hcount<50)or(HCount>74 and Hcount<81)or
       (HCount>91 and Hcount<98)or(HCount>138 and Hcount<144)or
       (HCount>165 and Hcount<172)or(HCount>186 and Hcount<195)or
       (HCount>220 and Hcount<224)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>341 and Hcount<355)or(HCount>379 and Hcount<392)or
       (HCount>416 and Hcount<422)or(HCount>443 and Hcount<450)or
       (HCount>464 and Hcount<471)or(HCount>493 and Hcount<502)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>583 and Hcount<590)or(HCount>633 and Hcount<646)or
       (HCount>668 and Hcount<676)or(HCount>692 and Hcount<700)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=58)then
    if((HCount>47 and Hcount<51)or(HCount>73 and Hcount<81)or
       (HCount>91 and Hcount<98)or(HCount>137 and Hcount<143)or
       (HCount>165 and Hcount<173)or(HCount>187 and Hcount<196)or
       (HCount>218 and Hcount<224)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>342 and Hcount<355)or(HCount>379 and Hcount<392)or
       (HCount>415 and Hcount<421)or(HCount>443 and Hcount<451)or
       (HCount>464 and Hcount<471)or(HCount>492 and Hcount<501)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>584 and Hcount<591)or(HCount>633 and Hcount<646)or
       (HCount>669 and Hcount<677)or(HCount>691 and Hcount<699)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=59)then
    if((HCount>47 and Hcount<54)or(HCount>72 and Hcount<80)or
       (HCount>91 and Hcount<98)or(HCount>137 and Hcount<143)or
       (HCount>166 and Hcount<173)or(HCount>187 and Hcount<198)or
       (HCount>216 and Hcount<225)or(HCount>236 and Hcount<243)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>343 and Hcount<355)or(HCount>380 and Hcount<391)or
       (HCount>415 and Hcount<421)or(HCount>444 and Hcount<451)or
       (HCount>464 and Hcount<471)or(HCount>490 and Hcount<501)or
       (HCount>514 and Hcount<521)or(HCount>559 and Hcount<566)or
       (HCount>584 and Hcount<592)or(HCount>634 and Hcount<645)or
       (HCount>669 and Hcount<678)or(HCount>690 and Hcount<698)or
       (HCount>712 and Hcount<717)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=60)then
    if((HCount>46 and Hcount<57)or(HCount>70 and Hcount<80)or
       (HCount>91 and Hcount<98)or(HCount>136 and Hcount<142)or
       (HCount>166 and Hcount<174)or(HCount>188 and Hcount<200)or
       (HCount>213 and Hcount<226)or(HCount>236 and Hcount<272)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>344 and Hcount<355)or(HCount>380 and Hcount<391)or
       (HCount>414 and Hcount<420)or(HCount>444 and Hcount<452)or
       (HCount>464 and Hcount<500)or(HCount>514 and Hcount<550)or
       (HCount>559 and Hcount<566)or(HCount>585 and Hcount<593)or
       (HCount>634 and Hcount<645)or(HCount>670 and Hcount<679)or
       (HCount>688 and Hcount<698)or(HCount>712 and Hcount<718)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=61)then
    if((HCount>46 and Hcount<79)or(HCount>91 and Hcount<98)or
       (HCount>136 and Hcount<142)or(HCount>167 and Hcount<174)or
       (HCount>189 and Hcount<223)or(HCount>236 and Hcount<272)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>345 and Hcount<355)or(HCount>381 and Hcount<391)or
       (HCount>414 and Hcount<420)or(HCount>445 and Hcount<452)or
       (HCount>464 and Hcount<499)or(HCount>514 and Hcount<550)or
       (HCount>559 and Hcount<566)or(HCount>586 and Hcount<593)or
       (HCount>635 and Hcount<645)or(HCount>671 and Hcount<697)or
       (HCount>711 and Hcount<718)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=62)then
    if((HCount>45 and Hcount<78)or(HCount>91 and Hcount<98)or
       (HCount>135 and Hcount<141)or(HCount>167 and Hcount<175)or
       (HCount>190 and Hcount<221)or(HCount>236 and Hcount<272)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>346 and Hcount<355)or(HCount>381 and Hcount<390)or
       (HCount>413 and Hcount<419)or(HCount>445 and Hcount<453)or
       (HCount>464 and Hcount<498)or(HCount>514 and Hcount<550)or
       (HCount>559 and Hcount<566)or(HCount>586 and Hcount<594)or
       (HCount>635 and Hcount<644)or(HCount>672 and Hcount<696)or
       (HCount>711 and Hcount<719)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=63)then
    if((HCount>48 and Hcount<77)or(HCount>91 and Hcount<98)or
       (HCount>135 and Hcount<141)or(HCount>168 and Hcount<175)or
       (HCount>191 and Hcount<220)or(HCount>236 and Hcount<272)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>347 and Hcount<355)or(HCount>381 and Hcount<390)or
       (HCount>413 and Hcount<419)or(HCount>446 and Hcount<453)or
       (HCount>464 and Hcount<497)or(HCount>514 and Hcount<550)or
       (HCount>559 and Hcount<566)or(HCount>587 and Hcount<595)or
       (HCount>635 and Hcount<644)or(HCount>673 and Hcount<695)or
       (HCount>711 and Hcount<719)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=64)then
    if((HCount>50 and Hcount<76)or(HCount>91 and Hcount<98)or
       (HCount>134 and Hcount<141)or(HCount>168 and Hcount<176)or
       (HCount>193 and Hcount<218)or(HCount>236 and Hcount<272)or
       (HCount>297 and Hcount<304)or(HCount>316 and Hcount<322)or
       (HCount>348 and Hcount<355)or(HCount>381 and Hcount<390)or
       (HCount>412 and Hcount<419)or(HCount>446 and Hcount<454)or
       (HCount>464 and Hcount<495)or(HCount>514 and Hcount<550)or
       (HCount>559 and Hcount<566)or(HCount>588 and Hcount<596)or
       (HCount>635 and Hcount<644)or(HCount>674 and Hcount<694)or
       (HCount>711 and Hcount<718)or(HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=65)then
    if((HCount>53 and Hcount<74)or(HCount>90 and Hcount<98)or
       (HCount>133 and Hcount<141)or(HCount>167 and Hcount<177)or
       (HCount>195 and Hcount<216)or(HCount>235 and Hcount<272)or
       (HCount>296 and Hcount<304)or(HCount>315 and Hcount<322)or
       (HCount>348 and Hcount<356)or(HCount>381 and Hcount<390)or
       (HCount>411 and Hcount<419)or(HCount>463 and Hcount<492)or
       (HCount>513 and Hcount<550)or(HCount>558 and Hcount<566)or
       (HCount>588 and Hcount<597)or(HCount>635 and Hcount<644)or
       (HCount>676 and Hcount<692)or(HCount>712 and Hcount<718)or
       (HCount>743 and Hcount<750))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=66)then
    if((HCount>56 and Hcount<71)or(HCount>89 and Hcount<100)or
       (HCount>132 and Hcount<143)or(HCount>166 and Hcount<179)or
       (HCount>198 and Hcount<213)or(HCount>234 and Hcount<272)or
       (HCount>295 and Hcount<306)or(HCount>314 and Hcount<324)or
       (HCount>346 and Hcount<357)or(HCount>380 and Hcount<392)or
       (HCount>410 and Hcount<421)or(HCount>444 and Hcount<457)or
       (HCount>462 and Hcount<488)or(HCount>512 and Hcount<550)or
       (HCount>557 and Hcount<568)or(HCount>586 and Hcount<599)or
       (HCount>634 and Hcount<646)or(HCount>678 and Hcount<690)or
       (HCount>712 and Hcount<717)or(HCount>741 and Hcount<752))then
      vga_framework_en<='1';
    end if;
  elsif(VCount=67)then
    if((HCount>60 and Hcount<67)or(HCount>202 and Hcount<209)or(HCount>681 and Hcount<686))then
      vga_framework_en<='1';
    end if;
  elsif((VCount>94 and VCount<108)or(VCount>169 and VCount<183)or(VCount>496 and VCount<500))then
    vga_framework_en<='1';
  end if;
end process FRAMEWORK;
--------------------------game over----------------------------------
GAMEOVER:process(HCount,VCount)
begin
vga_gameover_en<='0';
if(VCount=202)then
  if((HCount>217 and Hcount<224)or(HCount>450 and Hcount<456))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=203)then
  if((HCount>212 and Hcount<229)or(HCount>264 and Hcount<276)or
     (HCount>299 and Hcount<313)or(HCount>335 and Hcount<348)or
	 (HCount>357 and Hcount<394)or(HCount>445 and Hcount<461)or
	 (HCount>480 and Hcount<493)or(HCount>513 and Hcount<525)or
	 (HCount>530 and Hcount<567)or(HCount>575 and Hcount<604))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=204)then
  if((HCount>209 and Hcount<232)or(HCount>265 and Hcount<275)or
     (HCount>300 and Hcount<311)or(HCount>336 and Hcount<346)or
	 (HCount>358 and Hcount<394)or(HCount>443 and Hcount<464)or
	 (HCount>482 and Hcount<491)or(HCount>515 and Hcount<523)or
	 (HCount>531 and Hcount<567)or(HCount>576 and Hcount<608))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=205)then
  if((HCount>207 and Hcount<237)or(HCount>265 and Hcount<274)or
     (HCount>301 and Hcount<311)or(HCount>336 and Hcount<346)or
	 (HCount>359 and Hcount<394)or(HCount>441 and Hcount<465)or
	 (HCount>483 and Hcount<491)or(HCount>515 and Hcount<522)or
	 (HCount>532 and Hcount<567)or(HCount>577 and Hcount<610))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=206)then
  if((HCount>206 and Hcount<237)or(HCount>265 and Hcount<274)or
     (HCount>301 and Hcount<311)or(HCount>336 and Hcount<346)or
	 (HCount>359 and Hcount<394)or(HCount>439 and Hcount<467)or
	 (HCount>483 and Hcount<491)or(HCount>515 and Hcount<522)or
	 (HCount>532 and Hcount<567)or(HCount>577 and Hcount<611))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=207)then
  if((HCount>204 and Hcount<236)or(HCount>265 and Hcount<275)or
     (HCount>301 and Hcount<312)or(HCount>335 and Hcount<346)or
	 (HCount>359 and Hcount<394)or(HCount>438 and Hcount<468)or
	 (HCount>484 and Hcount<491)or(HCount>515 and Hcount<521)or
	 (HCount>532 and Hcount<567)or(HCount>577 and Hcount<612))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=208)then
  if((HCount>203 and Hcount<236)or(HCount>265 and Hcount<275)or
     (HCount>301 and Hcount<312)or(HCount>335 and Hcount<346)or
	 (HCount>359 and Hcount<394)or(HCount>437 and Hcount<469)or
	 (HCount>484 and Hcount<491)or(HCount>514 and Hcount<521)or
	 (HCount>532 and Hcount<567)or(HCount>577 and Hcount<613))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=209)then
  if((HCount>202 and Hcount<214)or(HCount>227 and Hcount<235)or
     (HCount>264 and Hcount<275)or(HCount>301 and Hcount<313)or
	 (HCount>334 and Hcount<346)or(HCount>359 and Hcount<394)or
	 (HCount>436 and Hcount<447)or(HCount>459 and Hcount<470)or
	 (HCount>485 and Hcount<492)or(HCount>514 and Hcount<521)or
	 (HCount>532 and Hcount<567)or(HCount>577 and Hcount<613))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=210)then
  if((HCount>201 and Hcount<211)or(HCount>230 and Hcount<235)or
     (HCount>264 and Hcount<276)or(HCount>301 and Hcount<313)or
	 (HCount>334 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>435 and Hcount<445)or(HCount>461 and Hcount<471)or
	 (HCount>485 and Hcount<492)or(HCount>513 and Hcount<520)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>605 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=211)then
  if((HCount>200 and Hcount<210)or(HCount>232 and Hcount<234)or
     (HCount>263 and Hcount<276)or(HCount>301 and Hcount<314)or
	 (HCount>333 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>435 and Hcount<443)or(HCount>463 and Hcount<472)or
	 (HCount>486 and Hcount<493)or(HCount>513 and Hcount<520)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>607 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=212)then
  if((HCount>200 and Hcount<209)or(HCount>263 and Hcount<277)or
     (HCount>301 and Hcount<314)or(HCount>333 and Hcount<346)or
	 (HCount>359 and Hcount<366)or(HCount>434 and Hcount<442)or
	 (HCount>464 and Hcount<472)or(HCount>486 and Hcount<493)or
	 (HCount>512 and Hcount<519)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>607 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=213)then
  if((HCount>199 and Hcount<208)or(HCount>262 and Hcount<268)or
     (HCount>271 and Hcount<277)or(HCount>301 and Hcount<315)or
	 (HCount>332 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>433 and Hcount<441)or(HCount>465 and Hcount<473)or
	 (HCount>486 and Hcount<494)or(HCount>512 and Hcount<519)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>608 and Hcount<615))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=214)then
  if((HCount>199 and Hcount<207)or(HCount>262 and Hcount<268)or
     (HCount>271 and Hcount<278)or(HCount>301 and Hcount<315)or
	 (HCount>332 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>433 and Hcount<441)or(HCount>466 and Hcount<473)or
	 (HCount>487 and Hcount<494)or(HCount>512 and Hcount<518)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>608 and Hcount<615))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=215)then
  if((HCount>198 and Hcount<206)or(HCount>261 and Hcount<267)or
     (HCount>271 and Hcount<278)or(HCount>301 and Hcount<307)or
	 (HCount>309 and Hcount<316)or(HCount>331 and Hcount<337)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>432 and Hcount<440)or(HCount>466 and Hcount<474)or
	 (HCount>487 and Hcount<495)or(HCount>511 and Hcount<518)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>608 and Hcount<615))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=216)then
  if((HCount>198 and Hcount<206)or(HCount>261 and Hcount<267)or
     (HCount>272 and Hcount<279)or(HCount>301 and Hcount<307)or
	 (HCount>310 and Hcount<317)or(HCount>331 and Hcount<337)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>432 and Hcount<439)or(HCount>467 and Hcount<474)or
	 (HCount>488 and Hcount<495)or(HCount>511 and Hcount<517)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>608 and Hcount<615))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=217)then
  if((HCount>198 and Hcount<205)or(HCount>260 and Hcount<266)or
     (HCount>272 and Hcount<279)or(HCount>301 and Hcount<307)or
	 (HCount>310 and Hcount<317)or(HCount>330 and Hcount<336)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>432 and Hcount<439)or(HCount>467 and Hcount<474)or
	 (HCount>488 and Hcount<496)or(HCount>510 and Hcount<517)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>607 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=218)then
  if((HCount>198 and Hcount<205)or(HCount>260 and Hcount<266)or
     (HCount>273 and Hcount<280)or(HCount>301 and Hcount<307)or
	 (HCount>311 and Hcount<318)or(HCount>329 and Hcount<335)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>432 and Hcount<439)or(HCount>468 and Hcount<475)or
	 (HCount>489 and Hcount<496)or(HCount>510 and Hcount<516)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>607 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=219)then
  if((HCount>197 and Hcount<204)or(HCount>259 and Hcount<265)or
     (HCount>273 and Hcount<280)or(HCount>301 and Hcount<307)or
	 (HCount>311 and Hcount<318)or(HCount>329 and Hcount<335)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<385)or
	 (HCount>431 and Hcount<438)or(HCount>468 and Hcount<475)or
	 (HCount>489 and Hcount<496)or(HCount>509 and Hcount<516)or
	 (HCount>532 and Hcount<558)or(HCount>577 and Hcount<584)or
	 (HCount>605 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=220)then
  if((HCount>197 and Hcount<204)or(HCount>259 and Hcount<265)or
     (HCount>274 and Hcount<281)or(HCount>301 and Hcount<307)or
	 (HCount>312 and Hcount<319)or(HCount>328 and Hcount<334)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<385)or
	 (HCount>431 and Hcount<438)or(HCount>468 and Hcount<475)or
	 (HCount>490 and Hcount<497)or(HCount>509 and Hcount<515)or
	 (HCount>532 and Hcount<558)or(HCount>577 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=221)then
  if((HCount>197 and Hcount<204)or(HCount>258 and Hcount<264)or
     (HCount>274 and Hcount<281)or(HCount>301 and Hcount<307)or
	 (HCount>312 and Hcount<319)or(HCount>328 and Hcount<334)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<385)or
	 (HCount>431 and Hcount<438)or(HCount>468 and Hcount<475)or
	 (HCount>490 and Hcount<497)or(HCount>508 and Hcount<515)or
	 (HCount>532 and Hcount<558)or(HCount>577 and Hcount<613))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=222)then
  if((HCount>197 and Hcount<204)or(HCount>258 and Hcount<264)or
     (HCount>275 and Hcount<282)or(HCount>301 and Hcount<307)or
	 (HCount>313 and Hcount<320)or(HCount>327 and Hcount<333)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<385)or
	 (HCount>431 and Hcount<438)or(HCount>468 and Hcount<475)or
	 (HCount>491 and Hcount<498)or(HCount>508 and Hcount<515)or
	 (HCount>532 and Hcount<558)or(HCount>577 and Hcount<612))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=223)then
  if((HCount>197 and Hcount<204)or(HCount>221 and Hcount<241)or
     (HCount>257 and Hcount<264)or(HCount>275 and Hcount<282)or
	 (HCount>301 and Hcount<307)or(HCount>313 and Hcount<320)or
	 (HCount>327 and Hcount<333)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<385)or(HCount>431 and Hcount<438)or
	 (HCount>468 and Hcount<475)or(HCount>491 and Hcount<498)or
	 (HCount>507 and Hcount<514)or(HCount>532 and Hcount<558)or
	 (HCount>577 and Hcount<611))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=224)then
  if((HCount>197 and Hcount<204)or(HCount>221 and Hcount<239)or
     (HCount>257 and Hcount<263)or(HCount>276 and Hcount<283)or
	 (HCount>301 and Hcount<307)or(HCount>314 and Hcount<321)or
	 (HCount>326 and Hcount<332)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<385)or(HCount>431 and Hcount<438)or
	 (HCount>468 and Hcount<475)or(HCount>492 and Hcount<499)or
	 (HCount>507 and Hcount<514)or(HCount>532 and Hcount<558)or
	 (HCount>577 and Hcount<610))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=225)then
  if((HCount>197 and Hcount<204)or(HCount>221 and Hcount<239)or
     (HCount>256 and Hcount<263)or(HCount>276 and Hcount<283)or
	 (HCount>301 and Hcount<307)or(HCount>314 and Hcount<321)or
	 (HCount>326 and Hcount<331)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<385)or(HCount>431 and Hcount<438)or
	 (HCount>468 and Hcount<475)or(HCount>492 and Hcount<499)or
	 (HCount>507 and Hcount<513)or(HCount>532 and Hcount<558)or
	 (HCount>577 and Hcount<608))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=226)then
  if((HCount>197 and Hcount<204)or(HCount>221 and Hcount<239)or
     (HCount>256 and Hcount<262)or(HCount>277 and Hcount<284)or
	 (HCount>301 and Hcount<307)or(HCount>315 and Hcount<322)or
	 (HCount>325 and Hcount<331)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<366)or(HCount>431 and Hcount<438)or
	 (HCount>468 and Hcount<475)or(HCount>492 and Hcount<500)or
	 (HCount>506 and Hcount<513)or(HCount>532 and Hcount<539)or
	 (HCount>558 and Hcount<558)or(HCount>577 and Hcount<605))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=227)then
  if((HCount>198 and Hcount<205)or(HCount>221 and Hcount<239)or
     (HCount>255 and Hcount<284)or(HCount>301 and Hcount<307)or
	 (HCount>316 and Hcount<322)or(HCount>325 and Hcount<330)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>432 and Hcount<439)or(HCount>468 and Hcount<475)or
	 (HCount>493 and Hcount<500)or(HCount>506 and Hcount<512)or
	 (HCount>532 and Hcount<539)or(HCount>577 and Hcount<584)or
	 (HCount>596 and Hcount<604))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=228)then
  if((HCount>198 and Hcount<205)or(HCount>221 and Hcount<239)or
     (HCount>255 and Hcount<285)or(HCount>301 and Hcount<307)or
	 (HCount>316 and Hcount<330)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<366)or(HCount>432 and Hcount<439)or
	 (HCount>467 and Hcount<474)or(HCount>493 and Hcount<500)or
	 (HCount>505 and Hcount<512)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>597 and Hcount<605))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=229)then
  if((HCount>198 and Hcount<205)or(HCount>221 and Hcount<239)or
     (HCount>254 and Hcount<285)or(HCount>301 and Hcount<307)or
	 (HCount>317 and Hcount<329)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<366)or(HCount>432 and Hcount<439)or
	 (HCount>467 and Hcount<474)or(HCount>494 and Hcount<501)or
	 (HCount>505 and Hcount<511)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>598 and Hcount<605))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=230)then
  if((HCount>198 and Hcount<206)or(HCount>234 and Hcount<239)or
     (HCount>254 and Hcount<286)or(HCount>301 and Hcount<307)or
	 (HCount>317 and Hcount<329)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<366)or(HCount>433 and Hcount<440)or
	 (HCount>466 and Hcount<474)or(HCount>494 and Hcount<501)or
	 (HCount>504 and Hcount<511)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>599 and Hcount<606))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=231)then
  if((HCount>199 and Hcount<207)or(HCount>234 and Hcount<239)or
     (HCount>253 and Hcount<286)or(HCount>301 and Hcount<307)or
	 (HCount>318 and Hcount<328)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<366)or(HCount>433 and Hcount<441)or
	 (HCount>466 and Hcount<473)or(HCount>495 and Hcount<502)or
	 (HCount>504 and Hcount<510)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>599 and Hcount<607))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=232)then
  if((HCount>199 and Hcount<207)or(HCount>234 and Hcount<239)or
     (HCount>253 and Hcount<259)or(HCount>279 and Hcount<287)or
	 (HCount>301 and Hcount<307)or(HCount>318 and Hcount<328)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>433 and Hcount<441)or(HCount>465 and Hcount<473)or
	 (HCount>495 and Hcount<510)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>600 and Hcount<608))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=233)then
  if((HCount>200 and Hcount<209)or(HCount>234 and Hcount<239)or
     (HCount>253 and Hcount<259)or(HCount>280 and Hcount<287)or
	 (HCount>301 and Hcount<307)or(HCount>319 and Hcount<327)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>434 and Hcount<442)or(HCount>464 and Hcount<472)or
	 (HCount>496 and Hcount<509)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>601 and Hcount<608))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=234)then
  if((HCount>200 and Hcount<210)or(HCount>234 and Hcount<239)or
     (HCount>252 and Hcount<258)or(HCount>280 and Hcount<288)or
	 (HCount>301 and Hcount<307)or(HCount>319 and Hcount<326)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>435 and Hcount<443)or(HCount>463 and Hcount<472)or
	 (HCount>496 and Hcount<509)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>602 and Hcount<609))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=235)then
  if((HCount>201 and Hcount<211)or(HCount>232 and Hcount<239)or
     (HCount>252 and Hcount<258)or(HCount>281 and Hcount<288)or
	 (HCount>301 and Hcount<307)or(HCount>320 and Hcount<326)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<366)or
	 (HCount>435 and Hcount<445)or(HCount>461 and Hcount<471)or
	 (HCount>497 and Hcount<508)or(HCount>532 and Hcount<539)or
	 (HCount>577 and Hcount<584)or(HCount>602 and Hcount<610))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=236)then
  if((HCount>202 and Hcount<214)or(HCount>229 and Hcount<241)or
     (HCount>251 and Hcount<257)or(HCount>281 and Hcount<289)or
	 (HCount>301 and Hcount<307)or(HCount>320 and Hcount<325)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<395)or
	 (HCount>436 and Hcount<447)or(HCount>459 and Hcount<470)or
	 (HCount>497 and Hcount<508)or(HCount>532 and Hcount<568)or
	 (HCount>577 and Hcount<584)or(HCount>603 and Hcount<611))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=237)then
  if((HCount>203 and Hcount<240)or(HCount>251 and Hcount<257)or
     (HCount>282 and Hcount<289)or(HCount>301 and Hcount<307)or
	 (HCount>321 and Hcount<325)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<395)or(HCount>437 and Hcount<469)or
	 (HCount>498 and Hcount<508)or(HCount>532 and Hcount<568)or
	 (HCount>577 and Hcount<584)or(HCount>604 and Hcount<611))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=238)then
  if((HCount>204 and Hcount<238)or(HCount>250 and Hcount<256)or
     (HCount>282 and Hcount<290)or(HCount>301 and Hcount<307)or
	 (HCount>321 and Hcount<324)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<395)or(HCount>438 and Hcount<468)or
	 (HCount>498 and Hcount<507)or(HCount>532 and Hcount<568)or
	 (HCount>577 and Hcount<584)or(HCount>604 and Hcount<612))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=239)then
  if((HCount>205 and Hcount<236)or(HCount>250 and Hcount<256)or
     (HCount>283 and Hcount<290)or(HCount>301 and Hcount<307)or
	 (HCount>322 and Hcount<324)or(HCount>339 and Hcount<346)or
	 (HCount>359 and Hcount<395)or(HCount>439 and Hcount<467)or
	 (HCount>498 and Hcount<507)or(HCount>532 and Hcount<568)or
	 (HCount>577 and Hcount<584)or(HCount>605 and Hcount<613))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=240)then
  if((HCount>207 and Hcount<234)or(HCount>249 and Hcount<256)or
     (HCount>283 and Hcount<291)or(HCount>301 and Hcount<307)or
	 (HCount>339 and Hcount<346)or(HCount>359 and Hcount<395)or
	 (HCount>441 and Hcount<466)or(HCount>498 and Hcount<507)or
	 (HCount>532 and Hcount<568)or(HCount>577 and Hcount<584)or
	 (HCount>606 and Hcount<614))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=241)then
  if((HCount>209 and Hcount<231)or(HCount>248 and Hcount<256)or
     (HCount>282 and Hcount<292)or(HCount>300 and Hcount<307)or
	 (HCount>339 and Hcount<346)or(HCount>358 and Hcount<395)or
	 (HCount>443 and Hcount<464)or(HCount>498 and Hcount<507)or
	 (HCount>531 and Hcount<568)or(HCount>576 and Hcount<584)or
	 (HCount>606 and Hcount<615))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=242)then
  if((HCount>212 and Hcount<228)or(HCount>247 and Hcount<258)or
     (HCount>281 and Hcount<294)or(HCount>299 and Hcount<309)or
	 (HCount>337 and Hcount<348)or(HCount>357 and Hcount<395)or
	 (HCount>445 and Hcount<461)or(HCount>497 and Hcount<509)or
	 (HCount>530 and Hcount<568)or(HCount>575 and Hcount<586)or
	 (HCount>604 and Hcount<617))then
    vga_gameover_en<='1';
  end if;
elsif(VCount=243)then
  if((HCount>216 and Hcount<223)or(HCount>450 and Hcount<456))then
    vga_gameover_en<='1';
  end if;
end if;
end process GAMEOVER;
---------------------player life-------------------------------------
PLAYER_STATUS:process(HCount,VCount)
begin
vga_player_life_en<='0';
if(VCount>115 and VCount<162)then
  if(HCount<801 and HCount<PLAYER_LIFE)then
    vga_player_life_en<='1';
  end if;
end if;
end process PLAYER_STATUS;

---------------------------------------------------------------------
SCREEN:process(HCount,VCount,HEnable,VEnable)
begin
  if (HEnable='1' and VEnable='1') then
    if(vga_framework_en='1')then
      ColorR<=(others=>'1');
      ColorG<=(others=>'1');
      ColorB<=(others=>'1');
    elsif(gameover_en='1')then
      if(VCount>60)then
        if(vga_gameover_en='1')then
          ColorR<=(others=>'0');
          ColorG<=(others=>'0');
          ColorB<=(others=>'0');
        else
          ColorR<=(others=>'1');
          ColorG<=(others=>'1');
          ColorB<=(others=>'1');
        end if;
      end if;
    elsif(vga_player_life_en='1')then
      ColorR<=(others=>'1');
      ColorG<=(others=>'1');
      ColorB<=(others=>'1');
    elsif(vga_alien_en(0)='1' or vga_alien_en(1)='1' or vga_alien_en(2)='1')then
          ColorR<=(others=>'1');
          ColorG<=(others=>'1');
          ColorB<=(others=>'1');
    elsif(vga_missile_en='1')then
      ColorR<=(others=>'1');
      ColorG<=(others=>'1');
      ColorB<=(others=>'1');
    elsif(vga_player_en='1')then
      ColorR<=(others=>'1');
      ColorG<=(others=>'1');
      ColorB<=(others=>'1');
    else
      ColorR<=(others=>'0');
      ColorG<=(others=>'0');
      ColorB<=(others=>'0');
    end if;
  else
    ColorR<=(others=>'0');
    ColorG<=(others=>'0');
    ColorB<=(others=>'0');
  end if;
end process SCREEN;

end behave;