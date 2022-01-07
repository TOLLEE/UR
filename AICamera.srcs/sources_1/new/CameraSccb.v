`timescale 1ns / 1ps

// 摄像头的sccb协议
module CameraSccb(input clk,
                      input rst,
                      inout sio_d,               // 摄像头sio_d信号
                      output reg sio_c,          // 摄像头sio_c信号
                      input reg_ready,           // 寄存器配置完成
                      output reg sccb_ready = 0, // SCCB协议传输完成
                      input [7:0] data_addr,     // 寄存器地址
                      input [7:0] data_in);      // 寄存器数据

    reg [3:0] now_state   = 0;
    reg [3:0] next_state  = 0;
    reg [16:0] wait_time  = 0;
    reg [8:0] change_time = 0;

    parameter time_1 = 3'h200;
    parameter time_2 = 3'h800;

    parameter state_prepare  = 0;
    parameter state_begin_1  = 1;
    parameter state_begin_2  = 2;
    parameter state_change_1 = 3;
    parameter state_change_2 = 4;
    parameter state_change_3 = 5;
    parameter state_end_1    = 6;
    parameter state_end_2    = 7;
    parameter state_end_3    = 8;
    parameter state_wait     = 9;

    reg [31:0] data_temp;
    reg sio_d_send;

    always @ (posedge clk) begin
        if (rst) begin
            now_state <= state_prepare;
            wait_time <= 0;
            data_temp <= 32'hffffffff;
        end
        else begin
            case(now_state)
                state_prepare: begin
                    if (reg_ready) begin
                        data_temp <= {2'b10, 8'h60, 1'bx, data_addr, 1'bx, data_in, 1'bx,3'b011};
                        now_state = state_begin_1;
                    end
                end

                state_begin_1: begin
                    change_time <= 2;
                    wait_time   <= time_2;
                    now_state   <= state_wait;
                    next_state  <= state_begin_2;
                    sio_c       <= 1;
                end
                state_begin_2: begin
                    data_temp  <= {data_temp[30:0], 1'b1};
                    wait_time  <= time_1 * 3;
                    now_state  <= state_wait;
                    next_state <= state_change_3;
                    sio_c      <= 1;
                end

                state_change_1: begin
                    data_temp   <= {data_temp[30:0], 1'b1};
                    change_time <= change_time + 1;
                    if (change_time == 10 || change_time == 19 || change_time == 28)
                        sio_d_send <= 0;
                    else
                        sio_d_send <= 1;
                    wait_time  <= time_1;
                    now_state  <= state_wait;
                    if (change_time == 29)
                        next_state <= state_end_1;
                    else
                        next_state <= state_change_2;
                    sio_c      <= 0;
                end
                state_change_2: begin
                    wait_time  <= time_1 * 2;
                    now_state  <= state_wait;
                    next_state <= state_change_3;
                    sio_c      <= 1;
                end
                state_change_3: begin
                    wait_time  <= time_1;
                    now_state  <= state_wait;
                    next_state <= state_change_1;
                    sio_c      <= 0;
                end

                state_end_1: begin
                    wait_time  <= time_1 * 3;
                    now_state  <= state_wait;
                    next_state <= state_end_2;
                    sio_c      <= 1;
                end
                state_end_2: begin
                    data_temp  <= {data_temp[30:0], 1'b1};
                    wait_time  <= time_2;
                    now_state  <= state_wait;
                    next_state <= state_end_3;
                    sio_c      <= 1;
                end
                state_end_3: begin
                    data_temp  <= {data_temp[30:0], 1'b1};
                    wait_time  <= time_2;
                    now_state  <= state_wait;
                    next_state <= state_prepare;
                    sio_c      <= 1;
                end
                state_wait: begin
                    if (wait_time == 0)
                        now_state <= next_state;
                    else
                        wait_time <= wait_time - 1;
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        sccb_ready <= (now_state == state_prepare) && (reg_ready == 1);
    end

    assign sio_d = sio_d_send ? data_temp[31] : 'bz;
endmodule

