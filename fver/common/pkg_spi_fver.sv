`timescale 1ns/1ps


interface spi_intf(
	output logic CS_N, // SPI Chip select (active-low)
	output logic SCK , // SPI clock
	// output logic COPI, // SPI Controller Out Peripheral In
	// input  logic CIPO  // SPI Controller In Peripheral Out
	output logic [3:0] COPI,
	input  logic [3:0] CIPO
);
endinterface : spi_intf


package pkg_spi_fver;

	typedef enum { 
		READ_BT, READ_HW, READ_WD, READ_DW, 
		WRITE_BT, WRITE_HW, WRITE_WD, WRITE_DW //read FIFO instead of WriteDW, saves spi functionality
	} spi_op_t;


	class class_spi_ctrl;
		virtual spi_intf spi;

		parameter CLK_P_SPI = 12.5; //25ns clock period
		// parameter CLK_P_SPI = 100ns;

		function new(virtual spi_intf intf);
			spi = intf;
		endfunction

		task automatic init();
			spi.CS_N = 1'b1;
			spi.SCK  = 1'b0;
			spi.COPI = 4'b0000;
			#(CLK_P_SPI);
		endtask

		task automatic trans (
				input  spi_op_t     op_t,
				input  logic [ 7:0] addr,
				input  logic [31:0] data,
				input  logic [31:0] expected_data=32'b0
			);

			// logic [ 7:0] op = int'(op_t); 
			logic [7:0] ad_0 = addr;		//channel 1 - [xxxd_dddd]
			logic [7:0] op_0 = int'(op_t); 	//channel 0 - [xxxx_xddd]
			
			logic [7:0] da_3 = data[31:24];
			logic [7:0] da_2 = data[23:16];
			logic [7:0] da_1 = data[ 15:8];
			logic [7:0] da_0 = data[  7:0];

			// logic [15:0] tx_bits;
			logic [ 7:0] rx_3 = '0;
			logic [ 7:0] rx_2 = '0;
			logic [ 7:0] rx_1 = '0;
			logic [ 7:0] rx_0 = '0;
			logic [31:0] rx_bits = '0;

			// int total_num_bits = 8*$pow(2, op_0[1:0]);
			int total_num_bits = 8 << op_0[1:0];
			int send_op_addr_size = 8;
			int send_data_size = 8;

			spi.CS_N = 0;
			#CLK_P_SPI;

			// Send Op and Addr -- 8 cycles
			for (int i = 0; i < send_op_addr_size; i++) begin
				spi.COPI[1] = ad_0[send_op_addr_size-1-i];
				spi.COPI[0] = op_0[send_op_addr_size-1-i];
				#CLK_P_SPI;
				spi.SCK = 1;
				#CLK_P_SPI;
				spi.SCK = 0;
			end

			for (int i = 0; i < send_data_size; i++) begin
				spi.COPI[3] = da_3[send_data_size-1-i];
				spi.COPI[2] = da_2[send_data_size-1-i];
				spi.COPI[1] = da_1[send_data_size-1-i];
				spi.COPI[0] = da_0[send_data_size-1-i];
				#CLK_P_SPI;
				spi.SCK = 1; //rising edge send in
				// rx_bits = {rx_bits[31:0], spi.CIPO};
				rx_3 = {rx_3[6:0],spi.CIPO[3]};
				rx_2 = {rx_2[6:0],spi.CIPO[2]};
				rx_1 = {rx_1[6:0],spi.CIPO[1]};
				rx_0 = {rx_0[6:0],spi.CIPO[0]};
				// rx_bits = { //falling edge send out
				// 	{rx_3[6:0],spi.CIPO[3]},
				// 	{rx_2[6:0],spi.CIPO[2]},
				// 	{rx_1[6:0],spi.CIPO[1]},
				// 	{rx_0[6:0],spi.CIPO[0]} 
				// };
				#CLK_P_SPI;
				spi.SCK = 0;
			end

			rx_bits = {rx_3, rx_2, rx_1, rx_0};

			#CLK_P_SPI;
			spi.CS_N = 1;
			#CLK_P_SPI;
			$display ("RX Data=%h  , Addr=%d", rx_bits, ad_0);
			$display ("     Da3=%h", rx_3);
			$display ("     Da2=%h", rx_2);
			$display ("     Da1=%h", rx_1);
			$display ("     Da0=%h", rx_0);
			//TODO: assert data is ready at spi.WE == 1 state
			// $display ("[ERROR!] ADDR %d, RX Data=%h, Expected Data=%h", addr, rx_bits, expected_data);
			
			if (rx_bits != expected_data)
				 begin
					$display ("[ERROR!] ADDR %d, RX Data=%h, Expected Data=%h", 
					addr, rx_bits, expected_data);
					$stop;
				end
		endtask : trans

	endclass : class_spi_ctrl

endpackage : pkg_spi_fver
