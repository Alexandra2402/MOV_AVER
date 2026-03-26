`timescale 1ns/1ps

module mov_aver_td ();

    logic clk = 0;
    logic resetn;
    logic [31:0] data_i;
    logic vl_i;
    logic last_i;
    logic EN;
    logic [7:0] avg_win_size;
    logic [31:0] data_o;
    logic vl_o;
    logic last_o;
    localparam FFT_SIZE = 4096;

    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    mov_aver_top DUT (.*);

    initial begin
        resetn = 0;
        #10
        resetn = 1;
        repeat(FFT_SIZE) begin
            EN = 0;
            vl_i = 0;
            #10
            EN = 1;
            #20
            data_i = $urandom_range(65535,0);
            vl_i = 1;
        end
    end

endmodule