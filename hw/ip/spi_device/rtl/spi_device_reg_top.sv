// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Top module auto-generated by `reggen`


module spi_device_reg_top (
  input clk_i,
  input rst_ni,

  // Below Regster interface can be changed
  input  tlul_pkg::tl_h2d_t tl_i,
  output tlul_pkg::tl_d2h_t tl_o,

  // Output port for window
  output tlul_pkg::tl_h2d_t tl_win_o  [1],
  input  tlul_pkg::tl_d2h_t tl_win_i  [1],

  // To HW
  output spi_device_reg_pkg::spi_device_reg2hw_t reg2hw, // Write
  input  spi_device_reg_pkg::spi_device_hw2reg_t hw2reg  // Read
);

  import spi_device_reg_pkg::* ;

  localparam AW = 12;
  localparam IW = $bits(tl_i.a_source);
  localparam DW = 32;
  localparam DBW = DW/8;                    // Byte Width
  localparam logic [$clog2($clog2(DBW)+1)-1:0] FSZ = $clog2(DBW); // Full Size 2^(FSZ) = DBW;

  // register signals
  logic          reg_we;
  logic          reg_re;
  logic [AW-1:0] reg_addr;
  logic [DW-1:0] reg_wdata;
  logic          reg_valid;
  logic [DW-1:0] reg_rdata;
  logic          tl_malformed, tl_addrmiss;

  // Bus signals
  tlul_pkg::tl_d_op_e rsp_opcode; // AccessAck or AccessAckData
  logic          reqready;
  logic [IW-1:0] reqid;
  logic [IW-1:0] rspid;

  logic          outstanding;

  tlul_pkg::tl_h2d_t tl_reg_h2d;
  tlul_pkg::tl_d2h_t tl_reg_d2h;

  tlul_pkg::tl_h2d_t tl_socket_h2d [2];
  tlul_pkg::tl_d2h_t tl_socket_d2h [2];

  logic [1:0] reg_steer;

  // socket_1n connection
  assign tl_reg_h2d = tl_socket_h2d[1];
  assign tl_socket_d2h[1] = tl_reg_d2h;

  assign tl_win_o[0] = tl_socket_h2d[0];
  assign tl_socket_d2h[0] = tl_win_i[0];

  // Create Socket_1n
  tlul_socket_1n #(
    .N          (2),
    .HReqPass   (1'b1),
    .HRspPass   (1'b1),
    .DReqPass   ({2{1'b1}}),
    .DRspPass   ({2{1'b1}}),
    .HReqDepth  (4'h1),
    .HRspDepth  (4'h1),
    .DReqDepth  ({2{4'h1}}),
    .DRspDepth  ({2{4'h1}})
  ) u_socket (
    .clk_i,
    .rst_ni,
    .tl_h_i (tl_i),
    .tl_h_o (tl_o),
    .tl_d_o (tl_socket_h2d),
    .tl_d_i (tl_socket_d2h),
    .dev_select (reg_steer)
  );

  // Create steering logic
  always_comb begin
    reg_steer = 1;       // Default set to register

    // TODO: Can below codes be unique case () inside ?
    if (tl_i.a_address[AW-1:0] >= 2048) begin
      // Exceed or meet the address range. Removed the comparison of limit addr 'h 1000
      reg_steer = 0;
    end
  end

  // TODO(eunchan): Fix it after bus interface is finalized
  assign reg_we = tl_reg_h2d.a_valid && tl_reg_d2h.a_ready &&
                  ((tl_reg_h2d.a_opcode == tlul_pkg::PutFullData) ||
                   (tl_reg_h2d.a_opcode == tlul_pkg::PutPartialData));
  assign reg_re = tl_reg_h2d.a_valid && tl_reg_d2h.a_ready &&
                  (tl_reg_h2d.a_opcode == tlul_pkg::Get);
  assign reg_addr = tl_reg_h2d.a_address[AW-1:0];
  assign reg_wdata = tl_reg_h2d.a_data;

  assign tl_reg_d2h.d_valid  = reg_valid;
  assign tl_reg_d2h.d_opcode = rsp_opcode;
  assign tl_reg_d2h.d_param  = '0;
  assign tl_reg_d2h.d_size   = FSZ;         // always Full Size
  assign tl_reg_d2h.d_source = rspid;
  assign tl_reg_d2h.d_sink   = '0;          // Used in TL-C
  assign tl_reg_d2h.d_data   = reg_rdata;
  assign tl_reg_d2h.d_user   = '0;          // Doesn't allow additional features yet
  assign tl_reg_d2h.d_error  = tl_malformed | tl_addrmiss;

  assign tl_reg_d2h.a_ready  = reqready;

  assign reqid     = tl_reg_h2d.a_source;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tl_malformed <= 1'b1;
    end else if (tl_reg_h2d.a_valid && tl_reg_d2h.a_ready) begin
      if ((tl_reg_h2d.a_opcode != tlul_pkg::Get) &&
          (tl_reg_h2d.a_opcode != tlul_pkg::PutFullData) &&
          (tl_reg_h2d.a_opcode != tlul_pkg::PutPartialData)) begin
        tl_malformed <= 1'b1;
      // Only allow Full Write with full mask
      end else if (tl_reg_h2d.a_size != FSZ || tl_reg_h2d.a_mask != {DBW{1'b1}}) begin
        tl_malformed <= 1'b1;
      end else if (tl_reg_h2d.a_user.parity_en == 1'b1) begin
        tl_malformed <= 1'b1;
      end else begin
        tl_malformed <= 1'b0;
      end
    end
  end
  // TODO(eunchan): Revise Register Interface logic after REG INTF finalized
  // TODO(eunchan): Make concrete scenario
  //    1. Write: No response, so that it can guarantee a request completes a clock after we
  //              It means, bus_reg_ready doesn't have to be lowered.
  //    2. Read: response. So bus_reg_ready should assert after reg_bus_valid & reg_bus_ready
  //               _____         _____
  // a_valid _____/     \_______/     \______
  //         ___________         _____
  // a_ready            \_______/     \______ <- ERR though no logic malfunction
  //                     _____________
  // d_valid ___________/             \______
  //                             _____
  // d_ready ___________________/     \______
  //
  // Above example is fine but if r.b.r doesn't assert within two cycle, then it can be wrong.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    // Not to accept new request when a request is handling
    //   #Outstanding := 1
    if (!rst_ni) begin
      reqready <= 1'b0;
    end else if (reg_we || reg_re) begin
      reqready <= 1'b0;
    end else if (outstanding == 1'b0) begin
      reqready <= 1'b1;
    end
  end

  // Request/ Response ID
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rspid <= '0;
    end else if (reg_we || reg_re) begin
      rspid <= reqid;
    end
  end

  // Define SW related signals
  // Format: <reg>_<field>_{wd|we|qs}
  //        or <reg>_{wd|we|qs} if field == 1 or 0
  logic intr_state_rxne_qs;
  logic intr_state_rxne_wd;
  logic intr_state_rxne_we;
  logic intr_state_rxlvl_qs;
  logic intr_state_rxlvl_wd;
  logic intr_state_rxlvl_we;
  logic intr_state_txe_qs;
  logic intr_state_txe_wd;
  logic intr_state_txe_we;
  logic intr_state_txf_qs;
  logic intr_state_txf_wd;
  logic intr_state_txf_we;
  logic intr_state_txlvl_qs;
  logic intr_state_txlvl_wd;
  logic intr_state_txlvl_we;
  logic intr_state_rxerr_qs;
  logic intr_state_rxerr_wd;
  logic intr_state_rxerr_we;
  logic intr_enable_rxne_qs;
  logic intr_enable_rxne_wd;
  logic intr_enable_rxne_we;
  logic intr_enable_rxlvl_qs;
  logic intr_enable_rxlvl_wd;
  logic intr_enable_rxlvl_we;
  logic intr_enable_txe_qs;
  logic intr_enable_txe_wd;
  logic intr_enable_txe_we;
  logic intr_enable_txf_qs;
  logic intr_enable_txf_wd;
  logic intr_enable_txf_we;
  logic intr_enable_txlvl_qs;
  logic intr_enable_txlvl_wd;
  logic intr_enable_txlvl_we;
  logic intr_enable_rxerr_qs;
  logic intr_enable_rxerr_wd;
  logic intr_enable_rxerr_we;
  logic intr_test_rxne_wd;
  logic intr_test_rxne_we;
  logic intr_test_rxlvl_wd;
  logic intr_test_rxlvl_we;
  logic intr_test_txe_wd;
  logic intr_test_txe_we;
  logic intr_test_txf_wd;
  logic intr_test_txf_we;
  logic intr_test_txlvl_wd;
  logic intr_test_txlvl_we;
  logic intr_test_rxerr_wd;
  logic intr_test_rxerr_we;
  logic control_abort_qs;
  logic control_abort_wd;
  logic control_abort_we;
  logic [1:0] control_mode_qs;
  logic [1:0] control_mode_wd;
  logic control_mode_we;
  logic control_rst_txfifo_qs;
  logic control_rst_txfifo_wd;
  logic control_rst_txfifo_we;
  logic control_rst_rxfifo_qs;
  logic control_rst_rxfifo_wd;
  logic control_rst_rxfifo_we;
  logic cfg_cpol_qs;
  logic cfg_cpol_wd;
  logic cfg_cpol_we;
  logic cfg_cpha_qs;
  logic cfg_cpha_wd;
  logic cfg_cpha_we;
  logic cfg_tx_order_qs;
  logic cfg_tx_order_wd;
  logic cfg_tx_order_we;
  logic cfg_rx_order_qs;
  logic cfg_rx_order_wd;
  logic cfg_rx_order_we;
  logic [7:0] cfg_timer_v_qs;
  logic [7:0] cfg_timer_v_wd;
  logic cfg_timer_v_we;
  logic [15:0] fifo_level_rxlvl_qs;
  logic [15:0] fifo_level_rxlvl_wd;
  logic fifo_level_rxlvl_we;
  logic [15:0] fifo_level_txlvl_qs;
  logic [15:0] fifo_level_txlvl_wd;
  logic fifo_level_txlvl_we;
  logic [7:0] async_fifo_level_rxlvl_qs;
  logic async_fifo_level_rxlvl_re;
  logic [7:0] async_fifo_level_txlvl_qs;
  logic async_fifo_level_txlvl_re;
  logic status_rxf_full_qs;
  logic status_rxf_full_re;
  logic status_rxf_empty_qs;
  logic status_rxf_empty_re;
  logic status_txf_full_qs;
  logic status_txf_full_re;
  logic status_txf_empty_qs;
  logic status_txf_empty_re;
  logic status_abort_done_qs;
  logic status_abort_done_re;
  logic [15:0] rxf_ptr_rptr_qs;
  logic [15:0] rxf_ptr_rptr_wd;
  logic rxf_ptr_rptr_we;
  logic [15:0] rxf_ptr_wptr_qs;
  logic [15:0] txf_ptr_rptr_qs;
  logic [15:0] txf_ptr_wptr_qs;
  logic [15:0] txf_ptr_wptr_wd;
  logic txf_ptr_wptr_we;
  logic [15:0] rxf_addr_base_qs;
  logic [15:0] rxf_addr_base_wd;
  logic rxf_addr_base_we;
  logic [15:0] rxf_addr_limit_qs;
  logic [15:0] rxf_addr_limit_wd;
  logic rxf_addr_limit_we;
  logic [15:0] txf_addr_base_qs;
  logic [15:0] txf_addr_base_wd;
  logic txf_addr_base_we;
  logic [15:0] txf_addr_limit_qs;
  logic [15:0] txf_addr_limit_wd;
  logic txf_addr_limit_we;

  // Register instances
  // R[intr_state]: V(False)

  //   F[rxne]: 0:0
  prim_subreg #(
    .DW      (1),
    .SWACCESS("W1C"),
    .RESVAL  (1'h0)
  ) u_intr_state_rxne (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_state_rxne_we),
    .wd     (intr_state_rxne_wd),

    // from internal hardware
    .de     (hw2reg.intr_state.rxne.de),
    .d      (hw2reg.intr_state.rxne.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_state.rxne.q ),

    // to register interface (read)
    .qs     (intr_state_rxne_qs)
  );


  //   F[rxlvl]: 1:1
  prim_subreg #(
    .DW      (1),
    .SWACCESS("W1C"),
    .RESVAL  (1'h0)
  ) u_intr_state_rxlvl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_state_rxlvl_we),
    .wd     (intr_state_rxlvl_wd),

    // from internal hardware
    .de     (hw2reg.intr_state.rxlvl.de),
    .d      (hw2reg.intr_state.rxlvl.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_state.rxlvl.q ),

    // to register interface (read)
    .qs     (intr_state_rxlvl_qs)
  );


  //   F[txe]: 2:2
  prim_subreg #(
    .DW      (1),
    .SWACCESS("W1C"),
    .RESVAL  (1'h0)
  ) u_intr_state_txe (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_state_txe_we),
    .wd     (intr_state_txe_wd),

    // from internal hardware
    .de     (hw2reg.intr_state.txe.de),
    .d      (hw2reg.intr_state.txe.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_state.txe.q ),

    // to register interface (read)
    .qs     (intr_state_txe_qs)
  );


  //   F[txf]: 3:3
  prim_subreg #(
    .DW      (1),
    .SWACCESS("W1C"),
    .RESVAL  (1'h0)
  ) u_intr_state_txf (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_state_txf_we),
    .wd     (intr_state_txf_wd),

    // from internal hardware
    .de     (hw2reg.intr_state.txf.de),
    .d      (hw2reg.intr_state.txf.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_state.txf.q ),

    // to register interface (read)
    .qs     (intr_state_txf_qs)
  );


  //   F[txlvl]: 4:4
  prim_subreg #(
    .DW      (1),
    .SWACCESS("W1C"),
    .RESVAL  (1'h0)
  ) u_intr_state_txlvl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_state_txlvl_we),
    .wd     (intr_state_txlvl_wd),

    // from internal hardware
    .de     (hw2reg.intr_state.txlvl.de),
    .d      (hw2reg.intr_state.txlvl.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_state.txlvl.q ),

    // to register interface (read)
    .qs     (intr_state_txlvl_qs)
  );


  //   F[rxerr]: 5:5
  prim_subreg #(
    .DW      (1),
    .SWACCESS("W1C"),
    .RESVAL  (1'h0)
  ) u_intr_state_rxerr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_state_rxerr_we),
    .wd     (intr_state_rxerr_wd),

    // from internal hardware
    .de     (hw2reg.intr_state.rxerr.de),
    .d      (hw2reg.intr_state.rxerr.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_state.rxerr.q ),

    // to register interface (read)
    .qs     (intr_state_rxerr_qs)
  );


  // R[intr_enable]: V(False)

  //   F[rxne]: 0:0
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_intr_enable_rxne (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_enable_rxne_we),
    .wd     (intr_enable_rxne_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_enable.rxne.q ),

    // to register interface (read)
    .qs     (intr_enable_rxne_qs)
  );


  //   F[rxlvl]: 1:1
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_intr_enable_rxlvl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_enable_rxlvl_we),
    .wd     (intr_enable_rxlvl_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_enable.rxlvl.q ),

    // to register interface (read)
    .qs     (intr_enable_rxlvl_qs)
  );


  //   F[txe]: 2:2
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_intr_enable_txe (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_enable_txe_we),
    .wd     (intr_enable_txe_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_enable.txe.q ),

    // to register interface (read)
    .qs     (intr_enable_txe_qs)
  );


  //   F[txf]: 3:3
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_intr_enable_txf (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_enable_txf_we),
    .wd     (intr_enable_txf_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_enable.txf.q ),

    // to register interface (read)
    .qs     (intr_enable_txf_qs)
  );


  //   F[txlvl]: 4:4
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_intr_enable_txlvl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_enable_txlvl_we),
    .wd     (intr_enable_txlvl_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_enable.txlvl.q ),

    // to register interface (read)
    .qs     (intr_enable_txlvl_qs)
  );


  //   F[rxerr]: 5:5
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_intr_enable_rxerr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (intr_enable_rxerr_we),
    .wd     (intr_enable_rxerr_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.intr_enable.rxerr.q ),

    // to register interface (read)
    .qs     (intr_enable_rxerr_qs)
  );


  // R[intr_test]: V(True)

  //   F[rxne]: 0:0
  prim_subreg_ext #(
    .DW    (1)
  ) u_intr_test_rxne (
    .re     (1'b0),
    .we     (intr_test_rxne_we),
    .wd     (intr_test_rxne_wd),
    .d      ('0),
    .qre    (),
    .qe     (reg2hw.intr_test.rxne.qe),
    .q      (reg2hw.intr_test.rxne.q ),
    .qs     ()
  );


  //   F[rxlvl]: 1:1
  prim_subreg_ext #(
    .DW    (1)
  ) u_intr_test_rxlvl (
    .re     (1'b0),
    .we     (intr_test_rxlvl_we),
    .wd     (intr_test_rxlvl_wd),
    .d      ('0),
    .qre    (),
    .qe     (reg2hw.intr_test.rxlvl.qe),
    .q      (reg2hw.intr_test.rxlvl.q ),
    .qs     ()
  );


  //   F[txe]: 2:2
  prim_subreg_ext #(
    .DW    (1)
  ) u_intr_test_txe (
    .re     (1'b0),
    .we     (intr_test_txe_we),
    .wd     (intr_test_txe_wd),
    .d      ('0),
    .qre    (),
    .qe     (reg2hw.intr_test.txe.qe),
    .q      (reg2hw.intr_test.txe.q ),
    .qs     ()
  );


  //   F[txf]: 3:3
  prim_subreg_ext #(
    .DW    (1)
  ) u_intr_test_txf (
    .re     (1'b0),
    .we     (intr_test_txf_we),
    .wd     (intr_test_txf_wd),
    .d      ('0),
    .qre    (),
    .qe     (reg2hw.intr_test.txf.qe),
    .q      (reg2hw.intr_test.txf.q ),
    .qs     ()
  );


  //   F[txlvl]: 4:4
  prim_subreg_ext #(
    .DW    (1)
  ) u_intr_test_txlvl (
    .re     (1'b0),
    .we     (intr_test_txlvl_we),
    .wd     (intr_test_txlvl_wd),
    .d      ('0),
    .qre    (),
    .qe     (reg2hw.intr_test.txlvl.qe),
    .q      (reg2hw.intr_test.txlvl.q ),
    .qs     ()
  );


  //   F[rxerr]: 5:5
  prim_subreg_ext #(
    .DW    (1)
  ) u_intr_test_rxerr (
    .re     (1'b0),
    .we     (intr_test_rxerr_we),
    .wd     (intr_test_rxerr_wd),
    .d      ('0),
    .qre    (),
    .qe     (reg2hw.intr_test.rxerr.qe),
    .q      (reg2hw.intr_test.rxerr.q ),
    .qs     ()
  );


  // R[control]: V(False)

  //   F[abort]: 0:0
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_control_abort (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (control_abort_we),
    .wd     (control_abort_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.control.abort.q ),

    // to register interface (read)
    .qs     (control_abort_qs)
  );


  //   F[mode]: 5:4
  prim_subreg #(
    .DW      (2),
    .SWACCESS("RW"),
    .RESVAL  (2'h0)
  ) u_control_mode (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (control_mode_we),
    .wd     (control_mode_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.control.mode.q ),

    // to register interface (read)
    .qs     (control_mode_qs)
  );


  //   F[rst_txfifo]: 16:16
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_control_rst_txfifo (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (control_rst_txfifo_we),
    .wd     (control_rst_txfifo_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.control.rst_txfifo.q ),

    // to register interface (read)
    .qs     (control_rst_txfifo_qs)
  );


  //   F[rst_rxfifo]: 17:17
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_control_rst_rxfifo (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (control_rst_rxfifo_we),
    .wd     (control_rst_rxfifo_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.control.rst_rxfifo.q ),

    // to register interface (read)
    .qs     (control_rst_rxfifo_qs)
  );


  // R[cfg]: V(False)

  //   F[cpol]: 0:0
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_cfg_cpol (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_cpol_we),
    .wd     (cfg_cpol_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg.cpol.q ),

    // to register interface (read)
    .qs     (cfg_cpol_qs)
  );


  //   F[cpha]: 1:1
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_cfg_cpha (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_cpha_we),
    .wd     (cfg_cpha_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg.cpha.q ),

    // to register interface (read)
    .qs     (cfg_cpha_qs)
  );


  //   F[tx_order]: 2:2
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_cfg_tx_order (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_tx_order_we),
    .wd     (cfg_tx_order_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg.tx_order.q ),

    // to register interface (read)
    .qs     (cfg_tx_order_qs)
  );


  //   F[rx_order]: 3:3
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_cfg_rx_order (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_rx_order_we),
    .wd     (cfg_rx_order_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg.rx_order.q ),

    // to register interface (read)
    .qs     (cfg_rx_order_qs)
  );


  //   F[timer_v]: 15:8
  prim_subreg #(
    .DW      (8),
    .SWACCESS("RW"),
    .RESVAL  (8'h7f)
  ) u_cfg_timer_v (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cfg_timer_v_we),
    .wd     (cfg_timer_v_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cfg.timer_v.q ),

    // to register interface (read)
    .qs     (cfg_timer_v_qs)
  );


  // R[fifo_level]: V(False)

  //   F[rxlvl]: 15:0
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h80)
  ) u_fifo_level_rxlvl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fifo_level_rxlvl_we),
    .wd     (fifo_level_rxlvl_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fifo_level.rxlvl.q ),

    // to register interface (read)
    .qs     (fifo_level_rxlvl_qs)
  );


  //   F[txlvl]: 31:16
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h0)
  ) u_fifo_level_txlvl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fifo_level_txlvl_we),
    .wd     (fifo_level_txlvl_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fifo_level.txlvl.q ),

    // to register interface (read)
    .qs     (fifo_level_txlvl_qs)
  );


  // R[async_fifo_level]: V(True)

  //   F[rxlvl]: 7:0
  prim_subreg_ext #(
    .DW    (8)
  ) u_async_fifo_level_rxlvl (
    .re     (async_fifo_level_rxlvl_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.async_fifo_level.rxlvl.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (async_fifo_level_rxlvl_qs)
  );


  //   F[txlvl]: 23:16
  prim_subreg_ext #(
    .DW    (8)
  ) u_async_fifo_level_txlvl (
    .re     (async_fifo_level_txlvl_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.async_fifo_level.txlvl.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (async_fifo_level_txlvl_qs)
  );


  // R[status]: V(True)

  //   F[rxf_full]: 0:0
  prim_subreg_ext #(
    .DW    (1)
  ) u_status_rxf_full (
    .re     (status_rxf_full_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status.rxf_full.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_rxf_full_qs)
  );


  //   F[rxf_empty]: 1:1
  prim_subreg_ext #(
    .DW    (1)
  ) u_status_rxf_empty (
    .re     (status_rxf_empty_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status.rxf_empty.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_rxf_empty_qs)
  );


  //   F[txf_full]: 2:2
  prim_subreg_ext #(
    .DW    (1)
  ) u_status_txf_full (
    .re     (status_txf_full_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status.txf_full.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_txf_full_qs)
  );


  //   F[txf_empty]: 3:3
  prim_subreg_ext #(
    .DW    (1)
  ) u_status_txf_empty (
    .re     (status_txf_empty_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status.txf_empty.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_txf_empty_qs)
  );


  //   F[abort_done]: 4:4
  prim_subreg_ext #(
    .DW    (1)
  ) u_status_abort_done (
    .re     (status_abort_done_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status.abort_done.d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_abort_done_qs)
  );


  // R[rxf_ptr]: V(False)

  //   F[rptr]: 15:0
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h0)
  ) u_rxf_ptr_rptr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (rxf_ptr_rptr_we),
    .wd     (rxf_ptr_rptr_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.rxf_ptr.rptr.q ),

    // to register interface (read)
    .qs     (rxf_ptr_rptr_qs)
  );


  //   F[wptr]: 31:16
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RO"),
    .RESVAL  (16'h0)
  ) u_rxf_ptr_wptr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.rxf_ptr.wptr.de),
    .d      (hw2reg.rxf_ptr.wptr.d ),

    // to internal hardware
    .qe     (),
    .q      (),

    // to register interface (read)
    .qs     (rxf_ptr_wptr_qs)
  );


  // R[txf_ptr]: V(False)

  //   F[rptr]: 15:0
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RO"),
    .RESVAL  (16'h0)
  ) u_txf_ptr_rptr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.txf_ptr.rptr.de),
    .d      (hw2reg.txf_ptr.rptr.d ),

    // to internal hardware
    .qe     (),
    .q      (),

    // to register interface (read)
    .qs     (txf_ptr_rptr_qs)
  );


  //   F[wptr]: 31:16
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h0)
  ) u_txf_ptr_wptr (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (txf_ptr_wptr_we),
    .wd     (txf_ptr_wptr_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.txf_ptr.wptr.q ),

    // to register interface (read)
    .qs     (txf_ptr_wptr_qs)
  );


  // R[rxf_addr]: V(False)

  //   F[base]: 15:0
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h0)
  ) u_rxf_addr_base (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (rxf_addr_base_we),
    .wd     (rxf_addr_base_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.rxf_addr.base.q ),

    // to register interface (read)
    .qs     (rxf_addr_base_qs)
  );


  //   F[limit]: 31:16
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h1fc)
  ) u_rxf_addr_limit (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (rxf_addr_limit_we),
    .wd     (rxf_addr_limit_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.rxf_addr.limit.q ),

    // to register interface (read)
    .qs     (rxf_addr_limit_qs)
  );


  // R[txf_addr]: V(False)

  //   F[base]: 15:0
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h200)
  ) u_txf_addr_base (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (txf_addr_base_we),
    .wd     (txf_addr_base_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.txf_addr.base.q ),

    // to register interface (read)
    .qs     (txf_addr_base_qs)
  );


  //   F[limit]: 31:16
  prim_subreg #(
    .DW      (16),
    .SWACCESS("RW"),
    .RESVAL  (16'h3fc)
  ) u_txf_addr_limit (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (txf_addr_limit_we),
    .wd     (txf_addr_limit_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.txf_addr.limit.q ),

    // to register interface (read)
    .qs     (txf_addr_limit_qs)
  );



  logic [11:0] addr_hit;
  always_comb begin
    addr_hit = '0;
    addr_hit[0] = (reg_addr == SPI_DEVICE_INTR_STATE_OFFSET);
    addr_hit[1] = (reg_addr == SPI_DEVICE_INTR_ENABLE_OFFSET);
    addr_hit[2] = (reg_addr == SPI_DEVICE_INTR_TEST_OFFSET);
    addr_hit[3] = (reg_addr == SPI_DEVICE_CONTROL_OFFSET);
    addr_hit[4] = (reg_addr == SPI_DEVICE_CFG_OFFSET);
    addr_hit[5] = (reg_addr == SPI_DEVICE_FIFO_LEVEL_OFFSET);
    addr_hit[6] = (reg_addr == SPI_DEVICE_ASYNC_FIFO_LEVEL_OFFSET);
    addr_hit[7] = (reg_addr == SPI_DEVICE_STATUS_OFFSET);
    addr_hit[8] = (reg_addr == SPI_DEVICE_RXF_PTR_OFFSET);
    addr_hit[9] = (reg_addr == SPI_DEVICE_TXF_PTR_OFFSET);
    addr_hit[10] = (reg_addr == SPI_DEVICE_RXF_ADDR_OFFSET);
    addr_hit[11] = (reg_addr == SPI_DEVICE_TXF_ADDR_OFFSET);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tl_addrmiss <= 1'b0;
    end else if (reg_re || reg_we) begin
      tl_addrmiss <= ~|addr_hit;
    end
  end

  // Write Enable signal

  assign intr_state_rxne_we = addr_hit[0] && reg_we;
  assign intr_state_rxne_wd = reg_wdata[0];

  assign intr_state_rxlvl_we = addr_hit[0] && reg_we;
  assign intr_state_rxlvl_wd = reg_wdata[1];

  assign intr_state_txe_we = addr_hit[0] && reg_we;
  assign intr_state_txe_wd = reg_wdata[2];

  assign intr_state_txf_we = addr_hit[0] && reg_we;
  assign intr_state_txf_wd = reg_wdata[3];

  assign intr_state_txlvl_we = addr_hit[0] && reg_we;
  assign intr_state_txlvl_wd = reg_wdata[4];

  assign intr_state_rxerr_we = addr_hit[0] && reg_we;
  assign intr_state_rxerr_wd = reg_wdata[5];

  assign intr_enable_rxne_we = addr_hit[1] && reg_we;
  assign intr_enable_rxne_wd = reg_wdata[0];

  assign intr_enable_rxlvl_we = addr_hit[1] && reg_we;
  assign intr_enable_rxlvl_wd = reg_wdata[1];

  assign intr_enable_txe_we = addr_hit[1] && reg_we;
  assign intr_enable_txe_wd = reg_wdata[2];

  assign intr_enable_txf_we = addr_hit[1] && reg_we;
  assign intr_enable_txf_wd = reg_wdata[3];

  assign intr_enable_txlvl_we = addr_hit[1] && reg_we;
  assign intr_enable_txlvl_wd = reg_wdata[4];

  assign intr_enable_rxerr_we = addr_hit[1] && reg_we;
  assign intr_enable_rxerr_wd = reg_wdata[5];

  assign intr_test_rxne_we = addr_hit[2] && reg_we;
  assign intr_test_rxne_wd = reg_wdata[0];

  assign intr_test_rxlvl_we = addr_hit[2] && reg_we;
  assign intr_test_rxlvl_wd = reg_wdata[1];

  assign intr_test_txe_we = addr_hit[2] && reg_we;
  assign intr_test_txe_wd = reg_wdata[2];

  assign intr_test_txf_we = addr_hit[2] && reg_we;
  assign intr_test_txf_wd = reg_wdata[3];

  assign intr_test_txlvl_we = addr_hit[2] && reg_we;
  assign intr_test_txlvl_wd = reg_wdata[4];

  assign intr_test_rxerr_we = addr_hit[2] && reg_we;
  assign intr_test_rxerr_wd = reg_wdata[5];

  assign control_abort_we = addr_hit[3] && reg_we;
  assign control_abort_wd = reg_wdata[0];

  assign control_mode_we = addr_hit[3] && reg_we;
  assign control_mode_wd = reg_wdata[5:4];

  assign control_rst_txfifo_we = addr_hit[3] && reg_we;
  assign control_rst_txfifo_wd = reg_wdata[16];

  assign control_rst_rxfifo_we = addr_hit[3] && reg_we;
  assign control_rst_rxfifo_wd = reg_wdata[17];

  assign cfg_cpol_we = addr_hit[4] && reg_we;
  assign cfg_cpol_wd = reg_wdata[0];

  assign cfg_cpha_we = addr_hit[4] && reg_we;
  assign cfg_cpha_wd = reg_wdata[1];

  assign cfg_tx_order_we = addr_hit[4] && reg_we;
  assign cfg_tx_order_wd = reg_wdata[2];

  assign cfg_rx_order_we = addr_hit[4] && reg_we;
  assign cfg_rx_order_wd = reg_wdata[3];

  assign cfg_timer_v_we = addr_hit[4] && reg_we;
  assign cfg_timer_v_wd = reg_wdata[15:8];

  assign fifo_level_rxlvl_we = addr_hit[5] && reg_we;
  assign fifo_level_rxlvl_wd = reg_wdata[15:0];

  assign fifo_level_txlvl_we = addr_hit[5] && reg_we;
  assign fifo_level_txlvl_wd = reg_wdata[31:16];

  assign async_fifo_level_rxlvl_re = addr_hit[6] && reg_re;

  assign async_fifo_level_txlvl_re = addr_hit[6] && reg_re;

  assign status_rxf_full_re = addr_hit[7] && reg_re;

  assign status_rxf_empty_re = addr_hit[7] && reg_re;

  assign status_txf_full_re = addr_hit[7] && reg_re;

  assign status_txf_empty_re = addr_hit[7] && reg_re;

  assign status_abort_done_re = addr_hit[7] && reg_re;

  assign rxf_ptr_rptr_we = addr_hit[8] && reg_we;
  assign rxf_ptr_rptr_wd = reg_wdata[15:0];



  assign txf_ptr_wptr_we = addr_hit[9] && reg_we;
  assign txf_ptr_wptr_wd = reg_wdata[31:16];

  assign rxf_addr_base_we = addr_hit[10] && reg_we;
  assign rxf_addr_base_wd = reg_wdata[15:0];

  assign rxf_addr_limit_we = addr_hit[10] && reg_we;
  assign rxf_addr_limit_wd = reg_wdata[31:16];

  assign txf_addr_base_we = addr_hit[11] && reg_we;
  assign txf_addr_base_wd = reg_wdata[15:0];

  assign txf_addr_limit_we = addr_hit[11] && reg_we;
  assign txf_addr_limit_wd = reg_wdata[31:16];

  // Read data return
  logic [DW-1:0] reg_rdata_next;
  always_comb begin
    reg_rdata_next = '0;
    unique case (1'b1)
      addr_hit[0]: begin
        reg_rdata_next[0] = intr_state_rxne_qs;
        reg_rdata_next[1] = intr_state_rxlvl_qs;
        reg_rdata_next[2] = intr_state_txe_qs;
        reg_rdata_next[3] = intr_state_txf_qs;
        reg_rdata_next[4] = intr_state_txlvl_qs;
        reg_rdata_next[5] = intr_state_rxerr_qs;
      end

      addr_hit[1]: begin
        reg_rdata_next[0] = intr_enable_rxne_qs;
        reg_rdata_next[1] = intr_enable_rxlvl_qs;
        reg_rdata_next[2] = intr_enable_txe_qs;
        reg_rdata_next[3] = intr_enable_txf_qs;
        reg_rdata_next[4] = intr_enable_txlvl_qs;
        reg_rdata_next[5] = intr_enable_rxerr_qs;
      end

      addr_hit[2]: begin
        reg_rdata_next[0] = '0;
        reg_rdata_next[1] = '0;
        reg_rdata_next[2] = '0;
        reg_rdata_next[3] = '0;
        reg_rdata_next[4] = '0;
        reg_rdata_next[5] = '0;
      end

      addr_hit[3]: begin
        reg_rdata_next[0] = control_abort_qs;
        reg_rdata_next[5:4] = control_mode_qs;
        reg_rdata_next[16] = control_rst_txfifo_qs;
        reg_rdata_next[17] = control_rst_rxfifo_qs;
      end

      addr_hit[4]: begin
        reg_rdata_next[0] = cfg_cpol_qs;
        reg_rdata_next[1] = cfg_cpha_qs;
        reg_rdata_next[2] = cfg_tx_order_qs;
        reg_rdata_next[3] = cfg_rx_order_qs;
        reg_rdata_next[15:8] = cfg_timer_v_qs;
      end

      addr_hit[5]: begin
        reg_rdata_next[15:0] = fifo_level_rxlvl_qs;
        reg_rdata_next[31:16] = fifo_level_txlvl_qs;
      end

      addr_hit[6]: begin
        reg_rdata_next[7:0] = async_fifo_level_rxlvl_qs;
        reg_rdata_next[23:16] = async_fifo_level_txlvl_qs;
      end

      addr_hit[7]: begin
        reg_rdata_next[0] = status_rxf_full_qs;
        reg_rdata_next[1] = status_rxf_empty_qs;
        reg_rdata_next[2] = status_txf_full_qs;
        reg_rdata_next[3] = status_txf_empty_qs;
        reg_rdata_next[4] = status_abort_done_qs;
      end

      addr_hit[8]: begin
        reg_rdata_next[15:0] = rxf_ptr_rptr_qs;
        reg_rdata_next[31:16] = rxf_ptr_wptr_qs;
      end

      addr_hit[9]: begin
        reg_rdata_next[15:0] = txf_ptr_rptr_qs;
        reg_rdata_next[31:16] = txf_ptr_wptr_qs;
      end

      addr_hit[10]: begin
        reg_rdata_next[15:0] = rxf_addr_base_qs;
        reg_rdata_next[31:16] = rxf_addr_limit_qs;
      end

      addr_hit[11]: begin
        reg_rdata_next[15:0] = txf_addr_base_qs;
        reg_rdata_next[31:16] = txf_addr_limit_qs;
      end

      default: begin
        reg_rdata_next = '1;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reg_valid <= 1'b0;
      reg_rdata <= '0;
      rsp_opcode <= tlul_pkg::AccessAck;
    end else if (reg_re || reg_we) begin
      // Guarantee to return data in a cycle
      reg_valid <= 1'b1;
      if (reg_re) begin
        reg_rdata <= reg_rdata_next;
        rsp_opcode <= tlul_pkg::AccessAckData;
      end else begin
        rsp_opcode <= tlul_pkg::AccessAck;
      end
    end else if (tl_reg_h2d.d_ready) begin
      reg_valid <= 1'b0;
    end
  end

  // Outstanding: 1 outstanding at a time. Identical to `reg_valid`
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      outstanding <= 1'b0;
    end else if (tl_reg_h2d.a_valid && tl_reg_d2h.a_ready) begin
      outstanding <= 1'b1;
    end else if (tl_reg_d2h.d_valid && tl_reg_h2d.d_ready) begin
      outstanding <= 1'b0;
    end
  end

  // Assertions for Register Interface
  `ASSERT_PULSE(wePulse, reg_we, clk_i, !rst_ni)
  `ASSERT_PULSE(rePulse, reg_re, clk_i, !rst_ni)

  `ASSERT(reAfterRv, $rose(reg_re || reg_we) |=> reg_valid, clk_i, !rst_ni)

  `ASSERT(en2addrHit, (reg_we || reg_re) |-> $onehot0(addr_hit), clk_i, !rst_ni)

  `ASSERT(reqParity, tl_reg_h2d.a_valid |-> tl_reg_h2d.a_user.parity_en == 1'b0, clk_i, !rst_ni)

endmodule
