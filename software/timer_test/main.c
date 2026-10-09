// The Potato Processor - Timer Interrupt Test (Sprint 3)
// (c) Kristian Klomsten Skordal / RISC-V Accelerator Thesis

#include <stdint.h>
#include <stdbool.h>

#include "platform.h"
#include "potato.h"
#include "uart.h"
#include "timer.h"

static struct uart uart0;
static struct timer timer0;
static volatile uint32_t timer_ticks = 0;

void exception_handler(uint32_t cause, void * epc, void * regbase)
{
    (void)epc;
    (void)regbase;

    if ((cause & (1U << POTATO_MCAUSE_INTERRUPT_BIT)) && ((cause & POTATO_MCAUSE_IRQ_MASK) == PLATFORM_IRQ_TIMER0))
    {
        timer_start(&timer0);

        timer_ticks++;

        uart_tx_string(&uart0, "[IRQ 0] Timer tick: ");
        uart_tx(&uart0, '0' + (timer_ticks % 10));
        uart_tx_string(&uart0, "\r\n");
    }
}

int main(void)
{
    uart_initialize(&uart0, (volatile void *) PLATFORM_UART0_BASE);
    uart_set_divisor(&uart0, uart_baud2divisor(115200, PLATFORM_SYSCLK_FREQ));

    uart_tx_string(&uart0, "\r\n=== Potato RISC-V Timer IRQ Test ===\r\n");

    timer_initialize(&timer0, (volatile void *) PLATFORM_TIMER0_BASE);
    timer_stop(&timer0);
    timer_set_compare(&timer0, 100000);

    uart_tx_string(&uart0, "Timer0 configured (2 ms period). Enabling IRQ...\r\n");

    potato_enable_irq(PLATFORM_IRQ_TIMER0);

    potato_enable_interrupts();

    // 4. Timer0 elindítása:
    timer_start(&timer0);

    while (1) {
        potato_wfi();
    }

    return 0;
}