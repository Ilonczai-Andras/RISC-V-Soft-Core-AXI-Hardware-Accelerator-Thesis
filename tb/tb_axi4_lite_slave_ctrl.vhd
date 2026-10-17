 library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axi4_lite_slave_ctrl is
end entity tb_axi4_lite_slave_ctrl;

architecture sim of tb_axi4_lite_slave_ctrl is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz órajel

    -- Globális jelek
    signal s_axi_aclk    : std_logic := '0';
    signal s_axi_aresetn : std_logic := '0';

    -- Read Address Channel
    signal s_axi_araddr  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;

    -- Read Data Channel
    signal s_axi_rdata   : std_logic_vector(31 downto 0);
    signal s_axi_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_rvalid  : std_logic;
    signal s_axi_rready  : std_logic := '0';

    -- Write Address Channel
    signal s_axi_awaddr  : std_logic_vector(7 downto 0) := (others => '0');
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;

    -- Write Data Channel
    signal s_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axi_wstrb   : std_logic_vector(3 downto 0)  := "1111";
    signal s_axi_wvalid  : std_logic := '0';
    signal s_axi_wready  : std_logic;

    -- Write Response Channel
    signal s_axi_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bvalid  : std_logic;
    signal s_axi_bready  : std_logic := '0';

    -- Gyorsító oldal jelei
    signal accel_start_out  : std_logic;
    signal accel_reset_out  : std_logic;
    signal accel_dim_out    : std_logic_vector(7 downto 0);
    signal accel_busy_in    : std_logic := '0';
    signal accel_done_in    : std_logic := '0';
    signal accel_err_ovf_in : std_logic := '0';
    signal accel_cycles_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal irq_out          : std_logic;

    signal read_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal sim_done         : boolean := false;

begin

    -- Órajel generálás (50 MHz)
    clk_proc : process
    begin
        while not sim_done loop
            s_axi_aclk <= '0';
            wait for CLK_PERIOD / 2;
            s_axi_aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Tesztelendő modul (DUT) példányosítása
    dut : entity work.axi4_lite_slave_ctrl
        port map (
            s_axi_aclk       => s_axi_aclk,
            s_axi_aresetn    => s_axi_aresetn,
            s_axi_araddr     => s_axi_araddr,
            s_axi_arvalid    => s_axi_arvalid,
            s_axi_arready    => s_axi_arready,
            s_axi_rdata      => s_axi_rdata,
            s_axi_rresp      => s_axi_rresp,
            s_axi_rvalid     => s_axi_rvalid,
            s_axi_rready     => s_axi_rready,
            s_axi_awaddr     => s_axi_awaddr,
            s_axi_awvalid    => s_axi_awvalid,
            s_axi_awready    => s_axi_awready,
            s_axi_wdata      => s_axi_wdata,
            s_axi_wstrb      => s_axi_wstrb,
            s_axi_wvalid     => s_axi_wvalid,
            s_axi_wready     => s_axi_wready,
            s_axi_bresp      => s_axi_bresp,
            s_axi_bvalid     => s_axi_bvalid,
            s_axi_bready     => s_axi_bready,
            accel_start_out  => accel_start_out,
            accel_reset_out  => accel_reset_out,
            accel_dim_out    => accel_dim_out,
            accel_busy_in    => accel_busy_in,
            accel_done_in    => accel_done_in,
            accel_err_ovf_in => accel_err_ovf_in,
            accel_cycles_in  => accel_cycles_in,
            irq_out          => irq_out
        );

    -- Stimulus és önellenőrző folyamat
    stim_proc : process

        -- Segédeljárás AXI4-Lite íráshoz
        procedure axi_write(
            constant addr : in std_logic_vector(7 downto 0);
            constant data : in std_logic_vector(31 downto 0)
        ) is
        begin
            wait until rising_edge(s_axi_aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= '1';
            s_axi_wdata   <= data;
            s_axi_wstrb   <= "1111";
            s_axi_wvalid  <= '1';
            s_axi_bready  <= '1';

            -- Várakozás az AW és W kézfogásra
            wait until rising_edge(s_axi_aclk) and s_axi_awready = '1' and s_axi_wready = '1';
            s_axi_awvalid <= '0';
            s_axi_wvalid  <= '0';

            -- Várakozás a BVALID válaszra
            if s_axi_bvalid = '0' then
                wait until rising_edge(s_axi_aclk) and s_axi_bvalid = '1';
            end if;
            assert s_axi_bresp = "00"
                report "HIBA: AXI Write BRESP nem OKAY (00)!" severity failure;

            wait until rising_edge(s_axi_aclk);
            s_axi_bready <= '0';
        end procedure;

        -- Segédeljárás AXI4-Lite olvasáshoz
        procedure axi_read(
            constant addr : in  std_logic_vector(7 downto 0);
            signal   data : out std_logic_vector(31 downto 0)
        ) is
        begin
            wait until rising_edge(s_axi_aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= '1';
            s_axi_rready  <= '1';

            -- Várakozás az ARREADY kézfogásra
            wait until rising_edge(s_axi_aclk) and s_axi_arready = '1';
            s_axi_arvalid <= '0';

            -- Várakozás az RVALID adatra
            if s_axi_rvalid = '0' then
                wait until rising_edge(s_axi_aclk) and s_axi_rvalid = '1';
            end if;
            data <= s_axi_rdata;
            assert s_axi_rresp = "00"
                report "HIBA: AXI Read RRESP nem OKAY (00)!" severity failure;

            wait until rising_edge(s_axi_aclk);
            s_axi_rready <= '0';
        end procedure;

    begin
        -- 1. TESZT: Reset állapot ellenőrzése
        s_axi_aresetn <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(s_axi_aclk);
        s_axi_aresetn <= '1';
        wait for CLK_PERIOD * 2;

        axi_read(x"08", read_data);
        assert read_data = x"00000004"
            report "1. TESZT HIBA: ACCEL_DIM reset erteke nem 4!" severity failure;
        assert accel_dim_out = x"04"
            report "1. TESZT HIBA: accel_dim_out nem 0x04!" severity failure;
        report "1. TESZT OK: Reset utani alapertelmezett ACCEL_DIM = 4." severity note;

        -- 2. TESZT: ACCEL_DIM (0x08) írása (N = 8) és visszaolvasása
        axi_write(x"08", x"00000008");
        axi_read(x"08", read_data);
        assert read_data = x"00000008"
            report "2. TESZT HIBA: ACCEL_DIM visszaolvasott ertek hibas!" severity failure;
        assert accel_dim_out = x"08"
            report "2. TESZT HIBA: accel_dim_out nem frissult 0x08-ra!" severity failure;
        report "2. TESZT OK: ACCEL_DIM iras es visszaolvasas (N=8) sikeres." severity note;

        -- 3. TESZT: ACCEL_CR (0x00) írása (START = 1, IE = 1 -> 0x00000005) és auto-clear ellenőrzése
        wait until rising_edge(s_axi_aclk);
        s_axi_awaddr  <= x"00";
        s_axi_awvalid <= '1';
        s_axi_wdata   <= x"00000005"; -- bit 0 (START) = 1, bit 2 (IE) = 1
        s_axi_wstrb   <= "1111";
        s_axi_wvalid  <= '1';
        s_axi_bready  <= '1';

        -- Megvárjuk, amíg a Slave felhúzza az AWREADY és WREADY jeleket (T2 órajel után):
        wait until s_axi_awready = '1' and s_axi_wready = '1';
        wait for 1 ns;
        -- Ebben az órajelciklusban az accel_start_out-nak '1'-nek kell lennie:
        assert accel_start_out = '1'
            report "3. TESZT HIBA: accel_start_out nem ugrott 1-be!" severity failure;

        -- A kézfogás órajel-felfutóéle (T3): itt veszi át a Master a nyugtát,
        -- és a Slave-ben UGYANEKKOR törlődik automatikusan 0-ba a START bit!
        wait until rising_edge(s_axi_aclk);
        s_axi_awvalid <= '0';
        s_axi_wvalid  <= '0';
        s_axi_bready  <= '0';
        wait for 1 ns;
        assert accel_start_out = '0'
            report "3. TESZT HIBA: accel_start_out nem torlodott automatikusan 1 orajel utan!" severity failure;

        -- Visszaolvasva a CR regisztert csak az IE bit (0x04) maradhat 1-ben:
        axi_read(x"00", read_data);
        assert read_data = x"00000004"
            report "3. TESZT HIBA: ACCEL_CR-ben az IE bit nem maradt 1, vagy a START nem torlodott!" severity failure;
        report "3. TESZT OK: START impulzus (1 orajel auto-clear) es IE bit mukodese helyes." severity note;

        -- 4. TESZT: Gyorsító működés szimulálása (BUSY, CYCLES, DONE és IRQ)
        accel_busy_in   <= '1';
        accel_cycles_in <= x"000001A4"; -- 420 órajelciklus
        axi_read(x"04", read_data);
        assert read_data = x"00000001"
            report "4. TESZT HIBA: ACCEL_SR BUSY bit nem 1!" severity failure;

        -- Gyorsító végez: 1 órajeles DONE impulzus
        wait until rising_edge(s_axi_aclk);
        accel_busy_in <= '0';
        accel_done_in <= '1';
        wait until rising_edge(s_axi_aclk);
        accel_done_in <= '0';
        wait for 1 ns;

        -- DONE flag-nek és az IRQ kimenetnek 1-ben kell maradnia (mert IE=1)
        assert irq_out = '1'
            report "4. TESZT HIBA: irq_out nem aktiválódott DONE utan!" severity failure;

        axi_read(x"04", read_data);
        assert read_data = x"00000002"
            report "4. TESZT HIBA: ACCEL_SR DONE bit (bit 1) nem 1!" severity failure;

        axi_read(x"0C", read_data);
        assert read_data = x"000001A4"
            report "4. TESZT HIBA: ACCEL_CYCLES erteke nem 0x000001A4!" severity failure;
        report "4. TESZT OK: ACCEL_SR (BUSY/DONE), ACCEL_CYCLES es irq_out mukodese helyes." severity note;

        -- 5. TESZT: Új START kiadásával a DONE flag és az IRQ törlődik
        axi_write(x"00", x"00000005"); -- Új START
        wait until rising_edge(s_axi_aclk);
        wait for 1 ns;
        assert irq_out = '0'
            report "5. TESZT HIBA: Uj START utan a done_flag / irq_out nem torlodott!" severity failure;
        report "5. TESZT OK: Uj START hatasara a DONE flag es az IRQ torlodott." severity note;

        report "=========================================================" severity note;
        report "MINDEN AXI4-LITE SLAVE TESZT SIKERESEN LEFUTOTT (PASS)!" severity note;
        report "=========================================================" severity note;

        sim_done <= true;
        wait;
    end process;

end architecture sim;