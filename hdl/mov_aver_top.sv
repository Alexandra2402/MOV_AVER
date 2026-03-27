module mov_aver_top #(
    parameter integer FFT_SIZE = 4096
    )(
    input logic clk,
    input logic resetn,
    input logic [31:0] data_i,
    input logic vl_i,
    input logic last_i,
    input logic EN,
    input logic [7:0] avg_win_size,
    output logic [31:0] data_o,
    output logic vl_o,
    output logic last_o
);

typedef enum {IDLE, CALC, FINISH} state_type;
state_type state;
state_type state_next;

logic [12:0] data_cnt = 0;
logic fifo_wr_en;
logic fifo_rd_en;
logic complete;
logic state_fl;
logic [39:0] acc = 0;
logic [39:0] sum = 0;
// logic [31:0] sub = 0;
logic [31:0] fifo_data = 0;
logic fifo_vl;
logic fifo_last;
logic [31:0] data_i_delayed [2:0];
logic [2:0] vl_i_delayed;
logic [31:0] div_data;
logic div_last;
logic div_vl;
logic [12:0] end_numb;
logic [31:0] fifo_data_reg;

assign data_o = (avg_win_size == 0) ? data_i : div_data;
assign last_o = (avg_win_size == 0) ? last_i : div_last;
assign vl_o = (avg_win_size == 0) ? vl_i : div_vl;

input_fifo input_fifo_u
(
    .s_aclk(clk),
    .s_aresetn(resetn),
    .s_axis_tvalid(vl_i_delayed[0] & fifo_wr_en),
    .s_axis_tready(),
    .s_axis_tdata(data_i_delayed[0]),
    .s_axis_tlast(last_i),
    .m_axis_tvalid(fifo_vl),
    .m_axis_tready(fifo_rd_en),
    .m_axis_tdata(fifo_data),
    .m_axis_tlast(fifo_last),
    .axis_prog_full_thresh(),
    .axis_data_count(),
    .axis_prog_full()
);

// divider divider_u
// (
//     .aclk(clk),
//     .s_axis_divisor_tvalid(),
//     .s_axis_divisor_tready(),
//     .s_axis_divisor_tdata(avg_win_size),
//     .s_axis_dividend_tvalid(),
//     .s_axis_dividend_tready(), 
//     .s_axis_dividend_tlast (),
//     .s_axis_dividend_tdata (sum),
//     .m_axis_dout_tvalid (div_vl),
//     .m_axis_dout_tlast (div_last),
//     .m_axis_dout_tdata (div_data)
//   );

always_ff @(posedge clk) begin
    if(!resetn) begin
        data_i_delayed[2] <= 0;
        data_i_delayed[1] <= 0;
        data_i_delayed[0] <= 0;
        vl_i_delayed <= 0;
    end
    else if (vl_i) begin
        vl_i_delayed[2] <= vl_i;
        vl_i_delayed[1] <= vl_i_delayed[2];
        vl_i_delayed[0] <= vl_i_delayed[1];
        data_i_delayed[2] <= data_i;
        data_i_delayed[1] <= data_i_delayed[2];
        data_i_delayed[0] <= data_i_delayed[1];
    end
end

always_ff @(posedge clk) begin
    if(!resetn)
        fifo_data_reg <= 0;
    else if (fifo_rd_en & data_i_delayed[0]) 
        fifo_data_reg <= fifo_data;
    else fifo_data_reg <= 0;
end

always_ff @(posedge clk) begin
    if(!resetn)
        end_numb <= 0;
    else if (EN)
        end_numb <= FFT_SIZE-avg_win_size-1; /// ?
    else end_numb <= 0;
end

always_ff @(posedge clk) begin
    if(!resetn)
        state <= IDLE;
    else state <= state_next;
end

always_ff @(posedge clk) begin
    if (!resetn) 
        data_cnt <= 0;
    else begin 
        if(EN) begin
            if(vl_i_delayed[0])
                data_cnt <= data_cnt + 1;
            else data_cnt <= 0;
        end
        else data_cnt <= 0;
    end
end

always_ff @(posedge clk) begin
    if (!resetn) 
        complete <= 0;
    else begin 
        if(data_cnt >= 4095) /// ?
            complete <= 1;
        // else if (state == IDLE)
        //     complete <= 1;
        else complete <= 0;
    end
end

always_comb begin
    fifo_rd_en = 0;
    fifo_wr_en = 0;
    state_next = state;
    case (state)
        IDLE: begin
            if (EN) begin
                if (avg_win_size != 0) begin
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
            else begin
                state_next = IDLE;
                fifo_wr_en = 0;
                fifo_rd_en = 0;
            end
        end
        CALC: begin 
            if (complete == 0) begin 
                if (data_cnt >= avg_win_size-1)
                    fifo_rd_en = 1;
                if (data_cnt >= end_numb) 
                    fifo_wr_en = 0;
                else fifo_wr_en = 1;
                state_next = CALC;
            end
            else begin
                state_next = FINISH;
                fifo_rd_en = 0;
                fifo_wr_en = 0;
            end
        end
        FINISH: begin
            if (!EN) state_next = IDLE;
            else state_next = FINISH;
            fifo_rd_en = 0;
            fifo_wr_en = 0;
        end
        default: begin
            fifo_rd_en = 0;
            fifo_wr_en = 0;
        end
    endcase
end

always_ff @(posedge clk) begin
    if (!resetn)
        acc <= 0;
    else if (vl_i_delayed[0])
        acc <= sum - fifo_data_reg;
    else acc <= 0;
end

always_ff @(posedge clk) begin
    if (!resetn)
        sum <= 0;
    else if (vl_i_delayed[0])
        sum <= data_i_delayed[0] + acc;
    else sum <= 0;
end

endmodule