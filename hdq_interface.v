`timescale 1ns / 1ps

module hdq_interface(
	input	clk,                  //ϵͳ����ʱ�� 133MHz
	input	clk_ref,              //���вο�ʱ�� 1us
	input rst,                  //Active High
	input	start,	             //startһ�������صõ�һ������
	inout DQ,                	 //1-WIRE DATA BUS
	input [7:0]addr,            //��Ҫ���ļĴ�����ַ
	output	reg	done,
	output	reg	[7:0]	data_out
    );
	 
	 
//״̬
reg [2:0]state;  
localparam IDLE  		 = 3'b001;
localparam BREAK 		 = 3'b010;
localparam WRITE 		 = 3'b011;
localparam RESPONSE	 = 3'b100;
localparam READ		 = 3'b101;
localparam DONE		 = 3'b110;
//����7λ��ַ+1λR/W 	
wire [7:0]cmd;   
assign cmd[6:0] = addr[6:0];
assign cmd[7]   = 1'b0;
	 
	wire	dq_in;
	reg	dq_out;
	reg	pullup_en;				   //Active 0�� �ͷ�����
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
						pullup_en	<=	0;                //HOST�ͷ�����
						cnt<=0;
						write_cnt	<=0;
						read_cnt		<=0;
						read_rst    <=0;
						data_out    <=8'h00;
						done<=1'b0;
						if(start==1'b1)state<=BREAK;
				end
				//HOST  ��|_________|������     
				//            250      50
				BREAK:begin                            
						cnt<=cnt+1;
						pullup_en	<=	1;						//HOSTռ�����ߣ�����BREAK�ź�
						if(cnt>=50  && cnt<250)  dq_out	<=	0;
						if(cnt>=250 && cnt<300)  dq_out	<=	1;
						if(cnt==300)
							begin cnt<=0;state<=WRITE;end
				end
				//HOST  ������|____|-----������
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
				//SLAVE ����������|__
				//          190
				RESPONSE:begin
							cnt<=cnt+1;	
							pullup_en	<=	0;					//HOST�ͷ����ߣ��ȴ�RESPONSE
							if(cnt>=190 && dq_in==1'b0)
								begin
								state<=READ;
								cnt<=0;
								end
				end
				//SLAVE ����|____|-----
				//            40   20�� 
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
//������ʱ����dq_in�½��ص������60usʱ����
always@(negedge dq_in or posedge read_rst)
begin
	if(read_rst==1'b1)
		bit_ready<=1'b0;
	else if(state==RESPONSE||state==READ)
		bit_ready<=1'b1;
end

endmodule
