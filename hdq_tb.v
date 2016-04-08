`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   15:20:28 04/06/2016
// Design Name:   hdq_interface
// Module Name:   F:/FPGA_Projects/Modules/hdq_interface/hdq_interface/hdq_tb.v
// Project Name:  hdq_interface
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: hdq_interface
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module hdq_tb;

	// Inputs
	reg clk;
	reg clk_ref;
	reg rst;
	reg start;
	reg [7:0] addr;

	// Outputs
	wire done;
	wire [7:0] data_out;

	// Bidirs
	wire DQ;
	
	
	// Instantiate the Unit Under Test (UUT)
	hdq_interface uut (
		.clk(clk), 
		.clk_ref(clk_ref), 
		.rst(rst), 
		.start(start), 
		.DQ(DQ), 
		.addr(addr), 
		.done(done), 
		.data_out(data_out)
	);
	integer i;
	reg out_temp;
	initial begin
		forever #10 clk=~clk;				 
	end
	initial begin
		forever #500 clk_ref=~clk_ref;   //1us clk
	end

	initial begin
		// Initialize Inputs
		clk = 0;
		clk_ref = 0;
		rst = 0;
		start = 0;
		addr = 0;
		out_temp=0;

		// Wait 100 ns for global reset to finish
		#100 addr  = 8'b0010_1111;
		#1000 start = 1;  //1us
		#10000 start = 0;
		#2311510 force DQ=1;//resoonse
		#500000  ;
		for(i=0;i<=7;i=i+1)
		begin
						force   DQ=0;  
			#40000   force   DQ=out_temp; 
			#60000   force   DQ=1;  out_temp=~out_temp;
			#100000 ;  
		end   
		
		
		#1000000 rst=1;
		
		
		
		
        
		// Add stimulus here

	end
      
endmodule

