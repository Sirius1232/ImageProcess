//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           max.v
// Descriptions:        最大值计算模块
//-----------------------------------------README-----------------------------------------
// 求输入的RGB像素点`src_data`三个通道中的最大值。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module max (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        input               src_last,
        output              dst_valid,
        output  reg [7:0]   dst_data,
        output  reg [1:0]   dst_index,
        output              dst_last
    );


    reg     [7:0]      tmp[0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp[0] <= 0;
            tmp[1] <= 0;
            dst_data <= 0;
        end
        else begin
            tmp[0] <= src_data[23:16] > src_data[15:8] ? src_data[23:16] : src_data[15:8];
            tmp[1] <= src_data[7:0];
            dst_data <= tmp[0] > tmp [1] ? tmp[0] : tmp [1];
        end
    end

    reg     [1:0]       tmp_index;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp_index <= 0;
            dst_index <= 0;
        end
        else begin
            tmp_index <= src_data[23:16] > src_data[15:8] ? 2'd2 : 2'd1;
            dst_index <= tmp[0] > tmp [1] ? tmp_index : 2'd0;
        end
    end


    reg     [2:1]       src_valid_d, src_last_d;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            src_valid_d <= 3'b0;
            src_last_d <= 3'b0;
        end
        else begin
            src_valid_d <= {src_valid, src_valid_d[2:2]};
            src_last_d <= {src_last, src_last_d[2:2]};
        end
    end
    assign  dst_valid = src_valid_d[1];
    assign  dst_last = src_last_d[1];


endmodule
