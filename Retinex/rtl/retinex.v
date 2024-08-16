//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           retinex.v
// Descriptions:        retinex算法
//-----------------------------------------README-----------------------------------------
// 为了减少资源开销，删减了一些消耗较大的步骤。
// 
// 可以对RGB彩图做处理：先转换到HSV空间，对V通道做处理，然后再还原回RGB。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module retinex #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080
    ) (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        output              dst_valid,
        output      [23:0]  dst_data
    );


    genvar  var;

    wire                src_y_valid;
    wire    [7:0]       src_y_data;
    wire                dst_y_valid;
    wire    [7:0]       dst_y_data;


    max max_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (src_valid),
        .src_data           (src_data),
        .src_last           (),
        .dst_valid          (src_y_valid),
        .dst_data           (src_y_data),
        .dst_index          (),
        .dst_last           ()
    );

    gamma gamma_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (src_y_valid),
        .src_data           (src_y_data),
        .dst_valid          (dst_y_valid),
        .dst_data           (dst_y_data)
    );

    wire    [15:0]      tmp;
    div #(
        .DELAY          (5)
    ) div_inst(
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (1'b1),
        .numerator      (16'hff00),
        .denominator    (dst_y_data),
        .done           (),
        .quotient       (tmp),
        .remainder      ()
    );

    wire    [23:0]      src_data_dly;
    delay #(
        .WIDTH      (24),
        .DELAY      (3+5)
    ) delay_src_data(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (src_data),
        .dout       (src_data_dly)
    );


    reg     [23:0]      tmp_rslt[0:2];
    generate
        for (var=0; var<3; var=var+1) begin: block
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    tmp_rslt[var] <= 0;
                else
                    tmp_rslt[var] <= src_data_dly[8*var+7:8*var] * tmp;
            end
            assign  dst_data[8*var+7:8*var] = |tmp_rslt[var][23:16] ? 8'd255 : tmp_rslt[var][15:8];
        end
    endgenerate


    delay #(
        .WIDTH      (1),
        .DELAY      (3+5+1)
    ) delay_dst_valid(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (src_valid),
        .dout       (dst_valid)
    );


endmodule
