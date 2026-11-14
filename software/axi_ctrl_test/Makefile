# ==============================================================================
# Potato RISC-V SoC - AXI Hardware Accelerator Control Test Makefile
# Target: Application Execution Environment ROM (0xffff8000)
# ==============================================================================

TARGET_PREFIX ?= riscv-none-elf
TARGET_CC      := $(TARGET_PREFIX)-gcc
TARGET_LD      := $(TARGET_PREFIX)-gcc
TARGET_SIZE    := $(TARGET_PREFIX)-size
TARGET_OBJCOPY := $(TARGET_PREFIX)-objcopy
PYTHON         ?= python

# Relative paths to vendor Potato directory and build scripts
POTATO_DIR     := ../../vendor/potato
BOOTLOADER_LD  := $(POTATO_DIR)/software/bootloader/bootloader.ld
START_S        := $(POTATO_DIR)/software/start.S
BIN2HEX        := ../../scripts/bin2hex.py

TARGET_CFLAGS  := -march=rv32i_zicsr -Wall -Wextra -Os -fomit-frame-pointer \
					-ffreestanding -fno-builtin -std=gnu99 -ffunction-sections -fdata-sections \
					-I$(POTATO_DIR) -I$(POTATO_DIR)/libsoc

TARGET_LDFLAGS := -march=rv32i_zicsr -nostartfiles \
					-Wl,-m,elf32lriscv --specs=nosys.specs -Wl,--no-relax -Wl,--gc-sections \
					-Wl,-T$(BOOTLOADER_LD) -Wl,--Map,axi_ctrl_test.map

OBJECTS        := main.o start.o
PROG           := axi_ctrl_test

.PHONY: all clean

all: $(PROG).elf $(PROG).bin $(PROG).coe

$(PROG).elf: $(OBJECTS)
	$(TARGET_LD) -o $@ $(TARGET_LDFLAGS) $(OBJECTS)
	$(TARGET_SIZE) $@

$(PROG).bin: $(PROG).elf
	$(TARGET_OBJCOPY) -j .text -j .data -j .rodata -O binary $< $@

$(PROG).coe: $(PROG).bin
	$(PYTHON) $(BIN2HEX) $(PROG).bin $(PROG).hex $@

main.o: main.c
	$(TARGET_CC) -c -o $@ $(TARGET_CFLAGS) $<

start.o: $(START_S)
	$(TARGET_CC) -DCOPY_DATA_TO_RAM -c -o $@ $(TARGET_CFLAGS) $<

clean:
	-rm -f $(OBJECTS) $(PROG).elf $(PROG).bin $(PROG).coe $(PROG).hex $(PROG).map