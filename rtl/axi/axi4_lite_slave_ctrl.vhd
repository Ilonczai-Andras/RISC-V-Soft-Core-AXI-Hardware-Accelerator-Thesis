



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_lite_slave_ctrl is
    port(
        -- Global Signals
        s_axi_aclk : in std_logic;
        s_axi_aresetn : in std_logic;

        -- Read Address Channel
        s_axi_araddr: in std_logic_vector(7 downto 0);
        s_axi_arvalid: in std_logic;
        s_axi_arready: out std_logic;

        -- Read Data Channel
        s_axi_rdata: out std_logic_vector(31 downto 0);
        s_axi_rresp: out std_logic_vector(1 downto 0);
        s_axi_rvalid: out std_logic;
        s_axi_rready: in std_logic;

        -- Write Address Channel
        s_axi_awaddr: in std_logic_vector(7 downto 0);
        s_axi_awvalid: in std_logic;
        s_axi_awready: out std_logic;

        -- Write Data Channel
        s_axi_wdata: in std_logic_vector(31 downto 0);
        s_axi_wstrb: in std_logic_vector(3 downto 0);
        s_axi_wvalid : in  std_logic;
        s_axi_wready : out std_logic;

        -- Write Response Channel
        s_axi_bresp: out std_logic_vector(1 downto 0);
        s_axi_bvalid: out std_logic;
        s_axi_bready: in std_logic;

        -- Hardware acceleration core and signals directed toward the CPU
        accel_start_out: out std_logic;
        accel_reset_out: out std_logic;
        accel_dim_out: out std_logic_vector(7 downto 0);

        accel_busy_in: in std_logic;
        accel_done_in: in std_logic;
        accel_err_ovf_in: in std_logic;
        accel_cycles_in: in std_logic_vector(31 downto 0);

        irq_out : out std_logic
    );
end entity;

architecture behaviour of axi4_lite_slave_ctrl is
    -- Register
        -- ACCEL_CR
        signal reg_cr : std_logic_vector(31 downto 0) := (others => '0');
        -- ACCEL_SR
        signal reg_sr : std_logic_vector(31 downto 0) := (others => '0');
        -- ACCEL_DIM
        signal reg_dim : std_logic_vector(31 downto 0) := x"00000004";
        --ACCEL_CYCLES
        signal reg_cycles : std_logic_vector(31 downto 0) := (others => '0');

    -- Signals
        signal awready_reg, wready_reg, bvalid_reg : std_logic := '0';
        signal arready_reg, rvalid_reg : std_logic := '0';
        signal rdata_reg : std_logic_vector(31 downto 0) := (others => '0');
        signal done_flag : std_logic := '0';

begin

    s_axi_awready <= awready_reg;
    s_axi_wready  <= wready_reg;
    s_axi_bvalid  <= bvalid_reg;
    s_axi_bresp   <= "00"; -- OKAY válasz

    s_axi_arready <= arready_reg;
    s_axi_rvalid  <= rvalid_reg;
    s_axi_rdata   <= rdata_reg;
    s_axi_rresp   <= "00"; -- OKAY válasz

    -- 2. Státusz (ACCEL_SR) és Ciklusszámláló (ACCEL_CYCLES) regiszterek összeállítása
    reg_sr(0)           <= accel_busy_in;
    reg_sr(1)           <= done_flag;
    reg_sr(2)           <= accel_err_ovf_in;
    reg_sr(31 downto 3) <= (others => '0');

    reg_cycles          <= accel_cycles_in;

    -- 3. Gyorsító vezérlő kimenetek és IRQ meghajtása
    accel_start_out <= reg_cr(0);
    accel_reset_out <= reg_cr(1);
    accel_dim_out   <= reg_dim(7 downto 0);
    irq_out         <= done_flag and reg_cr(2); -- IRQ ha DONE=1 és IE (bit 2)=1

    write_proc : process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                awready_reg <= '0';
                wready_reg <= '0';
                bvalid_reg <= '0';

                done_flag <= '0';

                reg_cr <= (others => '0');
                reg_dim <= x"00000004";
            else
                -- 1. Alaphelyzetbe álló (1 órajeles impulzus) jelek
                reg_cr(0) <= '0';
                awready_reg <= '0';
                wready_reg <= '0';

                -- 2. DONE flag kezelése 
                if accel_done_in = '1' then
                    done_flag <= '1';
                elsif reg_cr(0) = '1' or reg_cr(1) = '1' then
                    done_flag <= '0';
                end if ;
                
                -- 3. AXI Írási kézfogás és címdekódolás
                if s_axi_awvalid = '1' and s_axi_wvalid = '1' and awready_reg = '0' and bvalid_reg = '0' then
                    awready_reg <= '1';
                    wready_reg <= '1';
                    bvalid_reg <= '1';

                    case s_axi_awaddr(3 downto 2) is
                        when "00" =>
                            reg_cr <= s_axi_wdata;
                        when "10" =>
                            reg_dim <= s_axi_wdata;
                        when others =>
                            null;
                        end case;
                end if;

                -- 4. AXI Írási válasz (B csatorna) lezárása
                if bvalid_reg = '1' and s_axi_bready = '1' then
                    bvalid_reg <= '0';
                end if;

            end if ;
        end if ;
    end process;

    read_proc : process(s_axi_aclk)
        begin
            if rising_edge(s_axi_aclk) then
                if s_axi_aresetn = '0' then
                    arready_reg <= '0';
                    rvalid_reg  <= '0';
                    rdata_reg   <= (others => '0');
                else
                    arready_reg <= '0';

                    if s_axi_arvalid = '1' and arready_reg = '0' and rvalid_reg = '0' then
                        arready_reg <= '1';
                        rvalid_reg  <= '1';

                        case s_axi_araddr(3 downto 2) is
                            when "00" =>
                                rdata_reg <= reg_cr;
                            when "01" =>
                                rdata_reg <= reg_sr;
                            when "10" =>
                                rdata_reg <= reg_dim;
                            when "11" =>
                                rdata_reg <= reg_cycles;
                            when others =>
                                rdata_reg <= (others => '0');
                        end case;
                    end if;

                    if rvalid_reg = '1' and s_axi_rready = '1' then
                        rvalid_reg <= '0';
                    end if;
                end if;
            end if;
        end process;

end architecture behaviour;