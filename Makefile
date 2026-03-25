# --- Nombres de los ejecutables ---
QUARTUS_MAP = quartus_map
QUARTUS_FIT = quartus_fit
QUARTUS_ASM = quartus_asm
QUARTUS_PGM = quartus_pgm

# --- Configuración ---
# Aquí defines el nombre una sola vez
PROJECT_NAME = top_level

# --- Comandos ---
compile:
	$(QUARTUS_MAP) $(PROJECT_NAME)
	$(QUARTUS_FIT) $(PROJECT_NAME)
	$(QUARTUS_ASM) $(PROJECT_NAME)

flash:
	$(QUARTUS_PGM) -m jtag -o "p;output_files/$(PROJECT_NAME).sof"