//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           awb.v
// Descriptions:        基于灰度世界假设的AWB算法
//-----------------------------------------README-----------------------------------------
// 
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module awb #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080
    ) (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        input               src_start,
        input               src_last,
        output              dst_valid,
        output      [23:0]  dst_data
    );

    reg     pingpong;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pingpong <= 1'b0;
        end
        else begin
            pingpong <= src_last ? ~pingpong : pingpong;
        end
    end


    reg     [28:0]      sum_ch[0:2];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum_ch[0] <= 0;
            sum_ch[1] <= 0;
            sum_ch[2] <= 0;
        end
        else if(~pingpong & src_valid) begin
            sum_ch[0] <= src_start ? src_data[ 7: 0] : sum_ch[0] + src_data[ 7: 0];  // b
            sum_ch[1] <= src_start ? src_data[15: 8] : sum_ch[1] + src_data[15: 8];  // g
            sum_ch[2] <= src_start ? src_data[23:16] : sum_ch[2] + src_data[23:16];  // r
        end
        else begin
            sum_ch[0] <= sum_ch[0];
            sum_ch[1] <= sum_ch[1];
            sum_ch[2] <= sum_ch[2];
        end
    end


    reg     [7:0]       mean_ch[0:2];  // 这里会丢掉最后一个像素点的值，但几乎没有影响
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mean_ch[0] <= 0;
            mean_ch[1] <= 0;
            mean_ch[2] <= 0;
        end
        else begin
            mean_ch[0] <= src_last ? sum_ch[0][28:21] : mean_ch[0];
            mean_ch[1] <= src_last ? sum_ch[1][28:21] : mean_ch[1];
            mean_ch[2] <= src_last ? sum_ch[2][28:21] : mean_ch[2];
        end
    end

    reg                 muldiv_valid;
    reg     [23:0]      muldiv_data;
    reg     [15:0]      muldiv_mul;
    reg     [15:0]      muldiv_div;
    wire    [1:0]       skip_index;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            muldiv_valid <= 1'b0;
            muldiv_data <= 1'b0;
            muldiv_mul <= {8'd128, 8'd128};
            muldiv_div <= {8'd128, 8'd128};
        end
        else begin
            muldiv_valid <= pingpong & src_valid;
            muldiv_data <= src_data;
            muldiv_mul <= {mean_ch[1], mean_ch[1]};
            muldiv_div <= {mean_ch[2], mean_ch[0]};
        end
    end
    assign  skip_index = 2'd1;

    /*平衡*/
    mul_div mul_div_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (muldiv_valid),
        .src_data           (muldiv_data),
        .src_mul            (muldiv_mul),
        .src_div            (muldiv_div),
        .skip_index         (skip_index),
        .dst_valid          (dst_valid),
        .dst_data           (dst_data)
    );


endmodule
