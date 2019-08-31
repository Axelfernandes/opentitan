// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class uart_env_cov extends cip_base_env_cov #(.CFG_T(uart_env_cfg));
  `uvm_component_utils(uart_env_cov)

  covergroup fifo_level_cg with function sample(uart_dir_e dir, int lvl);
    cp_dir: coverpoint dir;
    cp_lvl: coverpoint lvl {
      bins all_levels[] = {[0:UART_FIFO_DEPTH]};
    }
    cross cp_dir, cp_lvl;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    fifo_level_cg = new();
  endfunction : new

endclass
