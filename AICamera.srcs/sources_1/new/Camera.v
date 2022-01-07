`timescale 1ns / 1ps

module CameraTop(input clk,
                  input rst,
                  output sio_c,
                  inout sio_d,
                  output reset,
                  output pwdn,
                  output xclk);
    assign reset = 1;
    assign pwdn  = 0;
    assign xclk  = clk;

    wire [15:0] data_send;
    wire reg_ready, sccb_ready;

    CameraReg init(
                  .clk(clk),
                  .rst(rst),
                  .data_out(data_send),
                  .reg_ready(reg_ready),
                  .sccb_ready(sccb_ready));

    CameraSccb sender(
                   .clk(clk),
                   .rst(rst),
                   .sio_d(sio_d),
                   .sio_c(sio_c),
                   .reg_ready(reg_ready),
                   .sccb_ready(sccb_ready),
                   .data_addr(data_send[15:8]),
                   .data_in(data_send[7:0]));

endmodule