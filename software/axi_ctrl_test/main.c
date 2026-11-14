// =============================================================================
// Potato RISC-V SoC - AXI Hardware Accelerator Control & Register Verification
// Sprint 5 Bare-Metal C Test Suite
// =============================================================================

#include <stdint.h>
#include <stdbool.h>

#include "platform.h"
#include "potato.h"
#include "uart.h"

// =============================================================================
// Hardware Accelerator MMIO Register Map (Base: 0xC000_6000)
// =============================================================================
#define PLATFORM_ACCEL_BASE         0xc0006000U

// Register Byte Offsets
#define ACCEL_REG_CR_OFFSET         0x00U  // Control Register
#define ACCEL_REG_SR_OFFSET         0x04U  // Status Register
#define ACCEL_REG_DIM_OFFSET        0x08U  // Matrix Dimension Register
#define ACCEL_REG_CYCLES_OFFSET     0x0cU  // Cycle Counter Register

// Direct 32-bit Memory-Mapped I/O Access Macros (Volatile MMIO)
#define ACCEL_REG_CR     (*(volatile uint32_t *)(PLATFORM_ACCEL_BASE + ACCEL_REG_CR_OFFSET))
#define ACCEL_REG_SR     (*(volatile uint32_t *)(PLATFORM_ACCEL_BASE + ACCEL_REG_SR_OFFSET))
#define ACCEL_REG_DIM    (*(volatile uint32_t *)(PLATFORM_ACCEL_BASE + ACCEL_REG_DIM_OFFSET))
#define ACCEL_REG_CYCLES (*(volatile uint32_t *)(PLATFORM_ACCEL_BASE + ACCEL_REG_CYCLES_OFFSET))

// Control Register (CR) Bit Definitions
#define ACCEL_CR_START              (1U << 0)  // 1-clock start pulse (Auto-cleared)
#define ACCEL_CR_RESET              (1U << 1)  // Software reset for accelerator
#define ACCEL_CR_IE                 (1U << 2)  // Interrupt Enable (IE)

// Status Register (SR) Bit Definitions
#define ACCEL_SR_BUSY               (1U << 0)  // 1 = Calculation in progress
#define ACCEL_SR_DONE               (1U << 1)  // 1 = Calculation complete (Sticky bit)
#define ACCEL_SR_ERR_OVF            (1U << 2)  // 1 = Accumulator overflow error

// Hardware Interrupt Line Index
#define PLATFORM_IRQ_ACCEL          5U         // Dedicated IRQ 5 line

static struct uart uart0;
static volatile uint32_t accel_irq_count = 0;

void exception_handler(uint32_t cause, void * epc, void * regbase)
{
    (void)epc;
    (void)regbase;

    // Check if cause is a hardware interrupt (MSB = 1)
    if (cause & (1U << POTATO_MCAUSE_INTERRUPT_BIT))
    {
        uint32_t irq_source = cause & POTATO_MCAUSE_IRQ_MASK;

        if (irq_source == PLATFORM_IRQ_ACCEL)
        {
            accel_irq_count++;
            uart_tx_string(&uart0, "\r\n[IRQ 5] Accelerator DONE Interrupt Received!\r\n");
        }
        else
        {
            uart_tx_string(&uart0, "\r\n[IRQ] Other Interrupt\r\n");
        }
    }
    else
    {
        // Exception occurred (e.g. Bus Error / Illegal instruction)
        uart_tx_string(&uart0, "\r\n[TRAP] Fatal Exception / Bus Error! Halt.\r\n");
        while (1) {
            potato_wfi();
        }
    }
}

int main(void)
{
    bool all_passed = true;

    // 1. Initialize UART0 to 115200 baud (50 MHz system clock)
    uart_initialize(&uart0, (volatile void *)PLATFORM_UART0_BASE);
    uart_set_divisor(&uart0, uart_baud2divisor(115200, PLATFORM_SYSCLK_FREQ));

    uart_tx_string(&uart0, "\r\n=========================================\r\n");
    uart_tx_string(&uart0, " Potato SoC - AXI Hardware Accelerator\r\n");
    uart_tx_string(&uart0, " Bare-Metal C Verification (Sprint 5)\r\n");
    uart_tx_string(&uart0, "=========================================\r\n\r\n");

    // -------------------------------------------------------------------------
    // TEST 1: Read default ACCEL_DIM register via the bridge
    // -------------------------------------------------------------------------
    uart_tx_string(&uart0, "[TEST 1] Reading default ACCEL_DIM... ");
    uint32_t default_dim = ACCEL_REG_DIM;

    if (default_dim == 4U) {
        uart_tx_string(&uart0, "PASS (DIM = 4)\r\n");
    } else {
        uart_tx_string(&uart0, "FAIL!\r\n");
        all_passed = false;
    }

    // -------------------------------------------------------------------------
    // TEST 2: Write ACCEL_DIM = 8 and readback (verify R/W data path)
    // -------------------------------------------------------------------------
    uart_tx_string(&uart0, "[TEST 2] Writing ACCEL_DIM = 8 and readback... ");
    ACCEL_REG_DIM = 8U;
    uint32_t readback_dim = ACCEL_REG_DIM;

    if (readback_dim == 8U) {
        uart_tx_string(&uart0, "PASS (DIM = 8)\r\n");
    } else {
        uart_tx_string(&uart0, "FAIL!\r\n");
        all_passed = false;
    }

    // -------------------------------------------------------------------------
    // TEST 3: Control Register (ACCEL_CR): START auto-clear and IE retention
    // -------------------------------------------------------------------------
    uart_tx_string(&uart0, "[TEST 3] Testing CR START auto-clear and IE... ");
    ACCEL_REG_CR = (ACCEL_CR_START | ACCEL_CR_IE); // 0x00000005

    // Readback: START (bit 0) cleared (0), IE (bit 2) retained (1):
    uint32_t cr_val = ACCEL_REG_CR;
    if ((cr_val & ACCEL_CR_START) == 0 && (cr_val & ACCEL_CR_IE) != 0) {
        uart_tx_string(&uart0, "PASS (START cleared, IE=1)\r\n");
    } else {
        uart_tx_string(&uart0, "FAIL!\r\n");
        all_passed = false;
    }

    // -------------------------------------------------------------------------
    // TEST 4: Read Status (ACCEL_SR) and Cycle Counter (ACCEL_CYCLES)
    // -------------------------------------------------------------------------
    uart_tx_string(&uart0, "[TEST 4] Reading Status & Cycles registers... ");
    uint32_t sr_val = ACCEL_REG_SR;
    uint32_t cycles_val = ACCEL_REG_CYCLES;

    // In idle state, accelerator is not busy and no error occurred (BUSY=0, ERR_OVF=0):
    if ((sr_val & ACCEL_SR_BUSY) == 0 && (sr_val & ACCEL_SR_ERR_OVF) == 0) {
        uart_tx_string(&uart0, "PASS (Status OK)\r\n");
    } else {
        uart_tx_string(&uart0, "FAIL!\r\n");
        all_passed = false;
    }

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    uart_tx_string(&uart0, "\r\n-----------------------------------------\r\n");
    if (all_passed) {
        uart_tx_string(&uart0, " *** ALL SPRINT 5 TESTS PASSED (PASS) ***\r\n");
    } else {
        uart_tx_string(&uart0, " !!! SOME TESTS FAILED (FAIL) !!!\r\n");
    }
    uart_tx_string(&uart0, "-----------------------------------------\r\n");

    // Wait in low-power sleep mode
    while (1) {
        potato_wfi();
    }

    return 0;
}