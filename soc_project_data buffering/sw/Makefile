# ==============================================================================
# Makefile : Bare-metal C test build for RISC-V VeeR EL2 SoC
# ==============================================================================

CROSS_COMPILE ?= riscv-none-elf-
CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
OBJDUMP := $(CROSS_COMPILE)objdump

ARCH_FLAGS := -march=rv32imc_zicsr -mabi=ilp32
CFLAGS     := $(ARCH_FLAGS) -O2 -g -Wall -nostdlib -nostartfiles -ffreestanding
LDFLAGS    := -T link.ld -nostdlib

TARGET := main

all: $(TARGET).elf $(TARGET).dump $(TARGET).hex $(TARGET).bin $(TARGET)_words.hex

$(TARGET).elf: startup.s main.c link.ld soc_regs.h
	@which $(CC) > /dev/null 2>&1 || { \
		echo "[ERROR] RISC-V GCC cross-compiler ($(CC)) not found in PATH."; \
		echo "[INFO] Install riscv-none-elf-gcc to compile this bare-metal firmware."; \
		exit 1; \
	}
	$(CC) $(CFLAGS) $(LDFLAGS) startup.s main.c -o $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -D -S $< > $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET)_words.hex: $(TARGET).bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).dump $(TARGET).hex $(TARGET).bin $(TARGET)_words.hex
