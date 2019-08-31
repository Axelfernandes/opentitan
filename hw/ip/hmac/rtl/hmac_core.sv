// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// HMAC Core implementation

module hmac_core import hmac_pkg::*; (
  input clk_i,
  input rst_ni,

  input [255:0] secret_key, // {word0, word1, ..., word7}

  input        wipe_secret,
  input [31:0] wipe_v,

  input        hmac_en,

  input        reg_hash_start,
  input        reg_hash_process,
  output logic hash_done,
  output logic sha_hash_start,
  output logic sha_hash_process,
  input        sha_hash_done,

  // fifo
  output logic      sha_rvalid,
  output sha_fifo_t sha_rdata,
  input             sha_rready,

  input             fifo_rvalid,
  input  sha_fifo_t fifo_rdata,
  output logic      fifo_rready,

  // fifo control (select and fifo write data)
  output logic       fifo_wsel,    // 0: from reg, 1: from digest
  output logic       fifo_wvalid,
  output logic [2:0] fifo_wdata_sel, // 0: digest[0] .. 7: digest[7]
  input              fifo_wready,

  input  [63:0] message_length,
  output [63:0] sha_message_length
);

  localparam BlockSize = 512;
  localparam BlockSizeBits = $clog2(BlockSize);
  localparam HashWordBits = $clog2($bits(sha_word_t));

  logic hash_start; // generated from internal state machine
  logic hash_process; // generated from internal state machine to trigger hash
  logic hmac_hash_done;

  logic [BlockSize-1:0] i_pad ;
  logic [BlockSize-1:0] o_pad ;

  logic [63:0] txcount;
  logic [BlockSizeBits-HashWordBits-1:0] pad_index;
  logic clr_txcount, inc_txcount;

  logic hmac_sha_rvalid;

  typedef enum logic [1:0] {
    SelIPad,
    SelOPad,
    SelFifo
  } sel_rdata_t;

  sel_rdata_t sel_rdata;

  typedef enum logic {
    SelIPadMsg,
    SelOPadMsg
  } sel_msglen_t;

  sel_msglen_t sel_msglen;

  typedef enum logic {
    Inner,  // Update when state goes to StIPad
    Outer   // Update when state enters StOPad
  } round_t ;

  logic update_round ;
  round_t round, round_next;

  typedef enum logic [2:0] {
    StIdle,
    StIPad,
    StMsg,              // Actual Msg, and Digest both
    StPushToMsgFifo,    // Digest --> Msg Fifo
    StWaitResp,         // Hash done( by checking processed_length? or hash_done)
    StOPad,
    StDone              // hmac_done
  } st_e ;

  st_e st, st_next;

  logic clr_fifo_wdata_sel;
  logic txcnt_eq_blksz ;

  logic reg_hash_process_flag;

  assign sha_hash_start   = (hmac_en) ? hash_start                       : reg_hash_start ;
  assign sha_hash_process = (hmac_en) ? reg_hash_process | hash_process  : reg_hash_process ;
  assign hash_done        = (hmac_en) ? hmac_hash_done                   : sha_hash_done  ;

  assign pad_index = txcount[BlockSizeBits-1:HashWordBits];

  assign i_pad = {secret_key, {(BlockSize-256){1'b0}}} ^ {(BlockSize/8){8'h36}};
  assign o_pad = {secret_key, {(BlockSize-256){1'b0}}} ^ {(BlockSize/8){8'h5c}};


  assign fifo_rready  = (hmac_en) ? (st == StMsg) & sha_rready : sha_rready ;
  // sha_rvalid is controlled by State Machine below.
  assign sha_rvalid = (!hmac_en) ? fifo_rvalid : hmac_sha_rvalid ;
  assign sha_rdata =
    (!hmac_en)             ? fifo_rdata                                               :
    (sel_rdata == SelIPad) ? '{data: i_pad[(BlockSize-1)-32*pad_index-:32], mask: '1} :
    (sel_rdata == SelOPad) ? '{data: o_pad[(BlockSize-1)-32*pad_index-:32], mask: '1} :
    (sel_rdata == SelFifo) ? fifo_rdata                                               :
    '{default: '0};

  // TODO: Block size and hash size can differ based on the hash algorithm.
  //       Shall this be flexible or HMAC sticks to SHA256 always?
  assign sha_message_length = (!hmac_en)                 ? message_length             :
                              (sel_msglen == SelIPadMsg) ? message_length + BlockSize :
                              (sel_msglen == SelOPadMsg) ? BlockSize + 256            :
                              '0 ;

  assign txcnt_eq_blksz = (txcount[BlockSizeBits:0] == BlockSize);

  assign inc_txcount = sha_rready && sha_rvalid;

  // txcount
  //    Looks like txcount can be removed entirely here in hmac_core
  //    In the first round (InnerPaddedKey), it can just watch process and hash_done
  //    In the second round, it only needs count 256 bits for hash digest to trigger
  //    hash_process to SHA2
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      txcount <= '0;
    end else if (clr_txcount) begin
      txcount <= '0;
    end else if (inc_txcount) begin
      txcount[63:5] <= txcount[63:5] + 1'b1;
    end
  end

  // reg_hash_process trigger logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      reg_hash_process_flag <= 1'b0;
    end else if (reg_hash_process) begin
      reg_hash_process_flag <= 1'b1;
    end else if (hmac_hash_done || reg_hash_start) begin
      reg_hash_process_flag <= 1'b0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      round <= Inner;
    end else if (update_round) begin
      round <= round_next;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fifo_wdata_sel <= 3'h 0;
    end else if (clr_fifo_wdata_sel) begin
      fifo_wdata_sel <= 3'h 0;
    end else if (fifo_wsel && fifo_wvalid) begin
      fifo_wdata_sel <= fifo_wdata_sel + 1'b1;
    end
  end

  assign sel_msglen = (round == Inner) ? SelIPadMsg : SelOPadMsg ;

  always_ff @(posedge clk_i or negedge rst_ni) begin : state_ff
    if (!rst_ni) st <= StIdle;
    else         st <= st_next;
  end

  always_comb begin : next_state
    hmac_hash_done  = 1'b0;
    hmac_sha_rvalid = 1'b0;

    clr_txcount = 1'b0;

    update_round = 1'b0;
    round_next = Inner;

    fifo_wsel    = 1'b0;   // from register
    fifo_wvalid  = 1'b0;

    clr_fifo_wdata_sel = 1'b1;

    sel_rdata = SelFifo;

    hash_start = 1'b0;
    hash_process = 1'b0;

    unique case (st)
      StIdle: begin
        if (hmac_en && reg_hash_start) begin
          st_next = StIPad;

          clr_txcount = 1'b1;
          update_round = 1'b1;
          round_next = Inner;
          hash_start = 1'b1;
        end else begin
          st_next = StIdle;
        end
      end

      StIPad: begin
        sel_rdata = SelIPad;

        if (txcnt_eq_blksz) begin
          st_next = StMsg;

          hmac_sha_rvalid = 1'b0; // block new read request
        end else begin
          st_next = StIPad;

          hmac_sha_rvalid = 1'b1;
        end
      end

      StMsg: begin
        sel_rdata = SelFifo;

        if ( (((round == Inner) && reg_hash_process_flag) || (round == Outer))
            && (txcount >= sha_message_length)) begin
          st_next = StWaitResp;

          hmac_sha_rvalid = 1'b0; // block
          hash_process = (round == Outer);
        end else begin
          st_next = StMsg;

          hmac_sha_rvalid = fifo_rvalid;
        end
      end

      StWaitResp: begin
        hmac_sha_rvalid = 1'b0;

        if (sha_hash_done) begin
          if (round == Outer) begin
            st_next = StDone;
          end else begin // round == Inner
            st_next = StPushToMsgFifo;
          end
        end else begin
          st_next = StWaitResp;
        end
      end

      StPushToMsgFifo: begin
        // TODO: Accelerate by parallel process of PushToMsgFifo and OPad hash
        hmac_sha_rvalid = 1'b0;
        fifo_wsel = 1'b1;
        fifo_wvalid  = 1'b1;
        clr_fifo_wdata_sel = 1'b0;

        if (fifo_wready && fifo_wdata_sel == 3'h7) begin
          st_next = StOPad;

          clr_txcount = 1'b1;
          update_round = 1'b1;
          round_next = Outer;
          hash_start = 1'b1;
        end else begin
          st_next = StPushToMsgFifo;

        end
      end

      StOPad: begin
        sel_rdata = SelOPad;

        if (txcnt_eq_blksz) begin
          st_next = StMsg;

          hmac_sha_rvalid = 1'b0; // block new read request
        end else begin
          st_next = StOPad;

          hmac_sha_rvalid = 1'b1;
        end
      end

      StDone: begin
        // raise interrupt (hash_done)
        st_next = StIdle;

        hmac_hash_done = 1'b1;
      end

      default: begin
        st_next = StIdle;
      end

    endcase
  end
endmodule
