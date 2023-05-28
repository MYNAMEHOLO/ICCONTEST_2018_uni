module LCD_CTRL(clk,
                reset,
                cmd,
                cmd_valid,
                IROM_Q,
                IROM_rd,
                IROM_A,
                IRAM_valid,
                IRAM_D,
                IRAM_A,
                busy,
                done);
    input clk;
    input reset;
    input [3:0] cmd; 
    input cmd_valid;
    input [7:0] IROM_Q;
    output reg IROM_rd;
    output reg [5:0] IROM_A;
    output reg IRAM_valid;
    output reg [7:0] IRAM_D;
    output reg [5:0] IRAM_A;
    output reg busy;
    output reg done;

parameter [5:0] IDLE = 0,
                READ = 1,
                CMD = 2,
                WAIT = 3,
                WRITE = 4,
                DONE = 5;

reg [5:0] cs , ns;
reg [5:0] cnt; // counter for read
reg [7:0] img [63:0]; //save my whole img
reg [5:0] ax_x , ax_y; // point axis_x and point ax_y
wire [5:0] LU ; // left up point
wire [5:0] RU ; // RIGHT up point
wire [5:0] LD ; // LEDT DOWN POINT
wire [5:0] RD ; // RIGHT DOWN POINT

//flagging at Right UP side
// point assignment
// hint '+' operator's priority is greater than '>> or <<'

assign LU = ( (ax_y-1'b1)<<3 ) + (ax_x - 6'b1);
assign RU = ( (ax_y-1'b1)<<3 ) + ax_x ;
assign LD = ( (ax_y-1'b1)<<3 ) + (ax_x + 6'd7);
assign RD = ( (ax_y-1'b1)<<3 ) + (ax_x + 6'd8);

//operate assignment
//avg
wire [9:0] sum_temp;
wire [7:0] avg;
assign sum_temp = (img[LU] + img[RU]) + (img [LD] + img[RD]);
assign avg = sum_temp [9:2];
//

//max compare
wire [7:0] max_temp1;
wire [7:0] max_temp2;
wire [7:0] max;
assign max_temp1 = (img[LU] >= img[LD])? img[LU]: img[LD];
assign max_temp2 = (img[RU] >= img[RD])? img[RU]: img[RD];
assign max = (max_temp1 >= max_temp2)? max_temp1: max_temp2;

//min compare
wire [7:0] min_temp1;
wire [7:0] min_temp2;
wire [7:0] min;
assign min_temp1 = (img[LU] <= img[LD])? img[LU]: img[LD];
assign min_temp2 = (img[RU] <= img[RD])? img[RU]: img[RD];
assign min = (min_temp1 <= min_temp2)? min_temp1: min_temp2;


// for delay one cycle
//reg for state[WRITE]
reg [5:0] cnt_output;

// current state logic
always@(posedge clk or posedge reset)begin
    if(reset) begin
        cs <= 'b0;
        cs[IDLE] <= 1'b1;
    end
    else cs <= ns;
end

//next state logic
always@(*)begin
    ns = 'b0;
    case(1'b1) //synopsys parallel_case
        cs[IDLE]: ns[READ] = 1'b1;
        cs[READ]: begin
            if(IROM_A == 6'd63) ns[CMD] = 1'b1;
            else ns[READ] = 1'b1;
        end
        cs[CMD]:begin
            if(cmd == 4'd0) ns[WRITE] = 1'b1;
            else if(cmd_valid == 1'b1) ns[WAIT] = 1'b1;
            else ns[CMD] = 1'b1;
        end
        cs[WAIT]: ns[CMD] = 1'b1;
        cs[WRITE]:begin
            if(IRAM_A == 6'd63) ns[DONE] = 1'b1;
            else ns[WRITE] = 1'b1;
        end
        cs[DONE]:begin
        end
    endcase
end

//output state logic gate level boom boom
always@(posedge clk)begin 
        IROM_rd <= 1'b0;
        IROM_A <= 1'b0;
        IRAM_valid <= 1'b0;
        IRAM_A <= 6'd0;
        IRAM_D <= 6'd0;
	    cnt <= 6'd0;
        cnt_output <= 6'd0;
        done <= 1'b0;
        busy <= 1'b1;
        if(reset) begin
            ax_x <= 6'd4;
            ax_y <= 6'd4;
        end
        else begin
        case(1'b1) //synopsys parallel_case
            cs[IDLE]:begin
                IROM_rd <= 1'b1;
                busy <= 1'b1;
            end
            cs[READ]:begin
                IROM_rd <= 1'b1;
                img[IROM_A] <= IROM_Q;
                IROM_A <= IROM_A + 1'b1;
                cnt <= cnt + 1'b1;
                if(IROM_A == 6'd63) busy <= 1'b0;
                else busy <= busy;
            end
            cs[CMD]:begin
                busy <= 1'b0;
                case(cmd)
                    4'd0:begin
                    end
                    4'd1:begin // Shift up
                        if(ax_y == 6'd1) ax_y <= 6'd1;
                        else ax_y <= ax_y - 1'b1;
                    end
                    4'd2:begin // Shift down
                        if(ax_y == 6'd7) ax_y <= 6'd7;
                        else ax_y <= ax_y + 1'b1;
                    end
                    4'd3:begin // Shift Left
                        if(ax_x == 6'd1) ax_x <= 6'd1;
                        else ax_x <= ax_x - 1'b1;
                    end
                    4'd4:begin // Shift Right
                        if(ax_x == 6'd7) ax_x <= 6'd7;
                        else ax_x <= ax_x + 1'b1;
                    end
                    4'd5:begin // Max
                        img[LU] <= max;
                        img[RU] <= max;
                        img[LD] <= max;
                        img[RD] <= max;
                    end
                    4'd6:begin // Min
                        img[LU] <= min;
                        img[RU] <= min;
                        img[LD] <= min;
                        img[RD] <= min;
                    end
                    4'd7:begin // Average
                        img[LU] <= avg;
                        img[RU] <= avg;
                        img[LD] <= avg;
                        img[RD] <= avg;
                    end
                    4'd8:begin // Counteclockwise Rotation
                        img[LU] <= img[RU];
                        img[RU] <= img[RD];
                        img[LD] <= img[LU];
                        img[RD] <= img[LD];
                    end
                    4'd9:begin // Clockwise Rotation
                        img[LU] <= img[LD];
                        img[RU] <= img[LU];
                        img[LD] <= img[RD];
                        img[RD] <= img[RU];
                    end
                    4'ha:begin // Mirror X
                        img[LU] <= img[LD];
                        img[RU] <= img[RD];
                        img[LD] <= img[LU];
                        img[RD] <= img[RU];
                    end
                    4'hb:begin // Mirror Y
                        img[LU] <= img[RU];
                        img[RU] <= img[LU];
                        img[LD] <= img[RD];
                        img[RD] <= img[LD];
                    end
                endcase
            end
            cs[WAIT]: busy <= 1'b1;
            cs[WRITE]:begin
                IRAM_valid <= 1'b1;
                busy <= 1'b1;
                if(IRAM_valid == 1'b1)begin
                IRAM_A <= cnt_output;
                IRAM_D <= img[cnt_output];
                cnt_output <= cnt_output + 1'b1;
                end
            end
            cs[DONE]:begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        endcase 
        end
end
endmodule
