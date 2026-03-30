`timescale 1ns/1ps

module mov_aver_tb ();

    logic clk = 0;
    logic resetn;
    logic [31:0] data_i;
    logic vl_i;
    logic last_i;
    logic EN;
    logic [7:0] avg_win_size_i;
    logic [31:0] data_o;
    logic vl_o;
    logic last_o;
    localparam FFT_SIZE = 4096;

    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    mov_aver_top DUT (.*);

    initial begin
        vl_i = 0;
        data_i = 32'd4294963199;
        resetn = 0;
        #1000
        resetn = 1;
        #1000
        last_i = 10;
        avg_win_size_i = 0;//$urandom_range(255,0);
        EN = 0;
        vl_i = 0;
        #10
        EN = 1;
        #20
        repeat(FFT_SIZE-1) begin
            @(posedge clk);
            data_i = data_i + 1;//$urandom_range(65535,0);
            vl_i = 1;
        end
        @(posedge clk);
        data_i = data_i + 1;//$urandom_range(65535,0);
        vl_i = 1;
        last_i = 1;
        @(posedge clk);
        vl_i = 0;
        last_i = 0;
        EN = 1;
      #100000
        EN = 0;
        data_i = 0;
      #100000
        EN = 1;
        repeat(FFT_SIZE-1) begin
            @(posedge clk);
            data_i = data_i + 1;//$urandom_range(65535,0);
            vl_i = 1;
        end
        @(posedge clk);
        data_i = data_i + 1;//$urandom_range(65535,0);
        vl_i = 1;
        last_i = 1;
        @(posedge clk);
        vl_i = 0;
        last_i = 0;
        EN = 1;
      #100000
        EN = 0;
        data_i = 0;
      #100000
        @(posedge clk);    
    end

endmodule