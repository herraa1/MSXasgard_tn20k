.PHONY: all clean cleanbin

COL_WHITE = \e[1;37m
COL_RESET = \e[0m

DIRSRC = ./src
BINDIR = ./bin
DIROUT = ./out

BINASM = $(BINDIR)/asmsx -z -r

ROMSIZE  = 4096
ROMBIN   = ./slave_rom.bin
ROMHEX   = ./slave_rom.hex
ROMHEXHDL= ../slave_rom.hex
MENUMAIN = $(DIROUT)/main.z80

all: $(ROMBIN) $(ROMHEX)

# Compila main.asm (se copia a ./out para no ensuciar ./src; asMSX deja la
# salida junto al fuente). El fuente lleva .org #4000 y asMSX emite solo los
# bytes ensamblados desde ese origen, sin relleno previo, asi que el .z80 ya
# empieza en la cabecera "AB".
$(MENUMAIN): $(DIRSRC)/main.asm
	@echo "$(COL_WHITE)###### Compiling main.asm$(COL_RESET)"
	@cp $(DIRSRC)/main.asm $(DIROUT)/
	$(BINASM) $(DIROUT)/ $(DIROUT)/main.asm
	@rm -rf $(DIROUT)/~tmppre.*

# ROM del proxy rellenada con 00 hasta $(ROMSIZE) bytes: se parte de un bloque
# de ceros y se sobreescribe el binario compilado al principio (conv=notrunc
# mantiene el tamano). 4 KB = 0x4000-0x4FFF, justo por debajo de la ventana de
# intercambio en 0x5000, asi que ROM y registros no se solapan.
$(ROMBIN): $(MENUMAIN)
	@echo "$(COL_WHITE)###### Generating $(ROMBIN) ($(ROMSIZE) bytes, zero-padded)$(COL_RESET)"
	@head -c $(ROMSIZE) /dev/zero > $@
	@dd if=$(MENUMAIN) of=$@ bs=1 conv=notrunc 2>/dev/null
	@echo "       usados: `stat -c %s $(MENUMAIN)` / $(ROMSIZE) bytes"

# Version hex (un byte por linea) para el $readmemh del modulo slave_rom.v.
# Se deja una copia en src/ junto a bios_missing.hex, que es donde la sintesis
# de Gowin resuelve la ruta del $readmemh.
$(ROMHEX): $(ROMBIN)
	@echo "$(COL_WHITE)###### Generating $(ROMHEX)$(COL_RESET)"
	@xxd -p -c1 $(ROMBIN) > $@
	@cp $@ $(ROMHEXHDL)

cleanbin:
	@rm -rf $(ROMBIN) $(ROMHEX) $(ROMHEXHDL)

clean: cleanbin
	@rm -rf $(DIROUT)/*
