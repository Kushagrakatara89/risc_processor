//00 - normal flow, 01 - jal, 10 - jlr,  jri,  beq

module branch_jump_controller (pc_control_from_ex, pc_control_from_id, pc_select);

input [1:0] pc_control_from_ex, pc_control_from_id ;
output reg [1:0] pc_select;

always @(*)
	begin
		if( pc_control_from_id == 2'b01 )	 
		  pc_select = 2'b01;		
		else if ( pc_control_from_ex == 2'b10 )
		  pc_select = 2'b10;		
		else
		 pc_select = 2'b00;			
	end	
endmodule





