# Fejlesztési terv – RISC-V soft-core + AXI hardveres gyorsító

*Diplomamunka fejlesztési és sprint-terv · Xilinx FPGA platform · VHDL · Bare-metal C*

---

## 1. A feladat összefoglalása és célkitűzései

A diplomamunka célja egy nyílt forráskódú, VHDL-alapú RISC-V soft-core processzor integrálása Xilinx FPGA platformra, valamint egy egyedi tervezésű, VHDL-ben implementált AXI-alapú hardveres gyorsító megvalósítása és mérése.

### Fő feladatcsoportok:
1. **Soft-core processzor integráció:** Egy konfigurálható, 32 bites RV32I RISC-V mag (referencia: [Potato](https://github.com/skordal/potato)) adaptálása, integrálása SoC környezetbe megszakításkezeléssel és alapvető debug lehetőséggel.
2. **AXI buszinterfész tervezése VHDL-ben:**
   - Saját **AXI4-Lite slave** interfész a vezérlő- és állapotregiszterek (Control/Status) eléréséhez.
   - Saját **AXI4-Stream master és slave** interfészek a gyorsító és a rendszer (memória/CPU) közötti nagy sebességű adatátvitelhez.
   - Buszillesztés megvalósítása a processzor natív busza (Wishbone) és az AXI alrendszer között.
3. **Hardveres gyorsító modul:** Fixpontos mátrixszorzó tervezése és VHDL implementációja, futószalagosított (pipelined) vagy szisztolikus architektúrával a maximális átviteli sebesség és minimális latencia elérésére.
4. **Szoftveres környezet és validáció:** Bare-metal C programcsomag készítése a processzorra: hardveres inicializálás, adatmozgatás, számítás indítása, interrupt/polling kezelés, valamint automatikus verifikáció és cikluspontos benchmark mérés a szoftveres és a gyorsított futás összehasonlítására.

---

## 2. Rendszerarchitektúra és fejlesztési módszertan

### Buszarchitektúra: A Potato és az AXI ötvözése
A Potato mag natívan **Wishbone** buszinterfészt biztosít. Az AXI-alapú gyorsító illesztésére a következő döntési fa áll rendelkezésre:

* **A) Javasolt hibrid megközelítés (alacsony kockázat, tiszta moduláris felépítés):**
  * A SoC belső processzormagja és alapperifériái (UART, Timer) Wishbone buszon maradnak.
  * A gyorsító felé egy **Wishbone Master → AXI4-Lite Master hídon** keresztül valósul meg a vezérlés.
  * Az AXI4-Stream adatfolyam kétféleképpen oldható meg:
    * *Megközelítés A1 (Egyszerűbb):* Memóriatérképbe illesztett **AXI-Stream FIFO** (a CPU írja/olvassa a FIFO-t, ami Stream formátumra konvertál).
    * *Megközelítés A2 (Nagyobb átvitel / Professzionális):* Egy egyszerű VHDL **Stream DMA egység** megvalósítása, amely a rendszermemóriából közvetlenül streamel a gyorsítóba és vissza.
* **B) Teljes natív AXI áttérés:** Wishbone→AXI4 híd az egész SoC elé, ahol a memória és perifériák is AXI-n futnak (jelentősen magasabb verifikációs teher).
* **C) Alternatív VHDL mag (B-terv):** Amennyiben a Potato elavult toolchain- vagy CSR-problémákba ütközne, a szintén VHDL-alapú, aktívan karbantartott és natív AXI4-Lite támogatással rendelkező **NEORV32** magra való váltás.

### Fejlesztési stratégia: "Simulation-First" (Otthoni fejlesztés kártya nélkül)
Mivel a fejlesztés túlnyomó része otthon, fizikai FPGA hardver nélkül zajlik, és a valós hardverteszt csak a projekt végén (egyetemi laborban) történik, a fejlesztési folyamat a **szimuláció-vezérelt tervezésre** épül:

1. **Önellenőrző szimulációs testbenchek (Self-Checking Testbenches):**
   - Nem kézi hullámforma-ellenőrzésre támaszkodunk, hanem VHDL `assert` állításokkal és Python referenciamodellekkel összevetett automatikus tesztekre.
2. **Virtuális szoftverfuttatás a szimulátorban:**
   - A bare-metal C fordító kimenetét (`.elf` → `.bin` / `.mem`) a testbench közvetlenül betölti a szimulált BRAM-ba.
   - A virtuális UART TX jelet a tesztkörnyezet dekódolja, és a `printf` kimenet valós időben megjelenik a Vivado/GHDL szimulációs konzolján. Így a szoftver teljes funkcionalitása ellenőrizhető otthon is.
3. **Folyamatos szintézis és időzítés-ellenőrzés (Offline Implementation):**
   - Bár fizikai kártya nincs csatlakoztatva, a Vivado szintézis, elhelyezés és huzalozás (Place & Route), valamint a statikus időzítés-elemzés (Timing Analysis) **teljes értékűen lefuttatható otthon is** a kiválasztott FPGA célalkatrészre (part number).
   - Minden sprintben ellenőrizzük a Setup/Hold időzítést és az erőforrás-kihasználást, megelőzve a késői hardveres meglepetéseket.
4. **Célzott laboratóriumi hardverteszt (Fázis 4 végén):**
   - A laborba már egy 100%-ig szimulált, implementált és bitstreammel rendelkező projekt érkezik.
   - A hardveres hibakeresést előre beépített Xilinx ILA (Integrated Logic Analyzer) magok támogatják, minimalizálva a laborban töltött időt.

---

## 3. Részletes fázis- és sprint-terv (2 hetes sprintek)

> **Időzítési megjegyzés:**
> - **2 féléves modell (Témalabor + Diplomamunka, ~26–28 hét):** A teljes 13 sprint + puffer lépésről lépésre végrehajtható.
> - **1 féléves modell (~14 hét):** A sprintek összevonandók (1 hetes sprintek, vagy a szimulációk gyorsított párhuzamosítása).

### Fázis 0 – Specifikáció és alapozás (Sprint 0, 2 hét)
* **Cél:** Pontos matematikai és hardveres követelményrendszer felállítása a konzulenssel egyeztetve.
* **Feladatok:**
  * RISC-V privilégium-specifikáció (M-mode, trap/CSR logika) és ARM AMBA AXI4 (Lite & Stream) protokollok áttekintése.
  * Céleszköz és környezet rögzítése: Xilinx Artix-7 család (pl. XC7A35T vagy XC7A100T alkatrész / Basys 3, Nexys A7, Arty A7 kártyák). Hivatalosan rögzített fejlesztőkörnyezet: **AMD/Xilinx Vivado ML Standard 2023.2** (`FPGAs_AdaptiveSoCs_Unified_2023.2_1013_2256_Win64` Windows telepítőcsomag).
  * Gyorsító specifikáció: fixpontos formátum (pl. Q8.8 bemenet, 32 bites akkumulátor a túlcsordulás ellen), mátrixdimenziók ($4 \times 4$, $8 \times 8$).
* **Mérföldkő:** 2–3 oldalas rendszerterv blokkdiagrammal, memóriatérképpel és szimulációs teszttervvel.

---

### Fázis 1 – Soft-core processzor integráció és szimulációs bring-up

#### Sprint 1 (2 hét): Fejlesztői környezet és toolchain
* RISC-V GNU toolchain felállítása (`riscv-gnu-toolchain`, `--with-arch=rv32i --with-abi=ilp32`).
* Vivado 2023.2 projekt létrehozása a cél FPGA alkatrészre (Artix-7), Potato VHDL források integrálása.
* Szimulációs környezet felállítása (Vivado XSIM és/vagy GHDL nyílt forráskódú szimulátor a gyors regressziókhoz).
* **Mérföldkő:** A referencia SoC szimulációban fordul, az instrukció-memória inicializálható.

#### Sprint 2 (2 hét): Szimulációs SoC bring-up és virtuális UART
* A Potato referencia SoC (Wishbone, UART, Timer, GPIO) testbench felépítése.
* Bare-metal program: C kód fordítása, memória-kép (`.mem`) generálása.
* Virtuális UART monitor megírása VHDL testbench-ben (a konzolra írja a szimulált processzor karaktereit).
* Szintézis- és implementáció-futtatás otthon: ellenőrizni, hogy a mag tiszta és időzítés-helyes bitstreamet képez a célchipre.
* **Mérföldkő:** A „Hello World!” és a timer-megszakítás szimulációban lefut és kiíródik; a projekt hiba nélkül szintetizál a cél FPGA-ra.

#### Sprint 3 (2 hét): Megszakításkezelés és szimulációs debug
* A Potato megszakításvezérlőjének (max. 8 maszkolható IRQ) tesztelése szimulációban (Timer és külső események).
* C nyelvű trap/interrupt handler írása és nyugtázási mechanizmus ellenőrzése.
* Debug infrastruktúra: szoftveres szinten UART diagnosztika; hardveres szinten Xilinx ILA magok előkészítése a későbbi laboros méréshez.
* **Mérföldkő:** Stabil, szimulációban igazolt megszakításkezelés C szinten.

---

### Fázis 2 – AXI infrastruktúra tervezése VHDL-ben

#### Sprint 4 (2 hét): Saját AXI4-Lite Slave komponens
* Generikus VHDL AXI4-Lite slave modul megírása:
  * Cím-dekódolás és állapotgép az AW/W/B (írás) és AR/R (olvasás) csatornákhoz.
  * Belső regisztertár: Control (Start/Reset/IRQ-enable), Status (Busy/Done/Error), Mátrix méret-regiszterek.
* Önellenőrző (self-checking) testbench írása: véletlenszerű és határesetes tranzakciók, backpressure (késleltetett READY jelek) kezelése.
* **Mérföldkő:** AXI4-Lite slave izolált szimulációban 100%-os protokoll-helyességgel működik.

#### Sprint 5 (2 hét): Wishbone ↔ AXI4-Lite híd és szimulációs integráció
* Wishbone Master → AXI4-Lite Master konverter VHDL modul tervezése és testbench verifikációja.
* A híd és az AXI4-Lite slave beillesztése a SoC memóriatérképébe.
* C tesztprogram szimulációja: a szimulált RISC-V mag C utasításokkal írja és olvassa a dummy AXI regisztereket.
* Időzítési ellenőrzés (Timing Check) Vivadóban.
* **Mérföldkő:** A virtuális C program sikeresen konfigurálja a buszhídon keresztül az AXI regisztereket szimulációban.

#### Sprint 6 (3 hét): AXI4-Stream interfészek tervezése
* VHDL AXI4-Stream Slave (bemenet) és Master (kimenet) modulok implementálása (TVALID, TREADY, TDATA, TLAST).
* Belső szinkron FIFO pufferek beillesztése a sebességkülönbségek és backpressure kivédésére.
* Interfész összekapcsolás a rendszerrel (AXI-Stream FIFO vagy minimális DMA vezérlő).
* Loopback tesztbench szimuláció: streaming adatátvitel ellenőrzése terhelés és stall állapotok mellett.
* **Mérföldkő:** Az AXI-Stream adatút önálló szimulációban adatvesztés nélkül, maximális throughputtal közvetíti az adatokat.

---

### Fázis 3 – Hardveres gyorsító (Mátrixszorzó modul)

#### Sprint 7 (3 hét): Fixpontos mátrixszorzó architektúra és mag
* Fixpontos számábrázolás véglegesítése (pl. Q8.8 bemenet, 32 bites akkumulátor túlcsordulásvédelemmel).
* Python/NumPy referenciamodell felállítása az aritmetikai pontosság és kvantálási hiba kiértékelésére.
* MAC (Multiply-Accumulate) egységek és a futószalagos adatút (pipeline) VHDL megvalósítása.
* Golden-referenciás VHDL testbench: Python által generált bemeneti mátrixok és elvárt eredmények automatikus összevetése.
* **Mérföldkő:** A számítási mag önmagában szimulációban hiba nélkül elvégzi a mátrixszorzást a referencia-adatokkal.

#### Sprint 8 (2 hét): Gyorsító és AXI alrendszer integrációja
* A mátrixszorzó összekötése az AXI4-Lite vezérlőregiszterekkel és az AXI4-Stream FIFO-kkal.
* Pipeline buborékok és stall-helyzetek optimalizálása.
* End-to-end szimuláció: AXI tranzakciókon keresztül beadott mátrixok kiszámítása és eredmény kiolvasása.
* **Mérföldkő:** A teljes gyorsító IP blokk szimulációban AXI interfészeken keresztül stabilan számol.

---

### Fázis 4 – Rendszerintegráció, Szoftver és Laboratóriumi FPGA Teszt

#### Sprint 9 (2 hét): Teljes SoC integráció és offline Timing Closure
* Processzor + Wishbone/AXI híd + Gyorsító + Memória összekötése csúcsszinten (top-level VHDL).
* XDC kényszerek (órajel, pin-kiosztás a laboros kártya szerint) beállítása.
* Szintézis, implementáció és Timing Closure otthon: Setup/Hold slack pozitív, erőforrások (LUT, DSP, BRAM) határon belül.
* Vivado ILA magok beillesztése a kritikus buszvonalakra a hardveres hibakereséshez.
* **Mérföldkő:** A teljes rendszer hiba nélkül fordul, az implementáció zárt időzítéssel bitstreamet generál.

#### Sprint 10 (2 hét): Bare-metal szoftver és szimulációs önellenőrzés
* Moduláris C driver réteg készítése a gyorsítóhoz: inicializálás, adatok küldése, számítás indítása, interrupt kezelés.
* Tisztán szoftveres fixpontos mátrixszorzó algoritmus megírása C-ben.
* Automatikus önellenőrző bare-metal program lefutása szimulációban: a virtuális RISC-V mag ellenőrzi a HW gyorsító eredményét a SW referenciával szemben.
* **Mérföldkő:** A teljes szoftver-hardver lánc önállóan és hibátlanul validálja a számításokat a szimulációban.

#### Sprint 11 (2 hét): Laboratóriumi FPGA Bring-up és Benchmark mérés
* **Kiemelt fázis: valós hardverteszt a laborban!**
* Bitstream feltöltése a fizikai FPGA-ra, UART terminál csatlakoztatása PC-hez.
* Ha kommunikációs vagy időzítési hiba lép fel: ILA megfigyeléssel azonnali hardveres diagnosztika.
* Cikluspontos mérések végzése a hardveres timer segítségével valós hardveren:
  * Szoftveres vs. hardveresen gyorsított futási idő és Speedup mérése különböző méretekre ($2 \times 2$-től $16 \times 16$-ig).
  * Teljesítmény- és erőforrás-táblázatok rögzítése.
* **Mérföldkő:** Valós FPGA kártyán sikeresen futó rendszer, igazolt működés és mért benchmark adatsor.

---

### Fázis 5 – Zárás és dokumentáció

#### Sprint 12 (2 hét): Kódrendezés és dolgozatírás
* Forráskódok kommentezése, Doxygen / Markdown dokumentáció lezárása a git repóban.
* Mérési diagramok, oszlopgrafikonok és blokkarchitektúra-ábrák beillesztése a dolgozatba.
* A dolgozat hardveres, szoftveres és mérési fejezeteinek megírása.

#### Sprint 13 (2 hét, Puffer): Finiselés és demonstráció
* Tartalék idő a dolgozat lektorálására és konzulensi javításokra.
* Védési prezentáció és a laborban rögzített működési videó (vagy élő hardveres demó) előkészítése.
* **Mérföldkő:** Végleges, leadott diplomamunka és bemutatásra kész hardveres demó.