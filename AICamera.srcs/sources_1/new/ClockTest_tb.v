module ClockTest_tb();
    reg clk_100;
    wire clk_24;
    wire clk_25_175;
    reg reset;
    wire locked;

    always begin
        #10 clk_100=~clk_100;
    end
    
    initial begin
        reset=0;
        clk_100=0;
    end

    clk_wiz_0 uut(
        .clk_in1(clk_100),
        .clk_out1(clk_25_175),
        .clk_out2(clk_24),
        .reset(reset),
        .locked(locked)
    );
endmodule