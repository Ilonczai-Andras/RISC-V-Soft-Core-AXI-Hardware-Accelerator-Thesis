# RISC-V Soft-Core + AXI Hardveres Gyorsító Diplomamunka

Nyílt forráskódú RISC-V soft-core processzor (Potato RV32I) integrálása Xilinx FPGA platformra, kiegészítve egy VHDL-ben megírt, egyedi AXI-alapú hardveres gyorsítóval (fixpontos mátrixszorzó).

## Fő komponensek
- **Fejlesztői környezet (EDA):** AMD / Xilinx Vivado ML Standard 2023.2 (`FPGAs_AdaptiveSoCs_Unified_2023.2_1013_2256_Win64`).
- **Célplatform:** Xilinx Artix-7 FPGA (pl. Basys 3, Nexys A7 vagy Arty A7 kártyák – ingyenes Vivado Standard/WebPACK licenc).
- **Processzormag:** RISC-V RV32I (Potato mag, Wishbone buszinterfész).
- **Buszinterfészek:** Wishbone ↔ AXI4-Lite híd, vezérlőregiszterek (AXI4-Lite), nagy sebességű adatátvitel (AXI4-Stream).
- **Hardveres gyorsító:** Fixpontos mátrixszorzó (MAC tömb, futószalagos architektúra).
- **Szoftver:** Bare-metal C tesztkörnyezet, driver és cikluspontos benchmark mérés.

## Dokumentáció
- **Fejlesztési napló és eredmények (Sprint Log):** [`docs/Sprint_Naplo.md`](docs/Sprint_Naplo.md)
- **Fejlesztési és sprint-terv:** [`docs/Fejlesztési_terv.md`](docs/Fejlesztési_terv.md)
- **Rendszerterv és részletes specifikáció:** [`docs/Rendszerterv_es_Specifikacio.md`](docs/Rendszerterv_es_Specifikacio.md)

---

## Gyorsindítás és Gyakori Parancsok (PowerShell / Windows)

### 1. Bare-metal RISC-V program fordítása ROM indításhoz (Standalone ROM)
Mivel a processzor közvetlenül a ROM-ból (`0xffff8000`) indul a reset után, a közvetlenül futtatandó programokat a `bootloader.ld` linker szkripttel fordítjuk:
```powershell
riscv-none-elf-gcc -c -o vendor/potato/software/hello/main_rom.o -march=rv32i_zicsr -Os -ffreestanding -fno-builtin -Ivendor/potato -Ivendor/potato/libsoc vendor/potato/software/hello/main.c
riscv-none-elf-gcc -DCOPY_DATA_TO_RAM -c -o vendor/potato/software/hello/start_rom.o -march=rv32i_zicsr -Os -ffreestanding -fno-builtin -Ivendor/potato -Ivendor/potato/libsoc vendor/potato/software/start.S
riscv-none-elf-gcc -o vendor/potato/software/hello/hello_rom.elf -march=rv32i_zicsr -nostartfiles "-Wl,-m,elf32lriscv" --specs=nosys.specs "-Wl,--no-relax" "-Wl,--gc-sections" "-Wl,-Tvendor/potato/software/bootloader/bootloader.ld" vendor/potato/software/hello/main_rom.o vendor/potato/software/hello/start_rom.o
riscv-none-elf-objcopy -j .text -j .data -j .rodata -O binary vendor/potato/software/hello/hello_rom.elf vendor/potato/software/hello/hello_rom.bin
python scripts/bin2hex.py vendor/potato/software/hello/hello_rom.bin vendor/potato/software/hello/hello_rom.hex vendor/potato/software/hello/hello_rom.coe
```

### 2. Szoftver tiszta újrafordítása (Clean)
```powershell
Remove-Item vendor/potato/software/hello/*.o, vendor/potato/software/hello/*.elf, vendor/potato/software/hello/*.bin, vendor/potato/software/hello/*.map, vendor/potato/software/hello/*.coe, vendor/potato/software/hello/*.hex -ErrorAction SilentlyContinue
```

### 4. Vivado projekt megnyitása
```powershell
& "C:\Xilinx\Vivado\2023.2\bin\vivado.bat" .\vivado_project\potato_soc_thesis\potato_soc_thesis.xpr
```