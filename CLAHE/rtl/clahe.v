//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           clahe.v
// Descriptions:        CLAHE算法（针对RGB图像）
//-----------------------------------------README-----------------------------------------
// 先将RGB图像转换到HSV空间，取亮度分量V做处理，然后还原回RGB图像。
// 
// 根据RGB和HSV的转换公式，可以证明R、G、B均与V成正比，因此色彩空间转化的计算可以简化为一个简单的乘除法计算。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module clahe #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080,
        parameter   BLOCK = 8
    ) (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        input               src_last,
        output              dst_valid,
        output      [23:0]  dst_data
    );


    wire                src_y_valid;
    wire    [7:0]       src_y_data;
    wire                src_y_last;
    wire                dst_y_valid;
    wire    [7:0]       dst_y_data;

    reg                 src_valid_en, src_y_valid_en;

    wire    [1:0]       max_index, max_index_dly;

    wire    [23:0]      src_data_dly;
    wire    [7:0]       y_dly;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            src_valid_en <= 1'b0;
            src_y_valid_en <= 1'b0;
        end
        else begin
            src_valid_en <= src_last ? ~src_valid_en : src_valid_en;
            src_y_valid_en <= src_y_last ? ~src_y_valid_en : src_y_valid_en;
        end
    end

    max max_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (src_valid),
        .src_data           (src_data),
        .src_last           (src_last),
        .dst_valid          (src_y_valid),
        .dst_data           (src_y_data),
        .dst_index          (max_index),
        .dst_last           (src_y_last)
    );

    clahe_core #(
        .HEIGHT             (HEIGHT),
        .WIDTH              (WIDTH)
    ) clahe_core_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (src_y_valid),
        .src_data           (src_y_data),
        .src_last           (src_y_last),
        .dst_valid          (dst_y_valid),
        .dst_data           (dst_y_data)
    );

    fifo #(
        .WIDTH      (24),
        .DEPTH      (16)
    ) fifo_inst_rgb(
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (src_valid_en & src_valid),
        .wr_data    (src_data),
        .rd_en      (dst_y_valid),
        .rd_data    (src_data_dly),
        .empty      (),
        .full       ()
    );

    fifo #(
        .WIDTH      (8),
        .DEPTH      (16)
    ) fifo_inst_y(
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (src_y_valid_en & src_y_valid),
        .wr_data    (src_y_data),
        .rd_en      (dst_y_valid),
        .rd_data    (y_dly),
        .empty      (),
        .full       ()
    );

    fifo #(
        .WIDTH      (2),
        .DEPTH      (16)
    ) fifo_inst_index(
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (src_y_valid_en & src_y_valid),
        .wr_data    (max_index),
        .rd_en      (dst_y_valid),
        .rd_data    (max_index_dly),
        .empty      (),
        .full       ()
    );

    wire    [23:0]      rgb_new;
    assign  rgb_new[ 7: 0] = (max_index_dly==2'd0) ? dst_y_data : src_data_dly[ 7: 0];
    assign  rgb_new[15: 8] = (max_index_dly==2'd1) ? dst_y_data : src_data_dly[15: 8];
    assign  rgb_new[23:16] = (max_index_dly==2'd2) ? dst_y_data : src_data_dly[23:16];

    mul_div mul_div_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (dst_y_valid),
        .src_data           (rgb_new),
        .src_mul            ({dst_y_data, dst_y_data}),
        .src_div            ({y_dly, y_dly}),
        .skip_index         (max_index_dly),
        .dst_valid          (dst_valid),
        .dst_data           (dst_data)
    );


endmodule
