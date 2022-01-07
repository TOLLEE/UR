`timescale 1ns / 1ps

module UartIn(input clk,
                input rst,
                input data_in,
                output reg [15:0] res_cnt,
                output reg [383:0] image_res);
    parameter bps      = 4000000;
    parameter need_cnt = 100000000 / bps;
    reg [15:0] bps_cnt; // 每一位中的计数器
    reg [3:0] cnt; // 每一组数据的计数器
    reg [1:0] first_two; // 除去滤波
    reg [7:0] data_out;
    reg begin_bps_cnt;

    always @ (posedge clk) begin
        if (rst)
            first_two <= 2'b11;
        else
            first_two <= {first_two[0], data_in}; // 串行赋值
    end

    always @ (posedge clk) begin
        if (rst)
            begin_bps_cnt <= 0;
        else if (first_two[1] & ~first_two[0])
            begin_bps_cnt <= 1;
        else if (cnt == 8 && bps_cnt == need_cnt - 1)
            begin_bps_cnt <= 0;
    end

    always @ (posedge clk) begin
        if (rst) begin
            bps_cnt <= 0;
            cnt     <= 0;
            res_cnt <= 0;
        end
        else if (begin_bps_cnt) begin
            if (bps_cnt == need_cnt - 1) begin
                bps_cnt <= 0;
                if (cnt == 8) begin
                    cnt                     <= 0;
                    image_res[7 + res_cnt-:8] <= data_out[7:0];
                    res_cnt                 <= res_cnt + 8;
                end
                else
                    cnt <= cnt + 1;
            end
            else
                bps_cnt <= bps_cnt + 1;
        end
    end

    always @ (posedge clk) begin
        if (rst)
            data_out <= 0;
        else if (begin_bps_cnt && bps_cnt == need_cnt / 2 - 1 && cnt > 0)
            data_out[cnt-1] <= data_in;
    end
endmodule