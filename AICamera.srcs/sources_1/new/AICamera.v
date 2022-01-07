`timescale 1ns / 1ps

module AICameraTop(output [3:0] red_vga, green_vga, blue_vga, // rgb像素信息
                output col_vga,          // 行时序信号
                output row_vga,          // 场时序信号
                input bluetooth_in,      // 接pmod
                input uart_rx,
                output uart_tx,
                input pclk, href, vsync, // 用于控制图像数据传输的三组信号
                input [7:0] camera_data, // 图像数据信号
                output sio_c,            // 摄像头sio_c信号
                inout sio_d,             // 摄像头sio_d信号
                output reset,            // reset信号，需要拉高，否则会重置寄存器
                output pwdn,             // pwdn信号，拉低关闭耗电模式
                output xclk,             // xclk信号，可不接
                output[7:0] dis_pos,     // 数码管显示位置
                output[6:0] display,     // 数码管显示数据
                input clk,
                input rst);

    // VGA 25.175 MHz, 蓝牙 100 MHz，摄像头 25 MHz, blk 100 MHz
    wire clk_vga, clk_bluetooth, clk_camera, clk_blk, locked;
    clk_wiz_0 clk_wiz(.clk_in1(clk),
                      .clk_out1(clk_vga),
                      .clk_out2(clk_bluetooth),
                      .clk_out3(clk_camera),
                      .clk_out4(clk_blk),
                      .locked(locked),
                      .reset(0));

    wire [3:0] bluetooth_dealed; // 处理过的蓝牙数据
    Bluetooth bluetooth(.clk_bluetooth(clk_bluetooth),
                        .rst(rst),
                        .data_bluetooth(bluetooth_in),
                        .bluetooth_dealed(bluetooth_dealed));

    CameraTop camera(.clk(clk_camera),
                     .rst(rst),
                     .sio_c(sio_c),
                     .sio_d(sio_d),
                     .reset(reset),
                     .pwdn(pwdn),
                     .xclk(xclk));

    wire [11:0] ram_data; // 写数据
    wire [18:0] ram_addr; // 写地址
    wire  write_ready; // 缓存写有效

    wire [18:0] uart_addr; // 发送地址
    wire image_pause;
    wire [4:0] image_state;

    GetImage getImage(.rst(rst),
                      .pclk(pclk),
                      .href(href),
                      .vsync(vsync),
                      .data_camera(camera_data),
                      .bluetooth_dealed(bluetooth_dealed),
                      .uart_addr(uart_addr),
                      .image_state(image_state),
                      .data_out(ram_data),
                      .write_ready(write_ready),
                      .now_addr(ram_addr),
                      .image_pause(image_pause));

    wire [11:0] vga_data; // 读数据
    wire [18:0] vga_addr; // 读地址
    wire [383:0] image_res;

    blk_mem_gen_0 buffer_mem(.clka(clk_blk),
                             .ena(1),
                             .wea(write_ready),
                             .addra(ram_addr),
                             .dina(ram_data),
                             .clkb(clk_blk),
                             .enb(1),
                             .addrb(vga_addr),
                             .doutb(vga_data));

    UartTop uart(.clk(clk_bluetooth),
                 .rst(rst),
                 .bluetooth_dealed(bluetooth_dealed),
                 .data_rgb(vga_data),
                 .ram_addr(uart_addr),
                 .image_res(image_res),
                 .uart_rx(uart_rx),
                 .image_pause(image_pause),
                 .image_state(image_state),
                 .uart_tx(uart_tx));
    
    Display7 display7(.clk(clk_blk),
                      .rst(rst),
                      .iData(image_state),
                      .oData(display),
                      .dis_pos(dis_pos));

    Vga vga(.clk_vga(clk_vga),
            .rst(rst),
            .data_rgb(vga_data),
            .ram_addr(vga_addr),
            .bluetooth_dealed(bluetooth_dealed),
            .uart_addr(uart_addr),
            .image_state(image_state),
            .image_res(image_res),
            .col_vga(col_vga),
            .row_vga(row_vga),
            .red_vga(red_vga),
            .green_vga(green_vga),
            .blue_vga(blue_vga));
endmodule