`timescale 1ns/1ps


interface spi_intf(
	output logic CS_N, // SPI Chip select (active-low)
	output logic SCK , // SPI clock
	output logic COPI, // SPI Controller Out Peripheral In
	input  logic CIPO  // SPI Controller In Peripheral Out
);
endinterface : spi_intf


package pkg_spi_fver;

	typedef enum { 
		READ_BT, READ_HW, READ_WD, READ_DW, 
		WRITE_BT, WRITE_HW, WRITE_WD, WRITE_DW
	} spi_op_t;


	class class_spi_ctrl;
		virtual spi_intf spi;

		parameter CLK_P_SPI = 100ns;

		function new(virtual spi_intf intf);
			spi = intf;
		endfunction

		task automatic init();
			spi.CS_N = 1'b1;
			spi.SCK  = 1'b0;
			spi.COPI = 1'b0;
			#(CLK_P_SPI);
		endtask

		task automatic trans (
				input  spi_op_t     op_t,
				input  logic [ 7:0] addr,
				input  logic [31:0] data,
				input  logic [31:0] expected_data=32'b0
			);

			logic [ 7:0] op = int'(op_t);
			logic [15:0] tx_bits;
			logic [31:0] rx_bits = '0;

			int num_bits = 8*$pow(2, op[1:0]);
			tx_bits = {op, addr};

			spi.CS_N = 0;
			#CLK_P_SPI;

			// Send Op and Addr
			for (int i = 0; i < 16; i++) begin
				spi.COPI = tx_bits[15-i];
				#CLK_P_SPI;
				spi.SCK = 1;
				#CLK_P_SPI;
				spi.SCK = 0;
			end

			// Data
			for (int i = 0; i < num_bits; i++) begin
				spi.COPI = data[num_bits-1-i];
				#CLK_P_SPI;
				spi.SCK = 1;
				rx_bits = {rx_bits[31:0], spi.CIPO};
				#CLK_P_SPI;
				spi.SCK = 0;
			end

			#CLK_P_SPI;
			spi.CS_N = 1;

			#CLK_P_SPI;

			assert (rx_bits == expected_data)
				else begin
					$display ("[ERROR!] ADDR %d, RX Data=%h, Expected Data=%h", 
					addr, rx_bits, expected_data);
				end
		endtask : trans

	endclass : class_spi_ctrl

endpackage : pkg_spi_fver
