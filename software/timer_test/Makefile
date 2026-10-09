# Potato Processor - Timer IRQ Test Makefile

.PHONY: all clean
include ../common.mk

TARGET_LDFLAGS += -Wl,-T../bootloader/bootloader.ld -Wl,--Map,timer_test.map

OBJECTS := main.o start.o

all: timer_test.elf timer_test.bin

timer_test.elf: $(OBJECTS)
	$(TARGET_LD) -o $@ $(TARGET_LDFLAGS) $(OBJECTS)
	$(TARGET_SIZE) $@

timer_test.bin: timer_test.elf
	$(TARGET_OBJCOPY) -j .text -j .data -j .rodata -O binary $< $@

clean:
	-$(RM) $(OBJECTS)
	-$(RM) timer_test.elf timer_test.bin timer_test.coe timer_test.hex timer_test.map

main.o: main.c ../../potato.h
	$(TARGET_CC) -c -o $@ $(TARGET_CFLAGS) $<

start.o: ../start.S
	$(TARGET_CC) -DCOPY_DATA_TO_RAM -c -o $@ $(TARGET_CFLAGS) $<