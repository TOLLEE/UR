`timescale 1ns / 1ps

module Display7(input clk,
                input rst,
                input [4:0] iData,
                output reg [7:0] dis_pos,
                output reg [6:0] oData);
    
    always @(posedge clk) begin
        if (rst) begin
            dis_pos <= 0;
            oData   <= 0;
        end
        else begin
            dis_pos <= 8'b11111110;
            case(iData)
                0:
                oData <= 7'b1000000;
                1:
                oData <= 7'b1111001;
                2:
                oData <= 7'b0100100;
                3:
                oData <= 7'b0110000;
                4:
                oData <= 7'b0011001;
                5:
                oData <= 7'b0010010;
                6:
                oData <= 7'b0000010;
                7:
                oData <= 7'b1111000;
                8:
                oData <= 7'b0000000;
                9:
                oData <= 7'b0010000;
            endcase
        end
    end
endmodule
