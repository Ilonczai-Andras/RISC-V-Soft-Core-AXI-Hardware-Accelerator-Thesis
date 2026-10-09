-- The Potato Processor - SoC design for the Arty FPGA board
-- (c) Kristian Klomsten Skordal 2016 <kristian.skordal@wafflemail.net>
-- Report bugs and issues on <https://github.com/skordal/potato/issues>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_toplevel is
end entity tb_toplevel;

architecture testbench of tb_toplevel is

	signal clk : std_logic := '0';
	constant clk_period : time := 10 ns;

	signal reset_n : std_logic := '0';

	signal gpio_pins : std_logic_vector(11 downto 0);

	signal uart0_txd : std_logic;
	signal uart0_rxd : std_logic := '1';

	signal uart1_txd : std_logic;
	signal uart1_rxd : std_logic := '1';

begin

	uut: entity work.toplevel
		port map(
			clk => clk,
			reset_n => reset_n,
			gpio_pins => gpio_pins,
			uart0_txd => uart0_txd,
			uart0_rxd => uart0_rxd,
			uart1_txd => uart1_txd,
			uart1_rxd => uart1_rxd
		);

	clock: process
	begin
		clk <= '0';
		wait for clk_period / 2;
		clk <= '1';
		wait for clk_period / 2;
	end process clock;

	stimulus: process
	begin
		reset_n <= '0';
		wait for clk_period * 4;
		reset_n <= '1';

		wait;
	end process stimulus;
    
    uart_monitor: process
            constant bit_period : time := 8681 ns; -- 115200 baud bitideje
            variable rx_byte    : std_logic_vector(7 downto 0);
            variable rx_char    : character;
            variable log_line   : line;
        begin
            -- 1. Várakozás a Start bitre (lefutó él)
            wait until falling_edge(uart0_txd);

            -- 2. Beugrás a Start bit közepére
            wait for bit_period / 2;

            -- 3. A 8 adatbit mintavételezése (LSB first)
            for i in 0 to 7 loop
                wait for bit_period;
                rx_byte(i) := uart0_txd;
            end loop;

            -- 4. Várakozás a Stop bitre
            wait for bit_period;

            -- 5. Karakter átalakítása és kiírása
            rx_char := character'val(to_integer(unsigned(rx_byte)));

            -- Ha újsor (LF = ASCII 10), kiírjuk az egész sort a Vivado Tcl konzolra
            if rx_char = LF then
                writeline(output, log_line);
            elsif rx_char /= CR then -- A kocsi-vissza (CR = ASCII 13) karaktert kihagyjuk
                write(log_line, rx_char);
            end if;

        end process uart_monitor;
    
end architecture testbench;
