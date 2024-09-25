//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           sobel.v
// Descriptions:        Sobel边缘检测算法
//-----------------------------------------README-----------------------------------------
// 
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module sobel #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080
    ) (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [23:0]  src_data,
        output  reg         dst_valid,
        output  reg [23:0]  dst_data
    );


    genvar  var;


    wire                gray_valid;
    wire                gray_ready;  // TODO: 补上ready信号
    wire    [7:0]       gray_data;
    rgb2gray rgb2gray_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_valid          (src_valid),
        .src_data           (src_data),
        .dst_valid          (gray_valid),
        .dst_data           (gray_data)
    );


    wire                block_valid;
    wire    [71:0]      block_data;
    block_3x3 block_3x3_inst(
        .clk            (clk),
        .rst_n          (rst_n),
        .src_width      (WIDTH),
        .src_height     (HEIGHT),
        .src_valid      (gray_valid),
        .src_ready      (gray_ready),
        .src_data       (gray_data),
        .dst_valid      (block_valid),
        .dst_ready      (1'b1),
        .dst_data       (block_data)
    );


    reg     [9:0]       gradx_tmp_data[0:1];
    reg     [9:0]       grady_tmp_data[0:1];
    reg     [9:0]       gradx_data;
    reg     [9:0]       grady_data;
    reg     [9:0]       grad_data;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            gradx_tmp_data[0] <= 0;
            gradx_tmp_data[1] <= 0;
            grady_tmp_data[0] <= 0;
            grady_tmp_data[1] <= 0;
            gradx_data <= 0;
            grady_data <= 0;
            grad_data <= 0;
        end
        else begin
            gradx_tmp_data[0] <= block_data[ 7: 0] + {block_data[31:24], 1'b0} + block_data[55:48];
            gradx_tmp_data[1] <= block_data[23:16] + {block_data[47:40], 1'b0} + block_data[71:64];
            grady_tmp_data[0] <= block_data[ 7: 0] + {block_data[15: 8], 1'b0} + block_data[23:16];
            grady_tmp_data[1] <= block_data[55:48] + {block_data[63:56], 1'b0} + block_data[71:64];
            gradx_data <= (gradx_tmp_data[0]>gradx_tmp_data[1]) ? (gradx_tmp_data[0] - gradx_tmp_data[1]) : (gradx_tmp_data[1] - gradx_tmp_data[0]);
            grady_data <= (grady_tmp_data[0]>grady_tmp_data[1]) ? (grady_tmp_data[0] - grady_tmp_data[1]) : (grady_tmp_data[1] - grady_tmp_data[0]);
            grad_data <= gradx_data + grady_data;
        end
    end
    wire    [7:0]       sobel_data;
    assign  sobel_data = |grad_data[9:8] ? 8'hff : grad_data[7:0];


    wire                sobel_valid;
    delay #(
        .WIDTH      (1),
        .DELAY      (3)
    ) delay_dst_valid(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (block_valid),
        .dout       (sobel_valid)
    );


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_valid <= 0;
            dst_data <= 0;
        end
        else begin
            dst_valid <= sobel_valid;
            dst_data  <= {3{sobel_data}};
        end
    end

    reg     [10:0]      dst_cnt_h, dst_cnt_w;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_cnt_h <= 0;
            dst_cnt_w <= 0;
        end
        else begin
            if(dst_valid) begin
                if(dst_cnt_w < WIDTH - 1) begin
                    dst_cnt_h <= dst_cnt_h;
                    dst_cnt_w <= dst_cnt_w + 1'b1;
                end
                else begin
                    dst_cnt_h <= (dst_cnt_h < HEIGHT - 1) ? dst_cnt_h + 1'b1 : 0;
                    dst_cnt_w <= 0;
                end
            end
            else begin
                dst_cnt_h <= dst_cnt_h;
                dst_cnt_w <= dst_cnt_w;
            end
        end
    end



endmodule
