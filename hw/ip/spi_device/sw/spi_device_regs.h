// Generated register defines for SPI_DEVICE

// Copyright information found in source file:
// Copyright lowRISC contributors.

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _SPI_DEVICE_REG_DEFS_
#define _SPI_DEVICE_REG_DEFS_

// Interrupt State Register
#define SPI_DEVICE_INTR_STATE(id) (SPI_DEVICE##id##_BASE_ADDR + 0x0)
#define SPI_DEVICE_INTR_STATE_RXNE 0
#define SPI_DEVICE_INTR_STATE_RXLVL 1
#define SPI_DEVICE_INTR_STATE_TXE 2
#define SPI_DEVICE_INTR_STATE_TXF 3
#define SPI_DEVICE_INTR_STATE_TXLVL 4
#define SPI_DEVICE_INTR_STATE_RXERR 5

// Interrupt Enable Register
#define SPI_DEVICE_INTR_ENABLE(id) (SPI_DEVICE##id##_BASE_ADDR + 0x4)
#define SPI_DEVICE_INTR_ENABLE_RXNE 0
#define SPI_DEVICE_INTR_ENABLE_RXLVL 1
#define SPI_DEVICE_INTR_ENABLE_TXE 2
#define SPI_DEVICE_INTR_ENABLE_TXF 3
#define SPI_DEVICE_INTR_ENABLE_TXLVL 4
#define SPI_DEVICE_INTR_ENABLE_RXERR 5

// Interrupt Test Register
#define SPI_DEVICE_INTR_TEST(id) (SPI_DEVICE##id##_BASE_ADDR + 0x8)
#define SPI_DEVICE_INTR_TEST_RXNE 0
#define SPI_DEVICE_INTR_TEST_RXLVL 1
#define SPI_DEVICE_INTR_TEST_TXE 2
#define SPI_DEVICE_INTR_TEST_TXF 3
#define SPI_DEVICE_INTR_TEST_TXLVL 4
#define SPI_DEVICE_INTR_TEST_RXERR 5

// Control register
#define SPI_DEVICE_CONTROL(id) (SPI_DEVICE##id##_BASE_ADDR + 0xc)
#define SPI_DEVICE_CONTROL_ABORT 0
#define SPI_DEVICE_CONTROL_MODE_MASK 0x3
#define SPI_DEVICE_CONTROL_MODE_OFFSET 4
#define SPI_DEVICE_CONTROL_MODE_FWMODE 0
#define SPI_DEVICE_CONTROL_RST_TXFIFO 16
#define SPI_DEVICE_CONTROL_RST_RXFIFO 17

// Configuration Register
#define SPI_DEVICE_CFG(id) (SPI_DEVICE##id##_BASE_ADDR + 0x10)
#define SPI_DEVICE_CFG_CPOL 0
#define SPI_DEVICE_CFG_CPHA 1
#define SPI_DEVICE_CFG_TX_ORDER 2
#define SPI_DEVICE_CFG_RX_ORDER 3
#define SPI_DEVICE_CFG_TIMER_V_MASK 0xff
#define SPI_DEVICE_CFG_TIMER_V_OFFSET 8

// RX/ TX FIFO levels.
#define SPI_DEVICE_FIFO_LEVEL(id) (SPI_DEVICE##id##_BASE_ADDR + 0x14)
#define SPI_DEVICE_FIFO_LEVEL_RXLVL_MASK 0xffff
#define SPI_DEVICE_FIFO_LEVEL_RXLVL_OFFSET 0
#define SPI_DEVICE_FIFO_LEVEL_TXLVL_MASK 0xffff
#define SPI_DEVICE_FIFO_LEVEL_TXLVL_OFFSET 16

// RX/ TX Async FIFO levels between main clk and spi clock
#define SPI_DEVICE_ASYNC_FIFO_LEVEL(id) (SPI_DEVICE##id##_BASE_ADDR + 0x18)
#define SPI_DEVICE_ASYNC_FIFO_LEVEL_RXLVL_MASK 0xff
#define SPI_DEVICE_ASYNC_FIFO_LEVEL_RXLVL_OFFSET 0
#define SPI_DEVICE_ASYNC_FIFO_LEVEL_TXLVL_MASK 0xff
#define SPI_DEVICE_ASYNC_FIFO_LEVEL_TXLVL_OFFSET 16

// FIFO status register
#define SPI_DEVICE_STATUS(id) (SPI_DEVICE##id##_BASE_ADDR + 0x1c)
#define SPI_DEVICE_STATUS_RXF_FULL 0
#define SPI_DEVICE_STATUS_RXF_EMPTY 1
#define SPI_DEVICE_STATUS_TXF_FULL 2
#define SPI_DEVICE_STATUS_TXF_EMPTY 3
#define SPI_DEVICE_STATUS_ABORT_DONE 4

// Receiver FIFO (SRAM) pointers
#define SPI_DEVICE_RXF_PTR(id) (SPI_DEVICE##id##_BASE_ADDR + 0x20)
#define SPI_DEVICE_RXF_PTR_RPTR_MASK 0xffff
#define SPI_DEVICE_RXF_PTR_RPTR_OFFSET 0
#define SPI_DEVICE_RXF_PTR_WPTR_MASK 0xffff
#define SPI_DEVICE_RXF_PTR_WPTR_OFFSET 16

// Transmitter FIFO (SRAM) pointers
#define SPI_DEVICE_TXF_PTR(id) (SPI_DEVICE##id##_BASE_ADDR + 0x24)
#define SPI_DEVICE_TXF_PTR_RPTR_MASK 0xffff
#define SPI_DEVICE_TXF_PTR_RPTR_OFFSET 0
#define SPI_DEVICE_TXF_PTR_WPTR_MASK 0xffff
#define SPI_DEVICE_TXF_PTR_WPTR_OFFSET 16

// Receiver FIFO (SRAM) Addresses
#define SPI_DEVICE_RXF_ADDR(id) (SPI_DEVICE##id##_BASE_ADDR + 0x28)
#define SPI_DEVICE_RXF_ADDR_BASE_MASK 0xffff
#define SPI_DEVICE_RXF_ADDR_BASE_OFFSET 0
#define SPI_DEVICE_RXF_ADDR_LIMIT_MASK 0xffff
#define SPI_DEVICE_RXF_ADDR_LIMIT_OFFSET 16

// Transmitter FIFO (SRAM) Addresses
#define SPI_DEVICE_TXF_ADDR(id) (SPI_DEVICE##id##_BASE_ADDR + 0x2c)
#define SPI_DEVICE_TXF_ADDR_BASE_MASK 0xffff
#define SPI_DEVICE_TXF_ADDR_BASE_OFFSET 0
#define SPI_DEVICE_TXF_ADDR_LIMIT_MASK 0xffff
#define SPI_DEVICE_TXF_ADDR_LIMIT_OFFSET 16

// Memory area: SPI internal 2kB buffer.
#define SPI_DEVICE_BUFFER(base) ((base) + 0x800)
#define SPI_DEVICE_BUFFER_SIZE_WORDS 512
#define SPI_DEVICE_BUFFER_SIZE_BYTES 2048
#endif  // _SPI_DEVICE_REG_DEFS_
// End generated register defines for SPI_DEVICE
