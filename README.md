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