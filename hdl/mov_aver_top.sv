module mov_aver_top #(
    parameter integer FFT_SIZE = 4096
)
(
    input logic clk,
    input logic resetn,
    input logic [31:0] data_i,
    input logic vl_i,
    input logic last_i,
    input logic EN,
    input logic [7:0] avg_win_size_i,
    output logic [31:0] data_o,
    output logic vl_o,
    output logic last_o
);

typedef enum {IDLE, CALC} state_type;
state_type state;
state_type state_next;

logic [12:0] data_cnt;
logic fifo_wr_en;
logic fifo_rd_en;
logic complete;
logic [43:0] excess_sum_reg,sum_reg; //max_32bit_value*4096 -> 44 bit
logic [39:0] sub_reg;
logic [31:0] fifo_data;
logic fifo_vl;
logic [31:0] data_i_delayed;
logic [2:0] vl_i_delayed;
logic [47:0] div_data;
logic [2:0] last_i_delayed;
logic div_last;
logic div_vl;
logic [12:0] end_numb;
logic zero_fl;

always_ff @(posedge clk) begin
    if (!resetn) begin
        data_o <= 0;
        last_o <= 0;
        vl_o <= 0;
        zero_fl <= 0;
    end
    else begin
        if(avg_win_size_i == 0) begin
            data_o <= data_i;
            last_o <= last_i;
            vl_o <= vl_i;
            zero_fl <= 1;
        end
        else begin
            data_o <= div_data[33:2];
            last_o <= div_last;
            vl_o <= div_vl;
            zero_fl <= 0;
        end
    end
end

input_fifo input_fifo_u
(
    .s_aclk(clk),
    .s_aresetn(resetn),
    .s_axis_tvalid(vl_i & fifo_wr_en),
    .s_axis_tready(),
    .s_axis_tdata(data_i),
    .m_axis_tvalid(fifo_vl),
    .m_axis_tready(fifo_rd_en),
    .m_axis_tdata(fifo_data),
    .axis_prog_full_thresh(),
    .axis_data_count(),
    .axis_prog_full()
);

divider divider_u
(
    .aclk(clk),
    .s_axis_divisor_tvalid(vl_i_delayed[2]),
    .s_axis_divisor_tdata(avg_win_size_i),
    .s_axis_dividend_tvalid(vl_i_delayed[2]), 
    .s_axis_dividend_tlast(last_i_delayed[2]),
    .s_axis_dividend_tdata(sub_reg),
    .m_axis_dout_tvalid(div_vl),
    .m_axis_dout_tlast(div_last),
    .m_axis_dout_tdata(div_data)
  );

always_ff @(posedge clk) begin
    vl_i_delayed[0] <= vl_i & ~complete;
    vl_i_delayed[1] <= vl_i_delayed[0];
    vl_i_delayed[2] <= vl_i_delayed[1];
    data_i_delayed <= data_i;
end

always_ff @(posedge clk) begin
    last_i_delayed[0] <= last_i & ~complete;
    last_i_delayed[1] <= last_i_delayed[0];
    last_i_delayed[2] <= last_i_delayed[1];
end

always_ff @(posedge clk) begin
    if(!resetn)
        end_numb <= 0;
    else if (EN)
        end_numb <= FFT_SIZE-avg_win_size_i-1;
    else 
        end_numb <= 0;
end

always_ff @(posedge clk) begin
    if (!resetn)
        state <= IDLE;
    else 
        state <= state_next;
end

//count input data
always_ff @(posedge clk) begin
    if (!resetn) 
        data_cnt <= 0;
    else if (vl_i_delayed[0] && ~complete) //~count one time for one enable! 
        data_cnt <= data_cnt + 1;
    else
        data_cnt <= 0;
end

//this signal need for ONE transfer per ENA
always_ff @(posedge clk) begin
    if (!resetn) 
        complete <= 0;
    else if (~EN)  
        complete <= 0;
    else if(data_cnt == 4095) 
        complete <= 1;
end

always_comb begin
    fifo_rd_en = 0;
    fifo_wr_en = 0;
    state_next = state;
    case (state)
        IDLE: begin
            if (EN && ~complete && ~zero_fl) begin
                state_next = CALC;
                fifo_wr_en = 1;
                fifo_rd_en = 0;
            end
            else begin
                state_next = IDLE;
                fifo_wr_en = 0;
                fifo_rd_en = 0;
            end
            
        end
        CALC: begin 
            if (complete == 0) begin 
                state_next = CALC;
                //read fifo start after AVG_WINDOW_SIZE
                if (data_cnt >= avg_win_size_i)
                    fifo_rd_en = 1;
                else 
                    fifo_rd_en = 0;
                //finish write when last AVG_WINDOW_SIZE words transfered 
                if (data_cnt >= end_numb) 
                    fifo_wr_en = 0;
                else
                    fifo_wr_en = 1;
                
            end
            else begin
                state_next = IDLE;
                fifo_rd_en = 0;
                fifo_wr_en = 0;
            end
        end

    endcase
end

//////////0,1,2,3,4,5,6,7...; win = 3; 0 1 2 -> sum_reg <= sum_reg + data_i ||||| 4,5,6,7... -> 
/// -> sum_reg <= sum_reg + data_i; excess_reg <= fifo_data + excess_reg; sub <= sum_reg - excess_reg;  
//accamulate data_i always
always_ff @(posedge clk) begin
    if (!resetn)
        sum_reg <= 0;
    else if (vl_i_delayed[0])
        sum_reg <= data_i_delayed + sum_reg;
    else 
        sum_reg <= 0;
end

//accamulate excess for window 
always_ff @(posedge clk) begin
    if (!resetn)
        excess_sum_reg <= 0;
    else if (vl_i_delayed[0] && fifo_rd_en)
        excess_sum_reg <= fifo_data + excess_sum_reg;
    else if (~complete)
        excess_sum_reg <= 0;
end

always_ff @(posedge clk) begin
    if (!resetn)
        sub_reg <= 0;
    else if (vl_i_delayed[1])
        sub_reg <= sum_reg - excess_sum_reg;
    else 
        sub_reg <= 0;
end

endmodule