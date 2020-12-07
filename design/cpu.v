module cardinal_processor(
		input clk          ,             // System Clock
		input reset        ,           // System Reset
		input [0:31]instruction  ,     // Instruction from Instruction Memory
		input [0:63]dataIn       ,          // Data from Data Memory
		output [0:31]pc           ,  // Program Counter
		output [0:63]dataOut      ,         // Write Data to Data Memory
		output [0:31]memAddr      ,         // Write Address for Data Memory 
		output memEn        ,           // Data Memory Enable
		output memWrEn                // Data Memory Write Enable 
	);
	// memEn and memWrEn is 1,1 : write mode   (dataOut, memAddr)
	// memEn and memWrEn is 1,0 : read mode    (dataIn,  memAddr)
	
	reg [0:63] REG_FILE [0:31];
	wire clk_n;
	assign clk_n = ~clk;
	
	//IF stage signal
	reg [0:31] pc_count;
	reg [0:31] ins;
	
	//ID stage signal
	//In ID stage we get the instruction and deocde it.
	wire r_type, m_type;
	wire [0:4] ID_rd, ID_ra, ID_rb, ID_shift_amount;
	wire [0:63] rd_content;
	wire [0:15] ID_IMME;
	wire [0:2] ID_PPP;
	wire [0:1] ID_WW;
	wire ID_AND, ID_OR, ID_XOR, ID_NOT, ID_MOV, ID_ADD, ID_SUB, ID_MULeven, ID_MULodd, ID_ROTATE, 
			ID_SHIFT_L, ID_SHIFT_L_I, ID_SHIFT_R, ID_SHIFT_R_I, ID_SHIFT_R_A, ID_SHIFT_R_A_I, 
			ID_LW, ID_SW, ID_BEQ, ID_BNE, ID_NOP;
		
	wire branch, branch_beq, branch_bne;
	
	//EX stage signal
	//In EX stage we manipulate data except MEM instruction.
	reg EX_r_type, EX_m_type;
	reg [0:63] EX_ra, EX_rb; 
	reg [0:4] EX_rd, EX_shift_amount;
	reg [0:15] EX_IMME;
	reg [0:2] EX_PPP;
	reg [0:1] EX_WW;
	reg EX_AND, EX_OR, EX_XOR, EX_NOT, EX_MOV, EX_ADD, EX_SUB, EX_MULeven, EX_MULodd, EX_ROTATE, 
			EX_SHIFT_L, EX_SHIFT_L_I, EX_SHIFT_R, EX_SHIFT_R_I, EX_SHIFT_R_A, EX_SHIFT_R_A_I, 
			EX_LW, EX_SW, EX_NOP;
	reg [0:63] EX_data_tep;
	//reg [0:63] EX_data_res;
	reg [0:15] EX_16bit_0, EX_16bit_1, EX_16bit_2, EX_16bit_3;
	reg [0:31] EX_32bit_0, EX_32bit_1;
	//integer shift_amount0, shift_amount1, shift_amount2, shift_amount3,
	//		shift_amount4, shift_amount5, shift_amount6, shift_amount7;
	//reg signed [0:7] sign8_0, sign8_1, sign8_2, sign8_3, sign8_4, sign8_5, sign8_6, sign8_7;		
	//reg signed [0:15] sign16_0, sign16_1, sign16_2, sign16_3;
	//reg signed [0:31] sign32_0, sign32_1;
	//reg signed [0:63] sign64_0;
	
	//MEM stage signal
	reg MEM_r_type, MEM_lw;
	reg [0:4] MEM_rd;
	reg [0:63] MEM_ra;
	reg [0:63] MEM_EX_data;
	reg [0:31] MEM_addr;
	reg [0:2] MEM_PPP;
	reg MEM_en, MEM_wr_en;
	
	//WB stage signal
	reg reg_wr, WB_lw;
	reg [0:2] WB_PPP;
	reg [0:4] WB_rd;
	reg [0:63] WB_data;
	wire [0:63] WB_final_data;
	
	
	//IF stage logic
	assign pc = pc_count;
	
	always@(posedge clk or posedge reset)
	begin
		if (reset)
		begin
			pc_count[0:31] <= 32'b0;
			ins[0:31] <= 32'h0000_0000;
		end
		else 
		begin
			if (!branch)
			begin
				pc_count[0:31] <= pc_count[0:31] + 32'h0000_0004;
				ins[0:31] <= instruction[0:31];
			end
			else if(branch)
			begin
				pc_count[0:31] <= { {16{1'b0}}, ID_IMME[0:15] };
				ins[0:31] <= 32'h0000_0000;
			end
		end
	end
	
	//ID stage logic
	assign r_type = (ins[0:5] == 6'b101010);
	assign m_type = (ins[0:5] == 6'b100000) || (ins[0:5] == 6'b100001);
	
	assign ID_AND = r_type && (ins[26:31] == 6'b000000);
	assign ID_OR  = r_type && (ins[26:31] == 6'b000001);
	assign ID_XOR = r_type && (ins[26:31] == 6'b000010);
	assign ID_NOT = r_type && (ins[26:31] == 6'b000011);
	assign ID_MOV = r_type && (ins[26:31] == 6'b000100);
	assign ID_ADD = r_type && (ins[26:31] == 6'b000101);
	assign ID_SUB = r_type && (ins[26:31] == 6'b000110);
	assign ID_MULeven = r_type && (ins[26:31] == 6'b000111);
	assign ID_MULodd = r_type && (ins[26:31] == 6'b001000);
	assign ID_ROTATE = r_type && (ins[26:31] == 6'b001001);
	assign ID_SHIFT_L = r_type && (ins[26:31] == 6'b001010);
	assign ID_SHIFT_L_I = r_type && (ins[26:31] == 6'b001011);
	assign ID_SHIFT_R = r_type && (ins[26:31] == 6'b001100);
	assign ID_SHIFT_R_I = r_type && (ins[26:31] == 6'b001101);
	assign ID_SHIFT_R_A = r_type && (ins[26:31] == 6'b001110);
	assign ID_SHIFT_R_A_I = r_type && (ins[26:31] == 6'b001111);
	assign ID_LW = (ins[0:5] == 6'b100000);
	assign ID_SW = (ins[0:5] == 6'b100001);
	assign ID_BEQ = (ins[0:5] == 6'b100010);
	assign ID_BNE = (ins[0:5] == 6'b100011);
	assign ID_NOP = (ins[0:5] == 6'b111100);
	
	assign ID_rd = (r_type || ID_BEQ || ID_BNE || ID_LW) ? ins[6:10] : 5'b00000;
	assign rd_content = REG_FILE[ID_rd[0:4]];
	assign ID_ra = (r_type || ID_SW) ? (r_type ? ins[11:15] : ins[6:10]) : 5'b00000;
	assign ID_rb = (ID_AND || ID_OR || ID_XOR || ID_ADD || ID_SUB || ID_MULeven || ID_MULodd || ID_SHIFT_L || ID_SHIFT_R || ID_SHIFT_R_A) ? ins[16:20] : 5'b00000;
	assign ID_shift_amount = (ID_SHIFT_L_I || ID_SHIFT_R_I || ID_SHIFT_R_A_I) ? ins[16:20] : 5'b00000;
	assign ID_IMME = (ID_LW || ID_SW || ID_BEQ || ID_BNE) ? ins[16:31] : 16'b0000_0000_0000_0000;
	
	assign ID_PPP = (ins[0:5] == 6'b101010) ? ins[21:23] : 3'b000;
	assign ID_WW = (ins[0:5] == 6'b101010) ? ins[24:25] : 2'b00;
	
	assign branch_beq = (ID_BEQ && rd_content == 0) ?  1'b1 : 1'b0 ;
	assign branch_bne = (ID_BNE && rd_content != 0) ?  1'b1 : 1'b0 ;
	assign branch = (branch_beq || branch_bne);
	
	
	always @(posedge clk or posedge reset)
	begin
		if (reset)
		begin
			EX_r_type <= 1'b0;
			EX_m_type <= 1'b0;
			
			EX_AND  <= 1'b0;
			EX_OR   <= 1'b0;
			EX_XOR  <= 1'b0;
			EX_NOT  <= 1'b0;
			EX_MOV  <= 1'b0;
			EX_ADD  <= 1'b0;
			EX_SUB  <= 1'b0;
			EX_MULeven  <= 1'b0;
			EX_MULodd   <= 1'b0;
			EX_ROTATE   <= 1'b0;
			EX_SHIFT_L  <= 1'b0;
			EX_SHIFT_L_I <= 1'b0;
			EX_SHIFT_R   <= 1'b0;
			EX_SHIFT_R_I <= 1'b0;
			EX_SHIFT_R_A <= 1'b0;
			EX_SHIFT_R_A_I <= 1'b0;
			EX_LW   <= 1'b0;
			EX_SW   <= 1'b0;
			EX_NOP  <= 1'b0;
			
			EX_ra <= 64'h0000_0000_0000_0000;
			EX_rb <= 64'h0000_0000_0000_0000;
			EX_shift_amount <= 5'b00000;
			
			EX_rd <= 5'b00000;
			EX_IMME <= 16'b0000_0000_0000_0000;
			EX_PPP <= 3'b000;
			EX_WW <= 2'b00;
			
		end
		else
		begin
			EX_r_type <= r_type;
			EX_m_type <= m_type;
			
			EX_AND  <= ID_AND;
			EX_OR   <= ID_OR;
			EX_XOR  <= ID_XOR;
			EX_NOT  <= ID_NOT;
			EX_MOV  <= ID_MOV;
			EX_ADD  <= ID_ADD;
			EX_SUB  <= ID_SUB;
			EX_MULeven  <= ID_MULeven;
			EX_MULodd   <= ID_MULodd;
			EX_ROTATE   <= ID_ROTATE;
			EX_SHIFT_L  <= ID_SHIFT_L;
			EX_SHIFT_L_I <= ID_SHIFT_L_I;
			EX_SHIFT_R   <= ID_SHIFT_R;
			EX_SHIFT_R_I <= ID_SHIFT_R_I;
			EX_SHIFT_R_A <= ID_SHIFT_R_A;
			EX_SHIFT_R_A_I <= ID_SHIFT_R_A_I;
			EX_LW   <= ID_LW;
			EX_SW   <= ID_SW;
			EX_NOP  <= ID_NOP;
			
			EX_ra <= REG_FILE[ID_ra[0:4]];
			EX_rb <= REG_FILE[ID_rb[0:4]];
			EX_shift_amount <= ID_shift_amount;
			
			EX_rd <= ID_rd;
			EX_IMME <= ID_IMME;
			EX_PPP <= ID_PPP;
			EX_WW <= ID_WW;
			
		end
	end
	
	
	//EX stage logic
	always @(*)
	begin
		if (EX_AND)
		begin
			EX_data_tep = EX_ra[0:63] & EX_rb[0:63];
		end
		else if (EX_OR)
		begin
			EX_data_tep = EX_ra[0:63] | EX_rb[0:63];
		end
		else if (EX_XOR)
		begin
			EX_data_tep = EX_ra[0:63] ^ EX_rb[0:63];
		end
		else if (EX_NOT)
		begin
			EX_data_tep = ~EX_ra[0:63];
		end
		else if (EX_MOV)
		begin
			EX_data_tep = EX_ra[0:63];
		end
		else if (EX_ADD)
		begin
			if (EX_WW == 2'b00)
				EX_data_tep = {EX_ra[0:7] + EX_rb[0:7], EX_ra[8:15] + EX_rb[8:15], EX_ra[16:23] + EX_rb[16:23], EX_ra[24:31] + EX_rb[24:31], 
							EX_ra[32:39] + EX_rb[32:39], EX_ra[40:47] + EX_rb[40:47], EX_ra[48:55] + EX_rb[48:55], EX_ra[56:63] + EX_rb[56:63]};
			else if (EX_WW == 2'b01)
				EX_data_tep = {EX_ra[0:15] + EX_rb[0:15], EX_ra[16:31] + EX_rb[16:31],
							EX_ra[32:47] + EX_rb[32:47], EX_ra[48:63] + EX_rb[48:63]};
			else if (EX_WW == 2'b10)
				EX_data_tep = {EX_ra[0:31] + EX_rb[0:31], EX_ra[32:63] + EX_rb[32:63]};
			else 
				EX_data_tep = EX_ra[0:63] + EX_rb[0:63];
		end
		else if (EX_SUB)
		begin
			if (EX_WW == 2'b00)
				EX_data_tep = {EX_ra[0:7]   + ~EX_rb[0:7]   + 1'b1, EX_ra[8:15]  + ~EX_rb[8:15]  + 1'b1, EX_ra[16:23] + ~EX_rb[16:23] + 1'b1, EX_ra[24:31] + ~EX_rb[24:31] + 1'b1, 
							   EX_ra[32:39] + ~EX_rb[32:39] + 1'b1, EX_ra[40:47] + ~EX_rb[40:47] + 1'b1, EX_ra[48:55] + ~EX_rb[48:55] + 1'b1, EX_ra[56:63] + ~EX_rb[56:63] + 1'b1};
			else if (EX_WW == 2'b01)
				EX_data_tep = {EX_ra[0:15]  + ~EX_rb[0:15]  + 1'b1, EX_ra[16:31] + ~EX_rb[16:31] + 1'b1,
							   EX_ra[32:47] + ~EX_rb[32:47] + 1'b1, EX_ra[48:63] + ~EX_rb[48:63] + 1'b1};
			else if (EX_WW == 2'b10)
				EX_data_tep = {EX_ra[0:31] + ~EX_rb[0:31] + 1'b1, EX_ra[32:63] + ~EX_rb[32:63] + 1'b1};
			else 
				EX_data_tep = EX_ra[0:63] + ~EX_rb[0:63] + 1'b1;
		end
		else if (EX_MULeven)
		begin
			if (EX_WW == 2'b00)
			begin
				EX_16bit_0[0:15] = EX_ra[0:7] * EX_rb[0:7];
				EX_16bit_1[0:15] = EX_ra[16:23] * EX_rb[16:23];
				EX_16bit_2[0:15] = EX_ra[32:39] * EX_rb[32:39];
				EX_16bit_3[0:15] = EX_ra[48:55] * EX_rb[48:55];
				EX_data_tep[0:63] = {EX_16bit_0[0:15], EX_16bit_1[0:15], EX_16bit_2[0:15], EX_16bit_3[0:15]};
			end
			else if (EX_WW == 2'b01)
			begin
				EX_32bit_0[0:31] = EX_ra[0:15] * EX_rb[0:15];
				EX_32bit_1[0:31] = EX_ra[32:47] * EX_rb[32:47];
				EX_data_tep[0:63] = {EX_32bit_0[0:31], EX_32bit_1[0:31]};
			end
			else 
				EX_data_tep[0:63] = EX_ra[0:31] * EX_rb[0:31];
		end
		else if (EX_MULodd)
		begin
			if (EX_WW == 2'b00)
			begin
				EX_16bit_0[0:15] = EX_ra[8:15] * EX_rb[8:15];
				EX_16bit_1[0:15] = EX_ra[24:31] * EX_rb[24:31];
				EX_16bit_2[0:15] = EX_ra[40:47] * EX_rb[40:47];
				EX_16bit_3[0:15] = EX_ra[56:63] * EX_rb[56:63];
				EX_data_tep[0:63] = {EX_16bit_0[0:15], EX_16bit_1[0:15], EX_16bit_2[0:15], EX_16bit_3[0:15]};
			end
			else if (EX_WW == 2'b01)
			begin
				EX_32bit_0[0:31] = EX_ra[16:31] * EX_rb[16:31];
				EX_32bit_1[0:31] = EX_ra[48:63] * EX_rb[48:63];
				EX_data_tep[0:63] = {EX_32bit_0[0:31], EX_32bit_1[0:31]};
			end
			else 
				EX_data_tep[0:63] = EX_ra[32:63] * EX_rb[32:63];
		end
		else if (EX_ROTATE)
		begin
			if (EX_WW == 2'b00)
				EX_data_tep = {EX_ra[4:7], EX_ra[0:3], EX_ra[12:15], EX_ra[8:11], 
								EX_ra[20:23], EX_ra[16:19], EX_ra[28:31], EX_ra[24:27], 
								EX_ra[36:39], EX_ra[32:35], EX_ra[44:47], EX_ra[40:43],
								EX_ra[52:55], EX_ra[48:51], EX_ra[60:63], EX_ra[56:59] };
			else if (EX_WW == 2'b01)
				EX_data_tep = { EX_ra[8:15], EX_ra[0:7], EX_ra[24:31], EX_ra[16:23], 
								EX_ra[40:47], EX_ra[32:39], EX_ra[56:63], EX_ra[48:55] };
			else if (EX_WW == 2'b10)
				EX_data_tep = { EX_ra[16:31], EX_ra[0:15], EX_ra[48:63], EX_ra[32:47] };
			else 
				EX_data_tep = { EX_ra[32:63], EX_ra[0:31] };
		end
		else if (EX_SHIFT_L)
		begin
			if (EX_WW == 2'b00)
			begin
				/*shift_amount0 = EX_rb[5:7];
				shift_amount1 = EX_rb[13:15];
				shift_amount2 = EX_rb[21:23];			
				shift_amount3 = EX_rb[29:31];
				shift_amount4 = EX_rb[37:39];				
				shift_amount5 = EX_rb[45:47];				
				shift_amount6 = EX_rb[53:55];				
				shift_amount7 = EX_rb[61:63];*/
				EX_data_tep = {EX_ra[0:7] << EX_rb[5:7], EX_ra[8:15] << EX_rb[13:15], EX_ra[16:23] << EX_rb[21:23], EX_ra[24:31] << EX_rb[29:31], 
							EX_ra[32:39] << EX_rb[37:39], EX_ra[40:47] << EX_rb[45:47], EX_ra[48:55] << EX_rb[53:55], EX_ra[56:63] << EX_rb[61:63] };
			end
			else if (EX_WW == 2'b01)
			begin
				/*shift_amount0 = EX_rb[12:15];
				shift_amount1 = EX_rb[28:31];
				shift_amount2 = EX_rb[44:47];			
				shift_amount3 = EX_rb[60:63];*/
				EX_data_tep = {EX_ra[0:15] << EX_rb[12:15], EX_ra[16:31] << EX_rb[28:31],
							EX_ra[32:47] << EX_rb[44:47], EX_ra[48:63] << EX_rb[60:63] };
			end
			else if (EX_WW == 2'b10)
			begin
				/*shift_amount0 = EX_rb[27:31];
				shift_amount1 = EX_rb[59:63];*/
				EX_data_tep = {EX_ra[0:31] << EX_rb[27:31], EX_ra[32:63] << EX_rb[59:63]};
			end
			else
			begin
				//shift_amount0 = EX_rb[58:63];
				EX_data_tep = {EX_ra[0:63] << EX_rb[58:63]};
			end
		end
		else if (EX_SHIFT_L_I)
		begin
			if (EX_WW == 2'b00)
			begin
				//shift_amount0 = EX_shift_amount[2:4];
				EX_data_tep = {EX_ra[0:7] << EX_shift_amount[2:4], EX_ra[8:15] << EX_shift_amount[2:4], EX_ra[16:23] << EX_shift_amount[2:4], EX_ra[24:31] << EX_shift_amount[2:4], 
							EX_ra[32:39] << EX_shift_amount[2:4], EX_ra[40:47] << EX_shift_amount[2:4], EX_ra[48:55] << EX_shift_amount[2:4], EX_ra[56:63] << EX_shift_amount[2:4] };
			end
			else if (EX_WW == 2'b01)
			begin
				//shift_amount0 = EX_shift_amount[1:4];
				EX_data_tep = {EX_ra[0:15] << EX_shift_amount[1:4], EX_ra[16:31] << EX_shift_amount[1:4],
							EX_ra[32:47] << EX_shift_amount[1:4], EX_ra[48:63] << EX_shift_amount[1:4] };
			end
			else if (EX_WW == 2'b10)
			begin
				//shift_amount0 = EX_shift_amount[0:4];
				EX_data_tep = {EX_ra[0:31] << EX_shift_amount[0:4], EX_ra[32:63] << EX_shift_amount[0:4]};
			end
			else
			begin
				//shift_amount0 = EX_shift_amount[0:4];
				EX_data_tep = {EX_ra[0:63] << EX_shift_amount[0:4]};
			end
		
		end
		else if (EX_SHIFT_R)
		begin
			if (EX_WW == 2'b00)
			begin
				/*shift_amount0 = EX_rb[5:7];
				shift_amount1 = EX_rb[13:15];
				shift_amount2 = EX_rb[21:23];			
				shift_amount3 = EX_rb[29:31];
				shift_amount4 = EX_rb[37:39];				
				shift_amount5 = EX_rb[45:47];				
				shift_amount6 = EX_rb[53:55];				
				shift_amount7 = EX_rb[61:63];*/
				EX_data_tep = {EX_ra[0:7] >> EX_rb[5:7], EX_ra[8:15] >> EX_rb[13:15], EX_ra[16:23] >> EX_rb[21:23], EX_ra[24:31] >> EX_rb[29:31], 
							EX_ra[32:39] >> EX_rb[37:39], EX_ra[40:47] >> EX_rb[45:47], EX_ra[48:55] >> EX_rb[53:55], EX_ra[56:63] >> EX_rb[61:63] };
			end
			else if (EX_WW == 2'b01)
			begin
				/*shift_amount0 = EX_rb[12:15];
				shift_amount1 = EX_rb[28:31];
				shift_amount2 = EX_rb[44:47];			
				shift_amount3 = EX_rb[60:63];*/
				EX_data_tep = {EX_ra[0:15] >> EX_rb[12:15], EX_ra[16:31] >> EX_rb[28:31],
							EX_ra[32:47] >> EX_rb[44:47], EX_ra[48:63] >> EX_rb[60:63] };
			end
			else if (EX_WW == 2'b10)
			begin
				//shift_amount0 = EX_rb[27:31];
				//shift_amount1 = EX_rb[59:63];
				EX_data_tep = {EX_ra[0:31] >> EX_rb[27:31], EX_ra[32:63] >> EX_rb[59:63]};
			end
			else
			begin
				//shift_amount0 = EX_rb[58:63];
				EX_data_tep = {EX_ra[0:63] >> EX_rb[58:63]};
			end
		
		end
		else if (EX_SHIFT_R_I)
		begin
			if (EX_WW == 2'b00)
			begin
				//shift_amount0 = EX_shift_amount[2:4];
				EX_data_tep = {EX_ra[0:7] >> EX_shift_amount[2:4], EX_ra[8:15] >> EX_shift_amount[2:4], EX_ra[16:23] >> EX_shift_amount[2:4], EX_ra[24:31] >> EX_shift_amount[2:4], 
							EX_ra[32:39] >> EX_shift_amount[2:4], EX_ra[40:47] >> EX_shift_amount[2:4], EX_ra[48:55] >> EX_shift_amount[2:4], EX_ra[56:63] >> EX_shift_amount[2:4] };
			end
			else if (EX_WW == 2'b01)
			begin
				//shift_amount0 = EX_shift_amount[1:4];
				EX_data_tep = {EX_ra[0:15] >> EX_shift_amount[1:4], EX_ra[16:31] >> EX_shift_amount[1:4],
							EX_ra[32:47] >> EX_shift_amount[1:4], EX_ra[48:63] >> EX_shift_amount[1:4] };
			end
			else if (EX_WW == 2'b10)
			begin
				//shift_amount0 = EX_shift_amount[0:4];
				EX_data_tep = {EX_ra[0:31] >> EX_shift_amount[0:4], EX_ra[32:63] >> EX_shift_amount[0:4]};
			end
			else
			begin
				//shift_amount0 = EX_shift_amount[0:4];
				EX_data_tep = {EX_ra[0:63] >> EX_shift_amount[0:4]};
			end
		
		end
		else if (EX_SHIFT_R_A)
		begin
			if (EX_WW == 2'b00)
			begin
				/*shift_amount0 = EX_rb[5:7];
				shift_amount1 = EX_rb[13:15];
				shift_amount2 = EX_rb[21:23];			
				shift_amount3 = EX_rb[29:31];
				shift_amount4 = EX_rb[37:39];				
				shift_amount5 = EX_rb[45:47];				
				shift_amount6 = EX_rb[53:55];				
				shift_amount7 = EX_rb[61:63];
				sign8_0[0:7] = EX_ra[0:7];  
				sign8_1[0:7] = EX_ra[8:15]; 
				sign8_2[0:7] = EX_ra[16:23]; 
				sign8_3[0:7] = EX_ra[24:31]; 
				sign8_4[0:7] = EX_ra[32:39];  
				sign8_5[0:7] = EX_ra[40:47]; 
				sign8_6[0:7] = EX_ra[48:55];  
				sign8_7[0:7] = EX_ra[56:63];*/
				EX_data_tep = { $signed(EX_ra[0:7]) >>> EX_rb[5:7],   $signed(EX_ra[8:15]) >>> EX_rb[13:15], 
								$signed(EX_ra[16:23]) >>> EX_rb[21:23], $signed(EX_ra[24:31]) >>> EX_rb[29:31], 
								$signed(EX_ra[32:39]) >>> EX_rb[37:39], $signed(EX_ra[40:47]) >>> EX_rb[45:47], 
								$signed(EX_ra[48:55]) >>> EX_rb[53:55], $signed(EX_ra[56:63]) >>> EX_rb[61:63] };
			end
			else if (EX_WW == 2'b01)
			begin
				/*shift_amount0 = EX_rb[12:15];
				shift_amount1 = EX_rb[28:31];
				shift_amount2 = EX_rb[44:47];			
				shift_amount3 = EX_rb[60:63];
				sign16_0[0:15] = EX_ra[0:15];
				sign16_1[0:15] = EX_ra[16:31];
				sign16_2[0:15] = EX_ra[32:47];
				sign16_3[0:15] = EX_ra[48:63]; */
				EX_data_tep = { $signed(EX_ra[0:15])  >>> EX_rb[12:15], $signed(EX_ra[16:31]) >>> EX_rb[28:31],
								$signed(EX_ra[32:47]) >>> EX_rb[44:47], $signed(EX_ra[48:63]) >>> EX_rb[60:63] };
			end
			else if (EX_WW == 2'b10)
			begin
				/*shift_amount0 = EX_rb[27:31];
				shift_amount1 = EX_rb[59:63];
				sign32_0[0:31] = EX_ra[0:31];
				sign32_1[0:31] = EX_ra[32:63];*/
				EX_data_tep = { $signed(EX_ra[0:31]) >>> EX_rb[28:31], $signed(EX_ra[32:63]) >>> EX_rb[60:63] };
			end
			else
			begin
				//shift_amount0 = EX_rb[58:63];
				//sign64_0[0:63] = EX_ra[0:63];
				EX_data_tep = $signed(EX_ra[0:63]) >>> EX_rb[58:63];
			end
		
		end
		else if (EX_SHIFT_R_A_I)
		begin
			if (EX_WW == 2'b00)
			begin
				/*shift_amount0 = EX_shift_amount[2:4];
				sign8_0[0:7] = EX_ra[0:7];  
				sign8_1[0:7] = EX_ra[8:15]; 
				sign8_2[0:7] = EX_ra[16:23]; 
				sign8_3[0:7] = EX_ra[24:31]; 
				sign8_4[0:7] = EX_ra[32:39];  
				sign8_5[0:7] = EX_ra[40:47]; 
				sign8_6[0:7] = EX_ra[48:55];  
				sign8_7[0:7] = EX_ra[56:63];*/
				EX_data_tep = { $signed(EX_ra[0:7]) >>> EX_shift_amount[2:4],   $signed(EX_ra[8:15]) >>> EX_shift_amount[2:4], 
								$signed(EX_ra[16:23]) >>> EX_shift_amount[2:4], $signed(EX_ra[24:31]) >>> EX_shift_amount[2:4], 
								$signed(EX_ra[32:39]) >>> EX_shift_amount[2:4], $signed(EX_ra[40:47]) >>> EX_shift_amount[2:4], 
								$signed(EX_ra[48:55]) >>> EX_shift_amount[2:4], $signed(EX_ra[56:63]) >>> EX_shift_amount[2:4] };
								
			end
			else if (EX_WW == 2'b01)
			begin
				/*shift_amount0 = EX_shift_amount[1:4];
				sign16_0[0:15] = EX_ra[0:15];
				sign16_1[0:15] = EX_ra[16:31];
				sign16_2[0:15] = EX_ra[32:47];
				sign16_3[0:15] = EX_ra[48:63]; */
				EX_data_tep = { $signed(EX_ra[0:15]) >>> EX_shift_amount[1:4],  $signed(EX_ra[16:31]) >>> EX_shift_amount[1:4],
								$signed(EX_ra[32:47]) >>> EX_shift_amount[1:4], $signed(EX_ra[48:63]) >>> EX_shift_amount[1:4] };
			end
			else if (EX_WW == 2'b10)
			begin
				//shift_amount0 = EX_shift_amount[0:4];
				//sign32_0[0:31] = EX_ra[0:31];
				//sign32_1[0:31] = EX_ra[32:63];
				EX_data_tep = { $signed(EX_ra[0:31]) >>> EX_shift_amount[0:4], $signed(EX_ra[32:63]) >>> EX_shift_amount[0:4] };
			end
			else
			begin
				//shift_amount0 = EX_shift_amount[0:4];
				//sign64_0[0:63] = EX_ra[0:63];
				EX_data_tep = $signed(EX_ra[0:63]) >>> EX_shift_amount[0:4];
			end
		
		end
		else
			EX_data_tep = 0;
	end
	
	/*  always @(EX_data_tep)
	begin
		if (EX_PPP == 3'b000)
			EX_data_res[0:63] = EX_data_tep;
		else if (EX_PPP == 3'b001)
			EX_data_res[0:63] =  { EX_data_tep[0:31], 32'h0000_0000  }; 
		else if (EX_PPP == 3'b010)
			EX_data_res[0:63] =  { 32'h0000_0000, EX_data_tep[32:63] };
		else if (EX_PPP == 3'b011)
			EX_data_res[0:63] = { EX_data_tep[0:7], 8'b0000_0000, EX_data_tep[16:23], 8'b0000_0000, 
							EX_data_tep[32:39], 8'b0000_0000, EX_data_tep[48:55], 8'b0000_0000  }; 
		else if (EX_PPP == 3'b100)
			EX_data_res[0:63] = { 8'b0000_0000, EX_data_tep[8:15], 8'b0000_0000, EX_data_tep[24:31], 
							8'b0000_0000, EX_data_tep[40:47], 8'b0000_0000, EX_data_tep[56:63] }; 
	end  */
	
	always @(posedge clk or posedge reset)
	begin
		if (reset)
		begin
			MEM_r_type <= 1'b0;
			MEM_lw <= 1'b0;
			MEM_rd <= 5'b00000;
			MEM_ra <= 64'h0000_0000_0000_0000;
			MEM_EX_data <= 64'h0000_0000_0000_0000;
			MEM_addr <= 32'h0000_0000;
			MEM_en <= 1'b0;
			MEM_wr_en <= 1'b0;
			MEM_PPP <= 3'b000;
		end
		else
		begin
			MEM_lw <= EX_LW;
			MEM_r_type <= EX_r_type;
			
			MEM_PPP <= EX_PPP;
			
			if (EX_r_type)
			begin
				MEM_EX_data <= EX_data_tep[0:63];
				MEM_rd <= EX_rd[0:4];
			end
			else if (EX_m_type)
			begin
				MEM_en <= 1'b1;
				if (EX_LW)
				begin
					MEM_addr[0:31] <= { {16{1'b0}}, EX_IMME};
					MEM_rd[0:4] <= EX_rd[0:4];
				end
				else if (EX_SW)
				begin
					MEM_addr[0:31] <= { {16{1'b0}}, EX_IMME};
					MEM_wr_en <= 1'b1;
					MEM_ra[0:63] <= EX_ra[0:63];
				end
			end
		end
	end
	
	//MEM stage logic
	assign dataOut = MEM_ra[0:63];
	assign memAddr = MEM_addr[0:31];
	assign memEn   = MEM_en;
	assign memWrEn = MEM_wr_en;
	
	always @(posedge clk or posedge reset)
	begin
		if (reset)
		begin
			reg_wr <= 1'b0;
			WB_rd  <= 5'b00000;
			WB_data <= 64'h0000_0000_0000_0000;
			WB_PPP <= 3'b000;
			WB_lw <= 1'b0;
		end
		else 
		begin
			reg_wr <= MEM_lw || MEM_r_type;
			WB_rd <= MEM_rd[0:4];
			
			WB_PPP <= MEM_PPP;
			WB_lw <= MEM_lw;
			
			if (MEM_r_type) 
				WB_data <= MEM_EX_data[0:63];
		end
	end
	
	//WB stage logic
	
	assign WB_final_data[0:63] = WB_lw ? dataIn[0:63] : WB_data[0:63];
	
	integer i;
	always @(posedge clk_n or posedge reset)
	begin
		if (reset)
		begin
			
			for (i = 0; i < 32; i = i + 1) 
				REG_FILE[i] <= 64'h0000_0000_0000_0000;
		end
		else 
		begin	
			if (reg_wr && WB_rd != 0)
			begin
				if (WB_PPP == 3'b000)
				begin
					REG_FILE[WB_rd[0:4]] <= WB_final_data[0:63];
				end
				else if (WB_PPP == 3'b001)
				begin
					REG_FILE[WB_rd[0:4]][0:31] <= WB_final_data[0:31];
				end
				else if (WB_PPP == 3'b010)
				begin
					REG_FILE[WB_rd[0:4]][32:63] <= WB_final_data[32:63];
				end
				else if (WB_PPP == 3'b011)
				begin
					REG_FILE[WB_rd[0:4]][0:7] <= WB_final_data[0:7];
					REG_FILE[WB_rd[0:4]][16:23] <= WB_final_data[16:23];
					REG_FILE[WB_rd[0:4]][32:39] <= WB_final_data[32:39];
					REG_FILE[WB_rd[0:4]][48:55] <= WB_final_data[48:55];
				end
				else if (WB_PPP == 3'b100)
				begin
					REG_FILE[WB_rd[0:4]][8:15] <= WB_final_data[8:15];
					REG_FILE[WB_rd[0:4]][24:31] <= WB_final_data[24:31];
					REG_FILE[WB_rd[0:4]][40:47] <= WB_final_data[40:47];
					REG_FILE[WB_rd[0:4]][56:63] <= WB_final_data[56:63];
				end
			end
		end
	end
	
endmodule


							
							
							
							


