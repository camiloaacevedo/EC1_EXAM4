# =============================================================================
# de2_115_pins.tcl
# Quartus II / Quartus Prime Pin Assignment Script
# Target: Altera DE2-115 (Cyclone IV EP4CE115F29C7)
# =============================================================================
# How to use:
#   1. Open your project in Quartus Prime.
#   2. Go to Tools -> Tcl Scripts -> Run.
#   3. Select this file, click Run.
# OR run from the Nios II Command Shell:
#   quartus_sh --tcl_eval source de2_115_pins.tcl
# =============================================================================

# Clock and reset
set_location_assignment PIN_Y2   -to CLOCK_50
set_location_assignment PIN_M23  -to "KEY[0]"
set_location_assignment PIN_M21  -to "KEY[1]"
set_location_assignment PIN_N21  -to "KEY[2]"
set_location_assignment PIN_R24  -to "KEY[3]"

# Switches
set_location_assignment PIN_AB28  -to "SW[0]"
set_location_assignment PIN_AC28  -to "SW[1]"
set_location_assignment PIN_AC27  -to "SW[2]"
set_location_assignment PIN_AD27  -to "SW[3]"
set_location_assignment PIN_AB27  -to "SW[4]"
set_location_assignment PIN_AC26  -to "SW[5]"
set_location_assignment PIN_AD26  -to "SW[6]"
set_location_assignment PIN_AB26  -to "SW[7]"
set_location_assignment PIN_AC25  -to "SW[8]"
set_location_assignment PIN_AB25  -to "SW[9]"
set_location_assignment PIN_AC24  -to "SW[10]"
set_location_assignment PIN_AB24  -to "SW[11]"
set_location_assignment PIN_AB23  -to "SW[12]"
set_location_assignment PIN_AA24  -to "SW[13]"
set_location_assignment PIN_AA23  -to "SW[14]"
set_location_assignment PIN_AA22  -to "SW[15]"
set_location_assignment PIN_Y24   -to "SW[16]"
set_location_assignment PIN_Y23   -to "SW[17]"

# VGA (ADV7123 DAC)
set_location_assignment PIN_E12  -to "VGA_R[0]"
set_location_assignment PIN_E11  -to "VGA_R[1]"
set_location_assignment PIN_D10  -to "VGA_R[2]"
set_location_assignment PIN_F12  -to "VGA_R[3]"
set_location_assignment PIN_G10  -to "VGA_R[4]"
set_location_assignment PIN_J12  -to "VGA_R[5]"
set_location_assignment PIN_H8   -to "VGA_R[6]"
set_location_assignment PIN_H10  -to "VGA_R[7]"
set_location_assignment PIN_G11  -to "VGA_R[8]"
set_location_assignment PIN_G12  -to "VGA_R[9]"

set_location_assignment PIN_J13  -to "VGA_G[0]"
set_location_assignment PIN_J14  -to "VGA_G[1]"
set_location_assignment PIN_F13  -to "VGA_G[2]"
set_location_assignment PIN_F14  -to "VGA_G[3]"
set_location_assignment PIN_H13  -to "VGA_G[4]"
set_location_assignment PIN_H14  -to "VGA_G[5]"
set_location_assignment PIN_F15  -to "VGA_G[6]"
set_location_assignment PIN_E15  -to "VGA_G[7]"
set_location_assignment PIN_B12  -to "VGA_G[8]"
set_location_assignment PIN_C12  -to "VGA_G[9]"

set_location_assignment PIN_B13  -to "VGA_B[0]"
set_location_assignment PIN_G13  -to "VGA_B[1]"
set_location_assignment PIN_H12  -to "VGA_B[2]"
set_location_assignment PIN_F11  -to "VGA_B[3]"
set_location_assignment PIN_E10  -to "VGA_B[4]"
set_location_assignment PIN_F10  -to "VGA_B[5]"
set_location_assignment PIN_J10  -to "VGA_B[6]"
set_location_assignment PIN_J11  -to "VGA_B[7]"
set_location_assignment PIN_C13  -to "VGA_B[8]"
set_location_assignment PIN_B14  -to "VGA_B[9]"

set_location_assignment PIN_AA13 -to VGA_HS
set_location_assignment PIN_AA12 -to VGA_VS
set_location_assignment PIN_AA14 -to VGA_CLK
set_location_assignment PIN_AB13 -to VGA_BLANK_N
set_location_assignment PIN_AC14 -to VGA_SYNC_N

# PS/2 Keyboard
set_location_assignment PIN_G6   -to PS2_CLK
set_location_assignment PIN_H5   -to PS2_DAT

# LCD (4-bit mode, upper nibble)
set_location_assignment PIN_M1   -to LCD_RS
set_location_assignment PIN_M2   -to LCD_RW
set_location_assignment PIN_L4   -to LCD_EN
set_location_assignment PIN_L1   -to "LCD_DATA[4]"
set_location_assignment PIN_M4   -to "LCD_DATA[5]"
set_location_assignment PIN_M3   -to "LCD_DATA[6]"
set_location_assignment PIN_M5   -to "LCD_DATA[7]"

# 7-Segment Displays (active LOW)
# HEX0
set_location_assignment PIN_G18  -to "HEX0[0]"
set_location_assignment PIN_F22  -to "HEX0[1]"
set_location_assignment PIN_E17  -to "HEX0[2]"
set_location_assignment PIN_L26  -to "HEX0[3]"
set_location_assignment PIN_L25  -to "HEX0[4]"
set_location_assignment PIN_J22  -to "HEX0[5]"
set_location_assignment PIN_H22  -to "HEX0[6]"
# HEX1
set_location_assignment PIN_M24  -to "HEX1[0]"
set_location_assignment PIN_Y22  -to "HEX1[1]"
set_location_assignment PIN_W21  -to "HEX1[2]"
set_location_assignment PIN_W22  -to "HEX1[3]"
set_location_assignment PIN_W25  -to "HEX1[4]"
set_location_assignment PIN_U23  -to "HEX1[5]"
set_location_assignment PIN_U24  -to "HEX1[6]"
# HEX2
set_location_assignment PIN_AA25 -to "HEX2[0]"
set_location_assignment PIN_AA26 -to "HEX2[1]"
set_location_assignment PIN_Y25  -to "HEX2[2]"
set_location_assignment PIN_W26  -to "HEX2[3]"
set_location_assignment PIN_Y26  -to "HEX2[4]"
set_location_assignment PIN_W27  -to "HEX2[5]"
set_location_assignment PIN_W28  -to "HEX2[6]"
# HEX3
set_location_assignment PIN_V21  -to "HEX3[0]"
set_location_assignment PIN_U21  -to "HEX3[1]"
set_location_assignment PIN_AB20 -to "HEX3[2]"
set_location_assignment PIN_AA21 -to "HEX3[3]"
set_location_assignment PIN_AD24 -to "HEX3[4]"
set_location_assignment PIN_AF23 -to "HEX3[5]"
set_location_assignment PIN_Y19  -to "HEX3[6]"
# HEX4
set_location_assignment PIN_AB19 -to "HEX4[0]"
set_location_assignment PIN_AA19 -to "HEX4[1]"
set_location_assignment PIN_AG21 -to "HEX4[2]"
set_location_assignment PIN_AH21 -to "HEX4[3]"
set_location_assignment PIN_AE19 -to "HEX4[4]"
set_location_assignment PIN_AF19 -to "HEX4[5]"
set_location_assignment PIN_AE18 -to "HEX4[6]"
# HEX5
set_location_assignment PIN_AD18 -to "HEX5[0]"
set_location_assignment PIN_AC18 -to "HEX5[1]"
set_location_assignment PIN_AB18 -to "HEX5[2]"
set_location_assignment PIN_AH19 -to "HEX5[3]"
set_location_assignment PIN_AG19 -to "HEX5[4]"
set_location_assignment PIN_AF18 -to "HEX5[5]"
set_location_assignment PIN_AH18 -to "HEX5[6]"
# HEX6
set_location_assignment PIN_AA17 -to "HEX6[0]"
set_location_assignment PIN_AB16 -to "HEX6[1]"
set_location_assignment PIN_AA16 -to "HEX6[2]"
set_location_assignment PIN_AB17 -to "HEX6[3]"
set_location_assignment PIN_AB15 -to "HEX6[4]"
set_location_assignment PIN_AA15 -to "HEX6[5]"
set_location_assignment PIN_AC17 -to "HEX6[6]"
# HEX7
set_location_assignment PIN_AD17 -to "HEX7[0]"
set_location_assignment PIN_AE17 -to "HEX7[1]"
set_location_assignment PIN_AG17 -to "HEX7[2]"
set_location_assignment PIN_AH17 -to "HEX7[3]"
set_location_assignment PIN_AF17 -to "HEX7[4]"
set_location_assignment PIN_AG18 -to "HEX7[5]"
set_location_assignment PIN_AA14 -to "HEX7[6]"

# I/O voltage standard
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_R[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_G[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_B[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_HS
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_VS
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_CLK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_BLANK_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_SYNC_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to PS2_CLK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to PS2_DAT
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LCD_*
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX*
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY[*]

# Weak pull-ups on PS/2 lines (open-collector bus)
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to PS2_CLK
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to PS2_DAT

# Target device
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE115F29C7

puts "Pin assignments applied successfully."
