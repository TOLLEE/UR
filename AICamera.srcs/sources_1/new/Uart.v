`timescale 1ns / 1ps

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
