`timescale 1ns / 1ps

// 蓝牙接受，第0位表示是否进入传输状态，表示第1位表示显示颜色/黑白，第2位表示传输颜色/黑白，第3位表示传输是否自动
module Bluetooth(input clk_bluetooth,
                    input rst,
                    input data_bluetooth,
                    output reg[3:0] bluetooth_dealed);
    parameter bps      = 9600;
    parameter need_cnt = 100000000 / bps;
    reg [15:0] bps_cnt;     // 每一位中的计数器
    reg [7:0] bluetooth_out; // 蓝牙输出信号
    reg [3:0] cnt;          // 每一组数据的计数器
    reg [1:0] first_two;    // 除去滤波
    reg begin_bps_cnt;      // 加法使能信号

    always @ (posedge clk_bluetooth) begin
        if (rst)
            first_two <= 2'b11;
        else
            first_two <= {first_two[0], data_bluetooth}; // 串行赋值
    end

    always @ (posedge clk_bluetooth) begin
        if (rst)
            begin_bps_cnt <= 0;
        else if (first_two[1] & ~first_two[0])
            begin_bps_cnt <= 1;
        else if (cnt == 8 && bps_cnt == need_cnt - 1)
            begin_bps_cnt <= 0;
    end

    always @ (posedge clk_bluetooth) begin
        if (rst) begin
            bps_cnt <= 0;
            cnt     <= 0;
        end
        else if (begin_bps_cnt) begin
            if (bps_cnt == need_cnt - 1) begin
                bps_cnt <= 0;
                if (cnt == 8)
                    cnt <= 0;
                else
                    cnt <= cnt + 1;
            end
            else
                bps_cnt <= bps_cnt + 1;
        end
    end

    always @ (posedge clk_bluetooth) begin
        if (rst)
            bluetooth_out <= 0;
        else if (begin_bps_cnt && bps_cnt == need_cnt / 2 - 1 && cnt > 0)
            bluetooth_out[cnt - 1] <= data_bluetooth;
    end

    always @ (posedge clk_bluetooth) begin
        if (cnt == 8) begin
            bluetooth_dealed[3:0] <= bluetooth_out[3:0];
        end
    end
endmodule

