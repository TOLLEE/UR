`timescale 1ns / 1ps

module GetImage (input rst,
                    input pclk,
                    input href,                     // 摄像头传输数据信号
                    input vsync,                    // 摄像头开始/结束传输
                    input [7:0] data_camera,        // 摄像头数据
                    input [3:0] bluetooth_dealed,   // 蓝牙数据
                    input [18:0] uart_addr,
                    input [4:0] image_state,
                    output reg [11:0] data_out,     // 得到的RGB数据
                    output reg write_ready,         // 写有效
                    output reg [18:0] now_addr = 0, // 数据传输地址
                    output reg image_pause);

    reg [15:0] rgb_565   = 0;
    reg [18:0] next_addr = 0;
    reg [1:0] now_state  = 0; // 当前状态
    parameter state_0    = 0; // 初始状态
    parameter state_1    = 1; // 8位有效
    parameter state_2    = 2; // 16位有效

    reg get_ready; // 是否正在传输
    reg [35:0] wait_time = 0;

    // 当前一幅图像是否传输完成
    always@ (negedge pclk) begin
        if (!bluetooth_dealed[0])
            get_ready <= 1;
        else if (!bluetooth_dealed[3] || (!image_state && vsync && !next_addr)) begin
            get_ready <= 0;
            image_pause <= 1;
        end
        else if (image_state == 3) begin
            get_ready   <= 1;
            image_pause <= 0;
        end
    end

    // 将摄像头图像存入RAM
    always@ (posedge pclk) begin
        if (rst || !vsync) begin
            write_ready <= 0;
            now_addr    <= 0;
            next_addr   <= 0;
            now_state   <= 0;
        end
        else if (get_ready) begin
            now_addr <= next_addr;
            rgb_565  <= {rgb_565[7:0], data_camera};
            data_out <= {rgb_565[15:12], rgb_565[10:7], rgb_565[4:1]};
            case(now_state)
                state_0: begin
                    if (href)
                        now_state <= state_1;
                    else
                        now_state <= state_0;
                    write_ready <= 0;
                end
                state_1: begin
                    now_state   <= state_2;
                    write_ready <= 0;
                end
                state_2: begin
                    if (href)
                        now_state = state_1;
                    else
                        now_state = state_0;
                    write_ready <= 1;
                    next_addr   <= next_addr + 1;
                end
            endcase
        end
        else
            write_ready <= 0;
    end
endmodule
