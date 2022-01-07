`timescale 1ns / 1ps

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

    UartGetData uartGetData(.trans_clk(trans_clk), .rst(rst), .data_rgb(data_rgb), .image_state(image_state),.bluetooth_dealed(bluetooth_dealed),
                       .ram_addr(ram_addr), .uart_txd_data(uart_txd_data));

    localparam T = FREQ / BAUDRATE;

    // 两层计数结构，cnt_clk计数每一位所占的时钟数，cnt_bit计数1个开始位，8个数据位，1个停止位，共10位
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

    // 先发送一个起始位0，然后是8位数据位，最后是1位停止位0
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