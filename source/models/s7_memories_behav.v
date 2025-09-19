`ifndef GF22

  //
  // Copyright (c) 2016-2019 SiFive, Inc. -- Proprietary and Confidential
  // All Rights Reserved.
  //
  // NOTICE: All information contained herein is, and remains the
  // property of SiFive, Inc. The intellectual and technical concepts
  // contained herein are proprietary to SiFive, Inc. and may be covered
  // by U.S. and Foreign Patents, patents in process, and are protected by
  // trade secret or copyright law.
  //
  // This work may not be copied, modified, re-published, uploaded,
  // executed, or distributed in any way, in any medium, whether in whole
  // or in part, without prior written permission from SiFive, Inc.
  //
  // The copyright notice above does not evidence any actual or intended
  // publication or disclosure of this source code, which includes
  // information that is confidential and/or proprietary, and is a trade
  // secret, of SiFive, Inc.
  //

  module base_table_0_ext(
    input RW0_clk,
    input [7:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [8:0] RW0_wmask,
    input [8:0] RW0_wdata,
    output [8:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [7:0] reg_RW0_addr;
    reg [8:0] ram [255:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 256; initvar = initvar+1)
          ram[initvar] = {1 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<9;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*1 +: 1] <= RW0_wdata[i*1 +: 1];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [31:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[8:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  
  module tagged_tables_0_ext(
    input RW0_clk,
    input [8:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [11:0] RW0_wmask,
    input [11:0] RW0_wdata,
    output [11:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [8:0] reg_RW0_addr;
    reg [11:0] ram [511:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 512; initvar = initvar+1)
          ram[initvar] = {1 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<12;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*1 +: 1] <= RW0_wdata[i*1 +: 1];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [31:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[11:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  module tag_array_ext(
    input RW0_clk,
    input [6:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [3:0] RW0_wmask,
    input [79:0] RW0_wdata,
    output [79:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [6:0] reg_RW0_addr;
    reg [79:0] ram [127:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 128; initvar = initvar+1)
          ram[initvar] = {3 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<4;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*20 +: 20] <= RW0_wdata[i*20 +: 20];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [95:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random, $random, $random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random, $random, $random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[79:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  module data_arrays_0_0_ext(
    input RW0_clk,
    input [8:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [0:0] RW0_wmask,
    input [63:0] RW0_wdata,
    output [63:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [8:0] reg_RW0_addr;
    reg [63:0] ram [511:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 512; initvar = initvar+1)
          ram[initvar] = {2 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<1;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*64 +: 64] <= RW0_wdata[i*64 +: 64];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [63:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random, $random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random, $random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[63:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  module data_arrays_0_ext(
    input RW0_clk,
    input [9:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [31:0] RW0_wmask,
    input [255:0] RW0_wdata,
    output [255:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [9:0] reg_RW0_addr;
    reg [255:0] ram [1023:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 1024; initvar = initvar+1)
          ram[initvar] = {8 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<32;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*8 +: 8] <= RW0_wdata[i*8 +: 8];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [255:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random, $random, $random, $random, $random, $random, $random, $random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random, $random, $random, $random, $random, $random, $random, $random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[255:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  module tag_array_0_ext(
    input RW0_clk,
    input [6:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [3:0] RW0_wmask,
    input [83:0] RW0_wdata,
    output [83:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [6:0] reg_RW0_addr;
    reg [83:0] ram [127:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 128; initvar = initvar+1)
          ram[initvar] = {3 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<4;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*21 +: 21] <= RW0_wdata[i*21 +: 21];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [95:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random, $random, $random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random, $random, $random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[83:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  module testharness_ext(
    input RW0_clk,
    input [25:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [7:0] RW0_wmask,
    input [63:0] RW0_wdata,
    output [63:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [25:0] reg_RW0_addr;
    reg [63:0] ram [67108863:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 67108864; initvar = initvar+1)
          ram[initvar] = {2 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<8;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*8 +: 8] <= RW0_wdata[i*8 +: 8];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [63:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random, $random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random, $random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[63:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule
  module testharness_0_ext(
    input RW0_clk,
    input [25:0] RW0_addr,
    input RW0_en,
    input RW0_wmode,
    input [7:0] RW0_wmask,
    input [63:0] RW0_wdata,
    output [63:0] RW0_rdata
  );

    reg reg_RW0_ren;
    reg [25:0] reg_RW0_addr;
    reg [63:0] ram [67108863:0];
    `ifdef RANDOMIZE_MEM_INIT
      integer initvar;
      initial begin
        #`RANDOMIZE_DELAY begin end
        for (initvar = 0; initvar < 67108864; initvar = initvar+1)
          ram[initvar] = {2 {$random}};
        reg_RW0_addr = {1 {$random}};
      end
    `endif
    integer i;
    always @(posedge RW0_clk)
      reg_RW0_ren <= RW0_en && !RW0_wmode;
    always @(posedge RW0_clk)
      if (RW0_en && !RW0_wmode) reg_RW0_addr <= RW0_addr;
    always @(posedge RW0_clk)
      if (RW0_en && RW0_wmode) begin
        for(i=0;i<8;i=i+1) begin
          if(RW0_wmask[i]) begin
            ram[RW0_addr][i*8 +: 8] <= RW0_wdata[i*8 +: 8];
          end
        end
      end
    `ifdef RANDOMIZE_GARBAGE_ASSIGN
    reg [63:0] RW0_random;
    `ifdef RANDOMIZE_MEM_INIT
      initial begin
        #`RANDOMIZE_DELAY begin end
        RW0_random = {$random, $random};
        reg_RW0_ren = RW0_random[0];
      end
    `endif
    always @(posedge RW0_clk) RW0_random <= {$random, $random};
    assign RW0_rdata = reg_RW0_ren ? ram[reg_RW0_addr] : RW0_random[63:0];
    `else
    assign RW0_rdata = ram[reg_RW0_addr];
    `endif

  endmodule

`endif
