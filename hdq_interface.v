`timescale 1ns / 1ps

module hdq_interface(
	input	clk,                  //系统采样时钟 133MHz
	input	clk_ref,              //串行参考时钟 1us
	input rst,                  //Active High
	input	start,	             //start一次上升沿得到一个数据
	inout DQ,                	 //1-WIRE DATA BUS
	input [7:0]addr,            //需要读的寄存器地址
	output	reg	done,
	output	reg	[7:0]	data_out
    );
	 
	 
//状态
reg [2:0]state;  
localparam IDLE  		 = 3'b001;
localparam BREAK 		 = 3'b010;
localparam WRITE 		 = 3'b011;
localparam RESPONSE	 = 3'b100;
localparam READ		 = 3'b101;
localparam DONE		 = 3'b110;
//发送7位地址+1位R/W 	
wire [7:0]cmd;   
assign cmd[6:0] = addr[6:0];
assign cmd[7]   = 1'b0;
	 
	wire	dq_in;
	reg	dq_out;
	reg	pullup_en;				   //Active 0， 释放总线
	IOBUF #(
      .DRIVE(12), // Specify the output drive strength
     // .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE" 
      .IOSTANDARD("DEFAULT"), // Specify the I/O standard
      .SLEW("SLOW") // Specify the output slew rate
   ) IOBUF_inst (
      .O(dq_in),     // Buffer output
      .IO(DQ),   // Buffer inout port (connect directly to top-level port)
      .I(dq_out),     // Buffer input
      .T(~pullup_en)      // 3-state enable input, high=input, low=output
   );
	
	reg	[19:0]	cnt;
	reg   [3:0]    write_cnt;
	reg   [3:0]    read_cnt;
	reg  read_rst;
	reg  bit_ready;
	
	
	
	
reg	clk_ref_dly1,clk_ref_dly2;

always @(posedge clk)
begin
	clk_ref_dly1 <= clk_ref;
	clk_ref_dly2 <= clk_ref_dly1;
end

//main
always @(posedge clk)
begin
	if(rst)	state<=IDLE;
	else if(clk_ref_dly2 == 1'b0 && clk_ref_dly1 == 1'b1)
		begin

			begin
				case(state)
				IDLE:begin
						dq_out		<=	0;
						pullup_en	<=	0;                //HOST释放总线
						cnt<=0;
						write_cnt	<=0;
						read_cnt		<=0;
						read_rst    <=0;
						data_out    <=8'h00;
						done<=1'b0;
						if(start==1'b1)state<=BREAK;
				end
				//HOST  ▔|_________|▔▔▔     
				//            250      50
				BREAK:begin                            
						cnt<=cnt+1;
						pullup_en	<=	1;						//HOST占用总线，发送BREAK信号
						if(cnt>=50  && cnt<250)  dq_out	<=	0;
						if(cnt>=250 && cnt<300)  dq_out	<=	1;
						if(cnt==300)
							begin cnt<=0;state<=WRITE;end
				end
				//HOST  ▔▔▔|____|-----▔▔▔
				//        50    40   60    100 
				WRITE:begin
						cnt<=cnt+1;	
						if(write_cnt<=7)
							case (cnt)
								50:	dq_out	<=	1'b0;
								90:  	dq_out	<=	cmd[write_cnt];   //write_cnt values from 0~7
								150:	dq_out	<=	1'b1;
								250:  begin write_cnt<=write_cnt+1;cnt<=0;end
								default:;
							endcase
						else
							begin
							state<=RESPONSE;
							cnt<=0;
							end
				end
				//SLAVE ▔▔▔▔▔|__
				//          190
				RESPONSE:begin
							cnt<=cnt+1;	
							pullup_en	<=	0;					//HOST释放总线，等待RESPONSE
							if(cnt>=190 && dq_in==1'b0)
								begin
								state<=READ;
								cnt<=0;
								end
				end
				//SLAVE ▔▔|____|-----
				//            40   20↑ 
				READ:	begin
						if(bit_ready==1'b1)	cnt<=cnt+1;	
						if(cnt==60) 
							begin 
								data_out[read_cnt]<=dq_in; 
								read_cnt<=read_cnt+1;
								read_rst<=1'b1;
								cnt<=cnt+1;
							end
						if(cnt==61)
							begin cnt<=0; read_rst<=1'b0;end
						if (read_cnt>=8) state<=DONE;
				end  
				DONE:begin
						done<=1'b1;
						if(rst)state<=IDLE;
				end
				default: state<=IDLE;
				endcase
		end
	end
end
//读数据时，在dq_in下降沿到来后的60us时捕获
always@(negedge dq_in or posedge read_rst)
begin
	if(read_rst==1'b1)
		bit_ready<=1'b0;
	else if(state==RESPONSE||state==READ)
		bit_ready<=1'b1;
end

endmodule
