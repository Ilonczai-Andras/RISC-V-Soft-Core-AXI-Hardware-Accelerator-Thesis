# Fejlesztési Napló és Sprint Eredmények
## RISC-V Soft-Core + AXI Hardveres Gyorsító Diplomamunka

Ez a dokumentum a projekt lépésről lépésre történő fejlesztési történetét, a sprintek eredményeit, a technikai beállításokat és az elhárított hibákat rögzíti, hogy a projektbe bárki (konzulens, bíráló vagy új fejlesztő) azonnal és zökkenőmentesen be tudjon kapcsolódni.

---

## Tartalomjegyzék
1. [Sprint 0 – Rendszerterv és Specifikáció](#sprint-0--rendszerterv-és-specifikáció)
2. [Sprint 1 – Fejlesztői Környezet, Toolchain és Vivado Bring-up](#sprint-1--fejlesztői-környezet-toolchain-és-vivado-bring-up)
3. [Sprint 2 – Szimulációs Bring-up és Bare-metal Szoftver (Következő lépés)](#sprint-2--szimulációs-bring-up-és-bare-metal-szoftver)

---

## Sprint 0 – Rendszerterv és Specifikáció
*Időszak: 2026. október · Státusz: ✅ KÉSZ ÉS LEZÁRVA*

### 1. Célkitűzés
A diplomamunka pontos matematikai, funkcionális és hardveres specifikációjának rögzítése a tényleges kódolás előtt.

### 2. Meghozott architekturális döntések
- **Célplatform:** Xilinx Artix-7 FPGA család (`xc7a35tcsg324-1`, pl. Digilent Basys 3 / Arty A7 / Nexys A7).
- **Fejlesztőkörnyezet:** AMD / Xilinx Vivado ML Standard 2023.2 (ingyenes licenc).
- **Processzormag:** Potato RV32I nyílt forráskódú, tiszta VHDL mag (5 fokozatú futószalag, Wishbone busz).
- **Gyorsító felépítése:**
  - Fixpontos mátrixszorzó ($C = A \times B$, ahol $N \in \{4, 8, 16\}$).
  - Számábrázolás: **Q8.8 fixpontos** (16 bit: 1 előjel, 7 egész, 8 tört).
  - Túlcsordulásvédelem: **40 bites belső akkumulátor**, telítéses kerekítéssel.
- **Buszhálózat:**
  - Wishbone Master (CPU) $\rightarrow$ Wishbone $\leftrightarrow$ AXI4-Lite híd $\rightarrow$ Gyorsító vezérlőregiszterek (`0xC000_6000`).
  - Adatátvitel: AXI4-Stream TX/RX adatút memóriába képezett FIFO-val (`0xC000_7000`).
  - Megszakítás: A gyorsító `Done` jele a processzor **IRQ 5** vonalára van kötve.

### 3. Elkészült dokumentumok és anyagok
- Részletes specifikáció: [`docs/Rendszerterv_es_Specifikacio.md`](Rendszerterv_es_Specifikacio.md)
- Fejlesztési ütemterv: [`docs/Fejlesztési_terv.md`](Fejlesztési_terv.md)
- Rendszer blokkvázlat: [`docs/images/soc_blokkdiagram.png`](images/soc_blokkdiagram.png)

---

## Sprint 1 – Fejlesztői Környezet, Toolchain és Vivado Bring-up
*Időszak: 2026. október · Státusz: ✅ KÉSZ ÉS LEZÁRVA*

### 1. Célkitűzés
A teljes Windows-alapú fejlesztői lánc (RISC-V cross-compiler, szimulátor, szintézis környezet) felállítása, a referencia SoC Vivado projektjének létrehozása és a szimuláció sikeres lefuttatása.

### 2. Telepített és beállított eszközök
1. **RISC-V GCC Cross-Compiler:**
   - Csomag: `xPack GNU RISC-V Embedded GCC 13.2.0-2` (Windows 64-bit).
   - Telepítési hely: `D:\tools\riscv-gcc\xpack-riscv-none-elf-gcc-13.2.0-2\bin`
   - Parancs: `riscv-none-elf-gcc` (PATH-hoz adva).
2. **Build segédeszköz:** `GNU Make 3.81` (`C:\Program Files (x86)\GnuWin32\bin\make.exe`).
3. **Hardvertervező (EDA):** `AMD Vivado ML Standard 2023.2` (`C:\Xilinx\Vivado\2023.2`).
4. **Alap kódbázis:** Potato processzor klónozva a `vendor/potato/` könyvtárba.

### 3. Szoftveres fordítási teszt
Lefordítottuk a `vendor/potato/software/hello` mintaprogramot a cross-compilerrel:
```powershell
make -C vendor/potato/software/hello TARGET_PREFIX=riscv-none-elf
```
Eredmény: A `hello.elf` és `hello.bin` hiba nélkül legenerálódott (méret: 434 bájt text szekció).

### 4. A Vivado 2023.2 projekt összeállítása
- **Projekt helye:** `vivado_project/potato_soc_thesis/`
- **Céleszköz:** `xc7a35tcsg324-1`
- **Hozzáadott források:**
  - `vendor/potato/src/*.vhd` (CPU mag, ALU, CSR, dekóder, register file)
  - `vendor/potato/soc/*.vhd` (UART, Timer, GPIO, Interconnect, RAM)
  - `vendor/potato/example/toplevel.vhd` (Top-level modul)
  - `vendor/potato/example/aee_rom_wrapper.vhd` (Boot ROM illesztő)
  - `vendor/potato/example/arty.xdc` (Fizikai kényszerek)
  - `vendor/potato/example/tb_toplevel.vhd` (Szimulációs testbench)
- **Generált Xilinx IP-k (IP Catalog):**
  - **`clock_generator` (Clocking Wizard):** 100 MHz bejövő órajelből 50 MHz-es `system_clk` előállítása, aktív alacsony reset (`resetn`) és PLL `locked` jellel.
  - **`aee_rom` (Block Memory Generator):** 32 bites, 4096 szavas (16 KB) Single-Port ROM a boot kód számára.

### 5. Megoldott technikai problémák és hibaelhárítás (Troubleshooting)
A projekt felépítése során három kritikus illesztési hibát azonosítottunk és hárítottunk el:

1. **Hiányzó ROM wrapper:**
   - *Tünet:* A `toplevel` alatt az `aee_rom` kérdőjellel (`?`) jelent meg.
   - *Ok:* Az `example/aee_rom_wrapper.vhd` fájl nem került be a projektbe, ami a híd a toplevel és az IP között.
   - *Megoldás:* A fájl hozzáadása a Design Sources forrásokhoz.
2. **Block Memory Generator `ena` láb eltérés:**
   - *Hibaüzenet:* `ERROR: [VRFC 10-3353] formal port 'ena' has no actual or default value`.
   - *Ok:* A Vivado 2023.2 alapértelmezésben generál egy `ena` engedélyező lábat a ROM-ra, amit a 2016-os Potato wrapper nem kötött be.
   - *Megoldás:* Az `aee_rom` IP testreszabásánál a *Port A Options* fülön az *Enable Port Type* átállítása **`Always Enabled`**-re.
3. **Clocking Wizard bemeneti portnév eltérés:**
   - *Hibaüzenet:* `ERROR: [VRFC 10-719] formal port/generic <clk> is not declared in <clock_generator>`.
   - *Ok:* A Clocking Wizard a bemenetet `clk_in1`-nek nevezi el, miközben a `toplevel.vhd` 295. sora `clk => clk`-t várt.
   - *Megoldás:* A `toplevel.vhd` 295. sorában a port hozzárendelés átírása: **`clk_in1 => clk`**.

### 6. Verifikáció és szimuláció
A javítások után elindítottuk a viselkedési szimulációt (*Run Behavioral Simulation*). A Vivado XSIM fordítója (`xvhdl`) és elaborátora (`xelab`) hiba nélkül lefutott, és sikeresen megnyílt a hullámforma ablak (`xsim`), befejezve a hardveres bring-up első fázisát.

### 7. Git konfiguráció
Létrehoztuk a projekt gyökerében a [`.gitignore`](../.gitignore) fájlt, amely kiszűri a gigabájtos ideiglenes Vivado futási mappákat (`*.runs/`, `*.sim/`, `*.cache/`, `*.hw/`), és tiszta forrásállapotot tart a repóban.

---

## Sprint 2 – Szimulációs Bring-up és Bare-metal Szoftver
*Státusz: ⏳ KÖVETKEZŐ LÉPÉS*
- [ ] A lefordított `hello` program `.coe` formátumba alakítása és betöltése a ROM-ba (`aee_rom`).
- [ ] Virtuális UART monitor megírása a `tb_toplevel.vhd` testbench-be (karakterek kiírása a Vivado konzolra).
- [ ] Szimulációs futtatás és „Hello world” ellenőrzése a Tcl konzolon.
- [ ] Első szintézis teszt (Run Synthesis) Artix-7-re az erőforrások (LUT, FF, BRAM) ellenőrzésére.
