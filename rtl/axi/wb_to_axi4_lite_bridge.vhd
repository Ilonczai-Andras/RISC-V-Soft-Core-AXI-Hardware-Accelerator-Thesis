library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_to_axi4_lite_bridge is
    generic (
        ADDR_WIDTH : integer := 32;
        DATA_WIDTH : integer := 32
    );

    port (
        clk        : in std_logic;
        reset      : In std_logic;

        -- =========================================================================
        -- Wishbone B4 Slave Interface (from the Potato CPU)
        -- =========================================================================
        wb_adr_in  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);        -- Wishbone address
        wb_sel_in  : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);    -- Wishbone byte select
        wb_cyc_in  : in  std_logic;                                      -- Wishbone cycle
        wb_stb_in  : in  std_logic;                                      -- Wishbone strobe
        wb_we_in   : in  std_logic;                                      -- Wishbone write enable
        wb_dat_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);        -- Wishbone data output
        wb_dat_out : out std_logic_vector(DATA_WIDTH-1 downto 0);        -- Wishbone data input
        wb_ack_out : out std_logic;                                      -- Wishbone acknowledge

        -- =========================================================================
        -- AXI4-Lite Master Interface (to the AXI4-Lite Slave register bank)
        -- =========================================================================

        -- Write Address Channel (AW)
        m_axi_awaddr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        m_axi_awprot    : out std_logic_vector(2 downto 0);
        m_axi_awvalid   : out std_logic;
        m_axi_awready   : in  std_logic;

        -- Write Data Channel (W)
        m_axi_wdata     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axi_wstrb     : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        m_axi_wvalid    : out std_logic;
        m_axi_wready    : in  std_logic;

        -- Write Response Channel (B)
        m_axi_bresp     : in  std_logic_vector(1 downto 0);
        m_axi_bvalid    : in  std_logic;
        m_axi_bready    : out std_logic;

        -- Read Address Channel (AR)
        m_axi_araddr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        m_axi_arprot    : out std_logic_vector(2 downto 0);
        m_axi_arvalid   : out std_logic;
        m_axi_arready   : in  std_logic;

        -- Read Data Channel (R)
        m_axi_rdata     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axi_rresp     : in  std_logic_vector(1 downto 0);
        m_axi_rvalid    : in  std_logic;
        m_axi_rready    : out std_logic
    );
end entity wb_to_axi4_lite_bridge;

architecture rtl of wb_to_axi4_lite_bridge is

    -- FSM states
    type state_type is (
        ST_IDLE,
        ST_WRITE_DATA,
        ST_WRITE_RESP,
        ST_READ_ADDR,
        ST_READ_DATA,
        ST_ACK
    );

    signal state : state_type := ST_IDLE;

    signal aw_done_reg : std_logic := '0';
    signal w_done_reg  : std_logic := '0';

    signal wb_ack_reg   : std_logic := '0';
    signal wb_rdata_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal axi_awvalid_reg : std_logic := '0';
    signal axi_wvalid_reg  : std_logic := '0';
    signal axi_bready_reg  : std_logic := '0';
    signal axi_arvalid_reg : std_logic := '0';
    signal axi_rready_reg  : std_logic := '0';

begin

    -- Wishbone outputs
    wb_ack_out <= wb_ack_reg;
    wb_dat_out <= wb_rdata_reg;

    -- AXI Outputs

    -- AW
    m_axi_awaddr  <= wb_adr_in;
    m_axi_awprot  <= "000";
    m_axi_awvalid <= axi_awvalid_reg;

    -- W
    m_axi_wdata   <= wb_dat_in;
    m_axi_wstrb   <= wb_sel_in;
    m_axi_wvalid  <= axi_wvalid_reg;

    -- B
    m_axi_bready  <= axi_bready_reg;

    -- AR
    m_axi_araddr  <= wb_adr_in;
    m_axi_arprot  <= "000";
    m_axi_arvalid <= axi_arvalid_reg;

    -- R
    m_axi_rready  <= axi_rready_reg;

        fsm_proc : process(clk)
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    state           <= ST_IDLE;
                    aw_done_reg     <= '0';
                    w_done_reg      <= '0';
                    wb_ack_reg      <= '0';
                    wb_rdata_reg    <= (others => '0');
                    axi_awvalid_reg <= '0';
                    axi_wvalid_reg  <= '0';
                    axi_bready_reg  <= '0';
                    axi_arvalid_reg <= '0';
                    axi_rready_reg  <= '0';
                else
                    wb_ack_reg <= '0';
    
                    case state is
                        when ST_IDLE =>                                                                                                                                                                                                                                                  
                            aw_done_reg <= '0';                                                                                                                                                                                                                                          
                            w_done_reg  <= '0';                                                                                                                                                                                                                                          
                                                                                                                                                                                                                                                                                        
                            if (wb_cyc_in = '1' and wb_stb_in = '1') then                                                                                                                                                                                                                
                                if (wb_we_in = '1') then -- Write Transaction                                                                                                                                                                                                            
                                    axi_awvalid_reg <= '1';                                                                                                                                                                                                                              
                                    axi_wvalid_reg  <= '1';                                                                                                                                                                                                                              
                                    aw_done_reg     <= '0';                                                                                                                                                                                                                              
                                    w_done_reg      <= '0';                                                                                                                                                                                                                              
                                    state           <= ST_WRITE_DATA;                                                                                                                                                                                                                    
                                else                     -- Read Transaction                                                                                                                                                                                                             
                                    axi_arvalid_reg <= '1';                                                                                                                                                                                                                              
                                    state           <= ST_READ_ADDR;                                                                                                                                                                                                                     
                                end if;                                                                                                                                                                                                                                                  
                            else                                                                                                                                                                                                                                                         
                                state <= ST_IDLE;                                                                                                                                                                                                                                        
                            end if;

                        when ST_WRITE_DATA =>
                            -- AW
                            if ( axi_awvalid_reg = '1' and m_axi_awready = '1') then
                                axi_awvalid_reg <= '0';
                                aw_done_reg <= '1';
                            end if ;
                            
                            -- W
                            if ( axi_wvalid_reg = '1' and m_axi_wready = '1') then
                                axi_wvalid_reg <= '0';
                                w_done_reg <= '1';
                            end if ;

                            if ((aw_done_reg = '1' or (axi_awvalid_reg = '1' and m_axi_awready = '1')) and                                 
                                (w_done_reg  = '1' or (axi_wvalid_reg  = '1' and m_axi_wready  = '1'))) then                               
                                                                                                                                        
                                axi_bready_reg <= '1';                                                                                     
                                state          <= ST_WRITE_RESP;                                                                           
                            end if;

                        when ST_WRITE_RESP =>    

                            if m_axi_bvalid = '1' then                                                                                                                                                                                                                                   
                                axi_bready_reg <= '0';                                                                                                                                                                  
                                wb_ack_reg     <= '1';                                                                                                                                                               
                                state          <= ST_ACK;                                                                                                                                                                                                                                
                            else                                                                                                                                                                                                                                                         
                                state <= ST_WRITE_RESP;
                            end if;

                        when ST_READ_ADDR =>
                            if ( axi_arvalid_reg = '1' and m_axi_arready = '1' ) then
                                axi_arvalid_reg <= '0';
                                axi_rready_reg <= '1';
                                state <= ST_READ_DATA;
                            end if ;
                            
                        when ST_READ_DATA =>                                                                                                                                                                                                                                             
                            if m_axi_rvalid = '1' then                                                                                                                                                                                                                                   
                                wb_rdata_reg   <= m_axi_rdata;                                                                                                                                                                                
                                axi_rready_reg <= '0';                                                                                                                                                                                                   
                                wb_ack_reg     <= '1';                                                                                                                                                                          
                                state          <= ST_ACK;                                                                                                                                                                                                                                
                            else                                                                                                                                                                                                                                                         
                                state <= ST_READ_DATA;  -- Várakozás az adatra                                                                                                                                                                                                           
                            end if;

                        when ST_ACK =>
                            wb_ack_reg <= '0';                                                                                                                                                                                                                                           
                            state <= ST_IDLE;

                    end case;

                end if;
            end if;
        end process fsm_proc;

end architecture rtl;