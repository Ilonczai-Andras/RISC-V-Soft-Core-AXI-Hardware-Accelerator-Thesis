library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axi4_lite_slave_ctrl is
end entity tb_axi4_lite_slave_ctrl;

architecture sim of tb_axi4_lite_slave_ctrl is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz clock

    -- Global signals
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

    -- Hardware Accelerator Core Signals
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

    -- Clock Generation (50 MHz)
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

    -- Device Under Test (DUT) Instantiation
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

    -- Stimulus and Self-Checking Process
    stim_proc : process

        -- Helper procedure for AXI4-Lite write transactions
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

            -- Wait for AW and W handshakes
            wait until rising_edge(s_axi_aclk) and s_axi_awready = '1' and s_axi_wready = '1';
            s_axi_awvalid <= '0';
            s_axi_wvalid  <= '0';

            -- Wait for BVALID response
            if s_axi_bvalid = '0' then
                wait until rising_edge(s_axi_aclk) and s_axi_bvalid = '1';
            end if;
            assert s_axi_bresp = "00"
                report "ERROR: AXI Write BRESP is not OKAY (00)!" severity failure;

            wait until rising_edge(s_axi_aclk);
            s_axi_bready <= '0';
        end procedure;

        -- Helper procedure for AXI4-Lite read transactions
        procedure axi_read(
            constant addr : in  std_logic_vector(7 downto 0);
            signal   data : out std_logic_vector(31 downto 0)
        ) is
        begin
            wait until rising_edge(s_axi_aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= '1';
            s_axi_rready  <= '1';

            -- Wait for ARREADY handshake
            wait until rising_edge(s_axi_aclk) and s_axi_arready = '1';
            s_axi_arvalid <= '0';

            -- Wait for RVALID data
            if s_axi_rvalid = '0' then
                wait until rising_edge(s_axi_aclk) and s_axi_rvalid = '1';
            end if;
            data <= s_axi_rdata;
            assert s_axi_rresp = "00"
                report "ERROR: AXI Read RRESP is not OKAY (00)!" severity failure;

            wait until rising_edge(s_axi_aclk);
            s_axi_rready <= '0';
        end procedure;

    begin
        -- ---------------------------------------------------------------------
        -- TEST 1: Check Reset State
        -- ---------------------------------------------------------------------
        s_axi_aresetn <= '0';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(s_axi_aclk);
        s_axi_aresetn <= '1';
        wait for CLK_PERIOD * 2;

        axi_read(x"08", read_data);
        assert read_data = x"00000004"
            report "TEST 1 ERROR: ACCEL_DIM reset value is not 4!" severity failure;
        assert accel_dim_out = x"04"
            report "TEST 1 ERROR: accel_dim_out is not 0x04!" severity failure;
        report "TEST 1 OK: Default reset value ACCEL_DIM = 4 verified." severity note;

        -- ---------------------------------------------------------------------
        -- TEST 2: Write ACCEL_DIM (0x08, N=8) and verify readback
        -- ---------------------------------------------------------------------
        axi_write(x"08", x"00000008");
        axi_read(x"08", read_data);
        assert read_data = x"00000008"
            report "TEST 2 ERROR: ACCEL_DIM readback mismatch!" severity failure;
        assert accel_dim_out = x"08"
            report "TEST 2 ERROR: accel_dim_out was not updated to 0x08!" severity failure;
        report "TEST 2 OK: ACCEL_DIM write and readback (N=8) verified." severity note;

        -- ---------------------------------------------------------------------
        -- TEST 3: Write ACCEL_CR (0x00, START=1, IE=1 -> 0x00000005) and verify auto-clear
        -- ---------------------------------------------------------------------
        wait until rising_edge(s_axi_aclk);
        s_axi_awaddr  <= x"00";
        s_axi_awvalid <= '1';
        s_axi_wdata   <= x"00000005"; -- bit 0 (START) = 1, bit 2 (IE) = 1
        s_axi_wstrb   <= "1111";
        s_axi_wvalid  <= '1';
        s_axi_bready  <= '1';

        -- Wait until Slave asserts AWREADY and WREADY (after T2 clock cycle):
        wait until s_axi_awready = '1' and s_axi_wready = '1';
        wait for 1 ns;
        -- In this clock cycle, accel_start_out must be asserted ('1'):
        assert accel_start_out = '1'
            report "TEST 3 ERROR: accel_start_out did not assert!" severity failure;

        -- Handshake rising edge (T3): Master acknowledges completion,
        -- and the Slave simultaneously clears the START bit to '0'!
        wait until rising_edge(s_axi_aclk);
        s_axi_awvalid <= '0';
        s_axi_wvalid  <= '0';
        s_axi_bready  <= '0';
        wait for 1 ns;
        assert accel_start_out = '0'
            report "TEST 3 ERROR: accel_start_out was not automatically cleared after 1 cycle!" severity failure;

        -- Reading back CR register must show only the IE bit (0x04) set:
        axi_read(x"00", read_data);
        assert read_data = x"00000004"
            report "TEST 3 ERROR: IE bit was not retained in ACCEL_CR, or START did not clear!" severity failure;
        report "TEST 3 OK: START pulse (1-cycle auto-clear) and IE bit behavior verified." severity note;

        -- ---------------------------------------------------------------------
        -- TEST 4: Simulate accelerator operation (BUSY, CYCLES, DONE, and IRQ)
        -- ---------------------------------------------------------------------
        accel_busy_in   <= '1';
        accel_cycles_in <= x"000001A4"; -- 420 clock cycles
        axi_read(x"04", read_data);
        assert read_data = x"00000001"
            report "TEST 4 ERROR: ACCEL_SR BUSY bit is not set!" severity failure;

        -- Accelerator finishes calculation: 1-cycle DONE pulse
        wait until rising_edge(s_axi_aclk);
        accel_busy_in <= '0';
        accel_done_in <= '1';
        wait until rising_edge(s_axi_aclk);
        accel_done_in <= '0';
        wait for 1 ns;

        -- DONE flag and IRQ output must remain asserted (since IE=1)
        assert irq_out = '1'
            report "TEST 4 ERROR: irq_out was not asserted after DONE!" severity failure;

        axi_read(x"04", read_data);
        assert read_data = x"00000002"
            report "TEST 4 ERROR: ACCEL_SR DONE bit (bit 1) is not set!" severity failure;

        axi_read(x"0C", read_data);
        assert read_data = x"000001A4"
            report "TEST 4 ERROR: ACCEL_CYCLES value is not 0x000001A4!" severity failure;
        report "TEST 4 OK: ACCEL_SR (BUSY/DONE), ACCEL_CYCLES, and irq_out verified." severity note;

        -- ---------------------------------------------------------------------
        -- TEST 5: Clear DONE flag and IRQ by issuing a new START pulse
        -- ---------------------------------------------------------------------
        axi_write(x"00", x"00000005"); -- New START
        wait until rising_edge(s_axi_aclk);
        wait for 1 ns;
        assert irq_out = '0'
            report "TEST 5 ERROR: done_flag / irq_out was not cleared after new START!" severity failure;
        report "TEST 5 OK: DONE flag and IRQ successfully cleared on new START." severity note;

        report "=========================================================" severity note;
        report "ALL AXI4-LITE SLAVE TESTS PASSED (PASS)!" severity note;
        report "=========================================================" severity note;

        sim_done <= true;
        wait;
    end process;

end architecture sim;