----------------------------------------------------------------------------------
-- Testbench:       tb_wb_to_axi4_lite_bridge
-- Project:         RISC-V Soft-Core + AXI Hardware Accelerator Thesis
-- Description:     Self-checking VHDL testbench for Wishbone B4 -> AXI4-Lite bridge
--                  and AXI4-Lite Slave register bank integration.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_wb_to_axi4_lite_bridge is
end entity tb_wb_to_axi4_lite_bridge;

architecture sim of tb_wb_to_axi4_lite_bridge is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz clock period (SoC system frequency)

    -- Global signals
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1'; -- Active-high internal reset
    signal reset_n : std_logic := '0'; -- Active-low AXI slave reset

    -- Wishbone bus signals (Master -> Bridge)
    signal wb_adr_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal wb_sel_in  : std_logic_vector(3 downto 0)  := "1111";
    signal wb_cyc_in  : std_logic := '0';
    signal wb_stb_in  : std_logic := '0';
    signal wb_we_in   : std_logic := '0';
    signal wb_dat_in  : std_logic_vector(31 downto 0) := (others => '0');
    signal wb_dat_out : std_logic_vector(31 downto 0);
    signal wb_ack_out : std_logic;

    -- AXI4-Lite interconnect signals (Bridge Master -> Slave Register Bank)
    signal axi_awaddr  : std_logic_vector(31 downto 0);
    signal axi_awprot  : std_logic_vector(2 downto 0);
    signal axi_awvalid : std_logic;
    signal axi_awready : std_logic;

    signal axi_wdata   : std_logic_vector(31 downto 0);
    signal axi_wstrb   : std_logic_vector(3 downto 0);
    signal axi_wvalid  : std_logic;
    signal axi_wready  : std_logic;

    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_bready  : std_logic;

    signal axi_araddr  : std_logic_vector(31 downto 0);
    signal axi_arprot  : std_logic_vector(2 downto 0);
    signal axi_arvalid : std_logic;
    signal axi_arready : std_logic;

    signal axi_rdata   : std_logic_vector(31 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);
    signal axi_rvalid  : std_logic;
    signal axi_rready  : std_logic;

    -- Accelerator dedicated control & status signals
    signal accel_start_out  : std_logic;
    signal accel_reset_out  : std_logic;
    signal accel_dim_out    : std_logic_vector(7 downto 0);
    signal accel_busy_in    : std_logic := '0';
    signal accel_done_in    : std_logic := '0';
    signal accel_err_ovf_in : std_logic := '0';
    signal accel_cycles_in  : std_logic_vector(31 downto 0) := x"000001A4"; -- 420 cycles test value
    signal irq_out          : std_logic;

    -- Simulation helper signals
    signal read_data : std_logic_vector(31 downto 0) := (others => '0');
    signal sim_done  : boolean := false;

    -- Wishbone write procedure (Classic Wishbone transaction)
    procedure wb_write(
        addr : in  std_logic_vector(31 downto 0);
        data : in  std_logic_vector(31 downto 0);
        signal clk_sig : in std_logic;
        signal cyc_sig : out std_logic;
        signal stb_sig : out std_logic;
        signal we_sig  : out std_logic;
        signal adr_sig : out std_logic_vector(31 downto 0);
        signal dat_sig : out std_logic_vector(31 downto 0);
        signal ack_sig : in  std_logic
    ) is
    begin
        wait until rising_edge(clk_sig);
        cyc_sig <= '1';
        stb_sig <= '1';
        we_sig  <= '1';
        adr_sig <= addr;
        dat_sig <= data;

        -- Wait for single-cycle Wishbone ACK pulse
        wait until rising_edge(clk_sig) and ack_sig = '1';
        cyc_sig <= '0';
        stb_sig <= '0';
        we_sig  <= '0';
    end procedure;

    -- Wishbone read procedure
    procedure wb_read(
        addr : in  std_logic_vector(31 downto 0);
        data_out : out std_logic_vector(31 downto 0);
        signal clk_sig     : in  std_logic;
        signal cyc_sig     : out std_logic;
        signal stb_sig     : out std_logic;
        signal we_sig      : out std_logic;
        signal adr_sig     : out std_logic_vector(31 downto 0);
        signal dat_in_sig  : in  std_logic_vector(31 downto 0);
        signal ack_sig     : in  std_logic
    ) is
    begin
        wait until rising_edge(clk_sig);
        cyc_sig <= '1';
        stb_sig <= '1';
        we_sig  <= '0';
        adr_sig <= addr;

        -- Wait for Wishbone ACK pulse and capture incoming data
        wait until rising_edge(clk_sig) and ack_sig = '1';
        data_out := dat_in_sig;
        cyc_sig <= '0';
        stb_sig <= '0';
    end procedure;

begin

    -- 50 MHz clock generation
    clk_proc : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_proc;

    -- Reset polarity translation: AXI slave expects active-low reset
    reset_n <= not reset;

    -- =========================================================================
    -- UUT 1: Wishbone -> AXI4-Lite Bridge
    -- =========================================================================
    uut_bridge : entity work.wb_to_axi4_lite_bridge
        generic map (
            ADDR_WIDTH => 32,
            DATA_WIDTH => 32
        )
        port map (
            clk          => clk,
            reset        => reset,
            wb_adr_in    => wb_adr_in,
            wb_sel_in    => wb_sel_in,
            wb_cyc_in    => wb_cyc_in,
            wb_stb_in    => wb_stb_in,
            wb_we_in     => wb_we_in,
            wb_dat_in    => wb_dat_in,
            wb_dat_out   => wb_dat_out,
            wb_ack_out   => wb_ack_out,

            m_axi_awaddr  => axi_awaddr,
            m_axi_awprot  => axi_awprot,
            m_axi_awvalid => axi_awvalid,
            m_axi_awready => axi_awready,

            m_axi_wdata   => axi_wdata,
            m_axi_wstrb   => axi_wstrb,
            m_axi_wvalid  => axi_wvalid,
            m_axi_wready  => axi_wready,

            m_axi_bresp   => axi_bresp,
            m_axi_bvalid  => axi_bvalid,
            m_axi_bready  => axi_bready,

            m_axi_araddr  => axi_araddr,
            m_axi_arprot  => axi_arprot,
            m_axi_arvalid => axi_arvalid,
            m_axi_arready => axi_arready,

            m_axi_rdata   => axi_rdata,
            m_axi_rresp   => axi_rresp,
            m_axi_rvalid  => axi_rvalid,
            m_axi_rready  => axi_rready
        );

    -- =========================================================================
    -- UUT 2: AXI4-Lite Slave Register Bank
    -- =========================================================================
    uut_slave : entity work.axi4_lite_slave_ctrl
        port map (
            s_axi_aclk    => clk,
            s_axi_aresetn => reset_n,

            s_axi_araddr  => axi_araddr(7 downto 0),
            s_axi_arvalid => axi_arvalid,
            s_axi_arready => axi_arready,

            s_axi_rdata   => axi_rdata,
            s_axi_rresp   => axi_rresp,
            s_axi_rvalid  => axi_rvalid,
            s_axi_rready  => axi_rready,

            s_axi_awaddr  => axi_awaddr(7 downto 0),
            s_axi_awvalid => axi_awvalid,
            s_axi_awready => axi_awready,

            s_axi_wdata   => axi_wdata,
            s_axi_wstrb   => axi_wstrb,
            s_axi_wvalid  => axi_wvalid,
            s_axi_wready  => axi_wready,

            s_axi_bresp   => axi_bresp,
            s_axi_bvalid  => axi_bvalid,
            s_axi_bready  => axi_bready,

            accel_start_out  => accel_start_out,
            accel_reset_out  => accel_reset_out,
            accel_dim_out    => accel_dim_out,
            accel_busy_in    => accel_busy_in,
            accel_done_in    => accel_done_in,
            accel_err_ovf_in => accel_err_ovf_in,
            accel_cycles_in  => accel_cycles_in,
            irq_out          => irq_out
        );

    -- =========================================================================
    -- Stimulus Process (Test Scenarios)
    -- =========================================================================
    stim_proc : process
        variable v_read : std_logic_vector(31 downto 0);
    begin
        -- 1. Reset phase
        reset <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);
        reset <= '0';
        wait for CLK_PERIOD * 3;

        report "--- SPRINT 5: WISHBONE <-> AXI4-LITE BRIDGE TEST START ---";

        -- ---------------------------------------------------------------------
        -- TEST 1: Read default register value via Wishbone
        -- Address: 0xC0006008 (ACCEL_DIM), expected: 0x00000004
        -- ---------------------------------------------------------------------
        wb_read(x"C0006008", v_read, clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_out, wb_ack_out);
        read_data <= v_read;
        assert v_read = x"00000004"
            report "ERROR Test 1: ACCEL_DIM read failed!"
            severity failure;
        report "TEST 1 OK: Wishbone read successful (ACCEL_DIM = 4).";

        wait for CLK_PERIOD * 2;

        -- ---------------------------------------------------------------------
        -- TEST 2: Register write and readback via Wishbone
        -- Address: 0xC0006008 (ACCEL_DIM) write 8 (0x00000008)
        -- ---------------------------------------------------------------------
        wb_write(x"C0006008", x"00000008", clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_in, wb_ack_out);
        wait for CLK_PERIOD * 2;

        assert accel_dim_out = x"08"
            report "ERROR Test 2: accel_dim_out port did not update to 8!"
            severity failure;

        wb_read(x"C0006008", v_read, clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_out, wb_ack_out);
        read_data <= v_read;
        assert v_read = x"00000008"
            report "ERROR Test 2: ACCEL_DIM readback value mismatch!"
            severity failure;
        report "TEST 2 OK: Wishbone write and readback successful (ACCEL_DIM = 8).";

        wait for CLK_PERIOD * 2;

        -- ---------------------------------------------------------------------
        -- TEST 3: Accelerator START and IE write via Wishbone
        -- Address: 0xC0006000 (ACCEL_CR), value: 0x00000005 (Bit 0: START, Bit 2: IE)
        -- ---------------------------------------------------------------------
        wb_write(x"C0006000", x"00000005", clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_in, wb_ack_out);

        -- Wait 1 clock cycle: auto-clear START pulse should be generated
        wait for CLK_PERIOD;
        wb_read(x"C0006000", v_read, clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_out, wb_ack_out);
        read_data <= v_read;
        -- START bit (bit 0) cleared, IE bit (bit 2 = 4) retained:
        assert v_read = x"00000004"
            report "ERROR Test 3: ACCEL_CR START auto-clear or IE error!"
            severity failure;
        report "TEST 3 OK: Wishbone control: START auto-cleared and IE retained.";

        wait for CLK_PERIOD * 2;

        -- ---------------------------------------------------------------------
        -- TEST 4: Accelerator DONE and IRQ assertion check via Wishbone
        -- Simulate hardware accelerator completing matrix multiplication:
        -- ---------------------------------------------------------------------
        accel_busy_in <= '1';
        wait for CLK_PERIOD * 3;
        accel_busy_in <= '0';
        accel_done_in <= '1'; -- 1-cycle completion pulse
        wait for CLK_PERIOD;
        accel_done_in <= '0';

        wait for CLK_PERIOD;

        -- IRQ must be active (DONE=1 and IE=1)
        assert irq_out = '1'
            report "ERROR Test 4: irq_out is not active after DONE!"
            severity failure;

        -- Read Status Register via Wishbone: 0xC0006004 (ACCEL_SR)
        -- Expected value: 0x00000002 (Bit 1: DONE)
        wb_read(x"C0006004", v_read, clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_out, wb_ack_out);
        read_data <= v_read;
        assert v_read = x"00000002"
            report "ERROR Test 4: ACCEL_SR DONE bit is not set!"
            severity failure;

        -- Read Cycle Counter: 0xC000600C (ACCEL_CYCLES)
        wb_read(x"C000600C", v_read, clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_out, wb_ack_out);
        read_data <= v_read;
        assert v_read = x"000001A4"
            report "ERROR Test 4: ACCEL_CYCLES read mismatch!"
            severity failure;
        report "TEST 4 OK: Accelerator DONE, ACCEL_SR, ACCEL_CYCLES, and IRQ verified.";

        wait for CLK_PERIOD * 2;

        -- ---------------------------------------------------------------------
        -- TEST 5: New START via Wishbone -> clear DONE flag and deassert IRQ
        -- ---------------------------------------------------------------------
        wb_write(x"C0006000", x"00000005", clk, wb_cyc_in, wb_stb_in, wb_we_in, wb_adr_in, wb_dat_in, wb_ack_out);
        wait for CLK_PERIOD * 2;

        assert irq_out = '0'
            report "ERROR Test 5: IRQ was not deasserted on new START!"
            severity failure;
        report "TEST 5 OK: New START successfully cleared DONE flag and deasserted IRQ.";

        report "=========================================================";
        report "ALL WISHBONE <-> AXI4-LITE BRIDGE TESTS PASSED (PASS)!";
        report "=========================================================";

        sim_done <= true;
        wait;
    end process stim_proc;

end architecture sim;