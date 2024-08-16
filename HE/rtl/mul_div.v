//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           mul_div.v
// Descriptions:        乘法除法计算模块
//-----------------------------------------README-----------------------------------------
// 对RGB图像的三个通道分别做先乘后除的运算，其中一个通道的乘数与除数相同，由`skip_index`标记。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module mul_div (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        input       [15:0]  src_mul,
        input       [15:0]  src_div,
        input       [1:0]   skip_index,
        output              dst_valid,
        output  reg [23:0]  dst_data
    );


    reg     [7:0]       mul_data[0:2];
    always @(*) begin
        case (skip_index)
            2'd0 : begin
                mul_data[0] <= src_data[15: 8];
                mul_data[1] <= src_data[23:16];
                mul_data[2] <= src_data[ 7: 0];
            end
            2'd1 : begin
                mul_data[0] <= src_data[ 7: 0];
                mul_data[1] <= src_data[23:16];
                mul_data[2] <= src_data[15: 8];
            end
            2'd2 : begin
                mul_data[0] <= src_data[ 7: 0];
                mul_data[1] <= src_data[15: 8];
                mul_data[2] <= src_data[23:16];
            end
            default: begin
                mul_data[0] <= 8'd0;
                mul_data[1] <= 8'd0;
                mul_data[2] <= 8'd0;
            end
        endcase
    end


    /*乘法计算*/
    reg     [15:0]      tmp_mul[0:2];
    reg     [7:0]       tmp_div[0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp_mul[0] <= 0;
            tmp_mul[1] <= 0;
            tmp_mul[2] <= 0;
            tmp_div[0] <= 0;
            tmp_div[1] <= 0;
        end
        else begin
            tmp_mul[0] <= src_valid ? mul_data[0] * src_mul[ 7: 0] : 8'd0;
            tmp_mul[1] <= src_valid ? mul_data[1] * src_mul[15: 8] : 8'd0;
            tmp_mul[2] <= src_valid ? mul_data[2] : 8'd0;
            tmp_div[0] <= src_div[ 7: 0];
            tmp_div[1] <= src_div[15: 8];
        end
    end


    wire    [15:0]      tmp_rslt[0:2];
    div #(
        .DELAY          (5)
    ) div_inst_0(
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (1'b1),
        .numerator      (tmp_mul[0]),
        .denominator    (tmp_div[0]),
        .done           (),
        .quotient       (tmp_rslt[0]),
        .remainder      ()
    );
    div #(
        .DELAY          (5)
    ) div_inst_1(
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (1'b1),
        .numerator      (tmp_mul[1]),
        .denominator    (tmp_div[1]),
        .done           (),
        .quotient       (tmp_rslt[1]),
        .remainder      ()
    );

    delay #(
        .WIDTH      (16),
        .DELAY      (5)
    ) delay_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (tmp_mul[2]),
        .dout       (tmp_rslt[2])
    );

    /*限幅*/
    reg     [7:0]       tmp_clip[0:2];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            {tmp_clip[0], tmp_clip[1], tmp_clip[2]} <= 0;
        end
        else begin
            tmp_clip[0] <= |tmp_rslt[0][15:8] ? 8'd255 : tmp_rslt[0][7:0];
            tmp_clip[1] <= |tmp_rslt[1][15:8] ? 8'd255 : tmp_rslt[1][7:0];
            tmp_clip[2] <= |tmp_rslt[2][15:8] ? 8'd255 : tmp_rslt[2][7:0];
        end
    end

    wire    [1:0]       skip_index_dly;
    delay #(
        .WIDTH      (2),
        .DELAY      (2+5)
    ) delay_inst_1(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (skip_index),
        .dout       (skip_index_dly)
    );

    always @(*) begin
        case (skip_index_dly)
            2'd0 : begin
                dst_data[15: 8] = tmp_clip[0];
                dst_data[23:16] = tmp_clip[1];
                dst_data[ 7: 0] = tmp_clip[2];
            end
            2'd1 : begin
                dst_data[ 7: 0] = tmp_clip[0];
                dst_data[23:16] = tmp_clip[1];
                dst_data[15: 8] = tmp_clip[2];
            end
            2'd2 : begin
                dst_data[ 7: 0] = tmp_clip[0];
                dst_data[15: 8] = tmp_clip[1];
                dst_data[23:16] = tmp_clip[2];
            end
            default: begin
                dst_data[ 7: 0] = 8'd0;
                dst_data[15: 8] = 8'd0;
                dst_data[23:16] = 8'd0;
            end
        endcase
    end

    delay #(
        .WIDTH      (1),
        .DELAY      (2+5)
    ) delay_inst_2(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (src_valid),
        .dout       (dst_valid)
    );


endmodule
