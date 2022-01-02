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

module UartGetData(
        input trans_clk, // 输入的时钟，频率由传输串口控制
        input rst,
        input [11:0] data_rgb, // 从RAM中读取的像素信息
        input [4:0] image_state,
        input [3:0] bluetooth_dealed, //蓝牙信息
        output reg[18:0] ram_addr, // 下一个要读取的RAM地址
        output reg[7:0] uart_txd_data
    );

    parameter col_siz = 11'd640;
    parameter row_siz = 11'd480;

    reg [11:0] col_pos; // 行坐标
    reg [11:0] row_pos; // 列坐标

    always@ (*) begin
        ram_addr = row_pos * col_siz + col_pos;
        if (bluetooth_dealed[0])
            uart_txd_data = (data_rgb[11:8] / 2 * 32 + data_rgb[7:4] / 2 * 4 + data_rgb[3:0] / 4);
        else
            uart_txd_data = (data_rgb[11:8] + data_rgb[7:4] + data_rgb[3:0]) * 16 / 3;
    end

    always @ (posedge trans_clk or posedge rst) begin
        if (rst) begin
            col_pos <= 0;
            row_pos <= 0;
        end
        else if (image_state && image_state != 2) begin // 除了这两个时间以外都不需要读内存
            col_pos <= 0;
            row_pos <= 0;
        end
        else if (col_pos == col_siz - 1) begin
            col_pos <= 0;
            if (row_pos == row_siz - 1) begin
                row_pos <= 0;
            end
            else
                row_pos <= row_pos + 1;
        end
        else
            col_pos <= col_pos + 1;
    end
endmodule

module UartOut (
        input clk, rst,
        input [11:0] data_rgb, // 从RAM中读取的像素信息
        input [4:0] image_state,
        input [3:0] bluetooth_dealed, //蓝牙信息
        output reg uart_tx,
        output [18:0] ram_addr,
        output reg img_start,
        output reg img_end
    );

    parameter BAUDRATE = 4000000;
    parameter FREQ     = 100_000_000;

    reg trans_clk;
    reg [3:0] cnt_bit;
    reg [31:0] cnt_clk;
    reg rdy = 1; // 忙闲指示信号，0为闲，1为忙

    wire [7:0] uart_txd_data;

    UartGetData getdata(.trans_clk(trans_clk), .rst(rst), .data_rgb(data_rgb), .image_state(image_state),.bluetooth_dealed(bluetooth_dealed),
                       .ram_addr(ram_addr), .uart_txd_data(uart_txd_data));

    localparam T = FREQ / BAUDRATE;

    // 两层计数结构，cnt_clk计数每一位所占的时钟数，cnt_bit计数1个开始位，8个数据位，一个停止位，共10位
    wire end_cnt_clk;
    wire end_cnt_bit;
    assign end_cnt_clk = cnt_clk == T - 1;
    assign end_cnt_bit = end_cnt_clk && cnt_bit == 9;

    always @(posedge clk or posedge rst) begin
        if (rst)
            cnt_clk <= 0;
        else if (end_cnt_clk)
            cnt_clk <= 0;
        else
            cnt_clk <= cnt_clk + 1'b1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            img_start <= 0;
            img_end   <= 0;
        end
        else if (cnt_bit == 8) begin
            if (image_state == 1)
                img_start <= 1;
            else if (image_state == 3)
                img_end <= 1;
            else if (image_state == 4) begin
                img_start <= 0;
                img_end   <= 0;
            end
        end

    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            cnt_bit <= 0;
        else if (end_cnt_clk) begin
            if (end_cnt_bit) begin
                cnt_bit   <= 0;
                trans_clk <= 0; // 刚开始时拉低
            end
            else begin
                if (cnt_bit == 8) begin
                    trans_clk <= 1; // 8位传完时拉高
                end
                cnt_bit <= cnt_bit + 1'b1;
            end
        end
    end

    reg [7:0] begin_data_color = 8'b11111111;
    reg [7:0] begin_data_black = 8'b11101110;

    // 先发送一个起始位0，然后8位数据位，最后是1位停止位0
    always @(posedge clk or posedge rst) begin
        if (rst)
            uart_tx <= 1;
        else if (!cnt_clk) begin
            if (!cnt_bit)
                uart_tx <= 0;
            else if (cnt_bit == 9)
                uart_tx <= 1;
            else if (image_state == 1 || image_state == 3) begin
                if (bluetooth_dealed[2])
                    uart_tx <= begin_data_black[cnt_bit - 1];
                else
                    uart_tx <= begin_data_color[cnt_bit - 1];
            end
            else
                uart_tx <= uart_txd_data[cnt_bit - 1];
        end
    end
endmodule

module UartTop(
        input clk, rst,
        input [3:0] bluetooth_dealed, // 蓝牙信息
        input [11:0] data_rgb, // 从RAM中读取的像素信息
        input uart_rx,
        input image_pause,
        output [18:0] ram_addr, // 下一个要读取的RAM地址
        output reg [4:0] image_state,
        output [383:0] image_res,
        output uart_tx
    );

    localparam BAUDRATE = 4000000;
    localparam FREQ     = 100_000_000;
    parameter col_siz   = 11'd640;
    parameter row_siz   = 11'd480;

    wire [7:0] data;
    wire img_start;
    wire img_end;
    wire [15:0] res_cnt;

    reg uart_out_rst = 1;
    reg uart_in_rst = 1;

    always@ (posedge clk or posedge rst) begin
        if (rst) begin
            uart_out_rst <= 1;
        end
        else if (!image_state || image_state == 4) begin
            uart_out_rst <= 1;
        end
        else if (image_state >= 1 && image_state <= 3) begin
            uart_out_rst <= 0;
        end
    end


    always@ (posedge clk or posedge rst) begin
        if (rst) begin
            image_state <= 0;
            uart_in_rst <= 1;
        end
        else if (image_state == 0 && bluetooth_dealed[0] && image_pause) begin
            image_state <= 1; // 传输起始位
        end
        else if (image_state == 1 && img_start == 1) begin
            image_state <= 2; // 传输图片
        end
        else if (image_state == 2 && ram_addr == col_siz * row_siz - 1) begin
            image_state <= 3; // 传输结束位
        end
        else if (image_state == 3 && img_end == 1) begin
            image_state <= 4; // 传入结果
            uart_in_rst <= 0;
        end
        else if (image_state == 4 && res_cnt >= 384) begin
            image_state <= 0; // 传入结束
            uart_in_rst <= 1;
        end
    end

    UartOut #(BAUDRATE, FREQ) uartOut(.clk(clk),.rst(uart_out_rst),.data_rgb(data_rgb),.image_state(image_state),.img_start(img_start),.img_end(img_end),.bluetooth_dealed(bluetooth_dealed),
                                        .ram_addr(ram_addr),.uart_tx(uart_tx));

    UartIn uartIn(.clk(clk), .rst(uart_in_rst), .data_in(uart_rx), .res_cnt(res_cnt), .image_res(image_res));

endmodule
