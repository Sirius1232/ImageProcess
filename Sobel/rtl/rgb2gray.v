//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           rgb2gray.v
// Descriptions:        RGB转灰度模块
//-----------------------------------------README-----------------------------------------
// gray = 0.299 \cdot R + 0.587 \cdot G + 0.114 \cdot B
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module rgb2gray (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        output              dst_valid,
        output      [23:0]  dst_data
    );


    genvar  var;

    reg     [15:0]      tmp[0:2];
    reg     [15:0]      tmp_rslt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp[0] <= 0;
            tmp[1] <= 0;
            tmp[2] <= 0;
            tmp_rslt <= 0;
        end
        else begin
            tmp[0] <= src_data[ 7: 0] * 8'd27;  // b
            tmp[1] <= src_data[15: 8] * 8'd150; // g
            tmp[2] <= src_data[23:16] * 8'd77;  // r
            tmp_rslt <= tmp[0] + tmp[1] + tmp[2];
        end
    end


    delay #(
        .WIDTH      (1),
        .DELAY      (2)
    ) delay_dst_valid(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (src_valid),
        .dout       (dst_valid)
    );
    assign  dst_data = tmp_rslt[15:8];


endmodule
