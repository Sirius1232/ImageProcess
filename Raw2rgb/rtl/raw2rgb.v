//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           raw2rgb.v
// Descriptions:        RAW转RGB模块
//-----------------------------------------README-----------------------------------------
// 将GBRG格式图像转为RGB格式图像，并根据分辨率裁剪边缘。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module raw2rgb (
        input               clk,
        input               rst_n,
        input       [10:0]  src_width,
        input       [10:0]  src_height,
        input               src_valid,
        output              src_ready,
        input       [7:0]   src_data,
        input       [10:0]  dst_width,
        input       [10:0]  dst_height,
        output  reg         dst_valid,
        input               dst_ready,
        output      [23:0]  dst_data,
        output  reg         dst_start,
        output  reg         dst_line_last,
        output  reg         dst_last
    );

    genvar  var;

    /*全局参数*/
    wire    [10:0]      block_l, block_r, block_u, block_d;
    assign  block_l = 1;
    assign  block_r = dst_width + 1;
    assign  block_u = 1;
    assign  block_d = dst_height + 1;


    wire                block_valid;
    wire                block_ready;
    wire    [71:0]      block_data;
    block_3x3 block_3x3_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .src_width  (src_width),
        .src_height (src_height),
        .src_valid  (src_valid),
        .src_ready  (src_ready),
        .src_data   (src_data),
        .dst_valid  (block_valid),
        .dst_ready  (block_ready),
        .dst_data   (block_data)
    );
    assign  block_ready = dst_ready | (~dst_valid);


    wire    [7:0]       raw_data[0:8];
    generate
        for (var=0; var<9; var=var+1) begin: block
            assign  raw_data[var] = block_data[8*var+7:8*var];
        end
    endgenerate


    /*输入图像像素点坐标计数*/
    reg     [10:0]      block_cnt_w, block_cnt_h;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            block_cnt_h <= 0;
            block_cnt_w <= 0;
        end
        else begin
            if(block_valid & block_ready) begin
                if(block_cnt_w < src_width - 1) begin
                    block_cnt_h <= block_cnt_h;
                    block_cnt_w <= block_cnt_w + 1'b1;
                end
                else begin
                    block_cnt_h <= (block_cnt_h < src_height - 1) ? block_cnt_h + 1'b1 : 0;
                    block_cnt_w <= 0;
                end
            end
            else begin
                block_cnt_h <= block_cnt_h;
                block_cnt_w <= block_cnt_w;
            end
        end
    end


    wire    [1:0]       status;
    assign  status = {block_cnt_h[0], block_cnt_w[0]};


    reg     [7:0]       dst_r_data, dst_g_data, dst_b_data;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_r_data <= 0;
            dst_g_data <= 0;
            dst_b_data <= 0;
        end
        else begin
            if(block_valid & block_ready) begin
                case (status)
                    2'h0 : begin
                        dst_r_data <= (raw_data[1] + raw_data[7]) / 2;
                        dst_g_data <= (raw_data[0] + raw_data[2] + raw_data[4] + raw_data[6] + raw_data[8]) / 5;
                        dst_b_data <= (raw_data[3] + raw_data[5]) / 2;
                    end
                    2'h1 : begin
                        dst_r_data <= (raw_data[0] + raw_data[2] + raw_data[6] + raw_data[8]) / 4;
                        dst_g_data <= (raw_data[1] + raw_data[3] + raw_data[5] + raw_data[7]) / 4;
                        dst_b_data <= raw_data[4];
                    end
                    2'h2 : begin
                        dst_r_data <= raw_data[4];
                        dst_g_data <= (raw_data[1] + raw_data[3] + raw_data[5] + raw_data[7]) / 4;
                        dst_b_data <= (raw_data[0] + raw_data[2] + raw_data[6] + raw_data[8]) / 4;
                    end
                    2'h3 : begin
                        dst_r_data <= (raw_data[3] + raw_data[5]) / 2;
                        dst_g_data <= (raw_data[0] + raw_data[2] + raw_data[4] + raw_data[6] + raw_data[8]) / 5;
                        dst_b_data <= (raw_data[1] + raw_data[7]) / 2;
                    end
                endcase
            end
            else begin
                dst_r_data <= dst_r_data;
                dst_g_data <= dst_g_data;
                dst_b_data <= dst_b_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_valid <= 1'b0;
        end
        else begin
            if(block_ready) begin
                if(block_cnt_h>=block_u && block_cnt_h<block_d && block_cnt_w>=block_l && block_cnt_w<block_r)
                    dst_valid <= block_valid;
                else
                    dst_valid <= 1'b0;
            end
            else begin
                dst_valid <= dst_valid;
            end
        end
    end
    assign  dst_data = {dst_r_data, dst_g_data, dst_b_data};

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_start <= 1'b0;
            dst_line_last <= 1'b0;
            dst_last <= 1'b0;
        end
        else begin
            dst_start <= (block_cnt_h==block_u && block_cnt_w==block_l) ? block_valid & block_ready : 1'b0;
            dst_line_last <= (block_cnt_w==block_r-1 && block_cnt_h>=block_u && block_cnt_h<block_d) ? block_valid & block_ready : 1'b0;
            dst_last <= (block_cnt_h==block_d-1 && block_cnt_w==block_r-1) ? block_valid & block_ready : 1'b0;
        end
    end


endmodule
