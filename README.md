# EC1 Exam 4 – VGA + PS/2 + LCD System on DE2-115
## How to Build and Program

### Files in this project

| File | Description |
|------|-------------|
| `top_level.vhd` | Top-level entity; integrates all modules |
| `vga_controller.vhd` | VGA sync generator (640x480, 800x600, 1024x768) |
| `pll_pixel_clk.vhd` | Pixel clock generator (PLL wrapper) |
| `ps2_keyboard.vhd` | PS/2 keyboard interface (scan code decoder) |
| `lcd_controller.vhd` | HD44780 LCD driver (4-bit mode) |
| `image_rom.vhd` | Image storage ROM (placeholder — replace with real image) |
| `seg7_decoder.vhd` | Hex-to-7-segment decoder |
| `de2_115_pins.tcl` | Quartus pin assignment script |

---

### Step 1 — Create a Quartus Prime Project

1. Open Quartus Prime → New Project Wizard
2. Device: **Cyclone IV E, EP4CE115F29C7**
3. Add all `.vhd` files to the project
4. Set **top_level** as the top-level entity

---

### Step 2 — Generate the PLL (CRITICAL)

The `pll_pixel_clk.vhd` contains a software approximation for educational purposes.
For real hardware you **must** replace it with an Altera ALTPLL:

1. IP Catalog → Basic Functions → Clocks → ALTPLL
2. Input clock: **50 MHz**
3. Configure outputs:
   - c0 = **25.000 MHz** → for 640×480@60Hz
   - c1 = **40.000 MHz** → for 800×600@60Hz
   - c2 = **65.000 MHz** → for 1024×768@60Hz
4. Modify `pll_pixel_clk.vhd` to instantiate your generated PLL and mux c0/c1/c2 based on `mode`

---

### Step 3 — Add Your Team Picture

1. Prepare a JPEG/PNG of your team members
2. Run the Python script (documented inside `image_rom.vhd`) to convert it to a `.mif` file at **640×480** resolution
3. In `image_rom.vhd`, replace the stripe pattern with an `altsyncram` ROM instance initialized from your `.mif`
4. For other resolutions (800x600, 1024x768), scale the address mapping accordingly

---

### Step 4 — Apply Pin Assignments

1. In Quartus: Tools → Tcl Scripts → Run → select `de2_115_pins.tcl`
   OR open the Tcl console and type: `source de2_115_pins.tcl`

---

### Step 5 — Compile and Program

1. Processing → Start Compilation
2. Programmer → Auto Detect → Load .sof file → Start

---

### Operation

| Switch | Effect |
|--------|--------|
| SW[0] only ON | 1024×768 @ 60Hz |
| SW[1] only ON | 800×600 @ 60Hz |
| SW[2] ON | 640×480 @ 60Hz (highest priority) |
| KEY[0] | Reset (active LOW) |

| Key | Action |
|-----|--------|
| **P** release | Show team picture on screen |
| **B** release | Set screen to black |

- **HEX1:HEX0** display the scan code of the last key pressed (hex)
- **LCD Line 1**: "  VGA DISPLAY   "
- **LCD Line 2**: "Picture " or "Black   " depending on last action

---

### PS/2 Scan Codes (Set 2)

| Key | Make code | Break code |
|-----|-----------|------------|
| P   | 0x4D      | F0 4D      |
| B   | 0x32      | F0 32      |

---

### Notes

- The LCD uses **4-bit mode** (only LCD_DATA[7:4] connected on DE2-115)
- VGA colors are 10-bit per channel (ADV7123); 8-bit values are padded with 2 LSB zeros
- Adjust the pixel clock frequencies using the PLL for accurate timing
