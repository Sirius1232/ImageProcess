//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           block_3x3.v
// Descriptions:        输入图像取3x3滑动窗口
//-----------------------------------------README-----------------------------------------
// 通过shift_ram的方式来获取3x3窗口
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module block_3x3 (
        input               clk,
        input               rst_n,
        input       [10:0]  src_width,
        input       [10:0]  src_height,
        input               src_valid,
        output              src_ready,
        input       [7:0]   src_data,
        output              dst_valid,
        input               dst_ready,
        output      [71:0]  dst_data
    );

    genvar  var;


    reg     [10:0]      w_addr, r_addr;
    wire    [7:0]       w_data[0:1];
    wire    [7:0]       r_data[0:1];
    reg     [7:0]       slide_data[0:2][0:2];
    wire    [7:0]       block_data[0:2][0:2];
    reg                 block_inited;  // 已经累积一定数量数据，可以开始输出
    reg                 src_frame_done;
    reg     [10:0]      src_cnt_w, src_cnt_h;
    reg     [10:0]      dst_cnt_w, dst_cnt_h;
    wire                src_last;
    wire                dst_last;



    assign  src_ready = src_frame_done ? 1'b0 : dst_ready | (~dst_valid);
    assign  src_last = (src_cnt_h==src_height-1 && src_cnt_w==src_width-1) ? 1'b1 : 1'b0;
    assign  dst_last = (dst_cnt_h==src_height-1 && dst_cnt_w==src_width-1) ? 1'b1 : 1'b0;


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            src_frame_done <= 1'b0;
        end
        else begin
            if(src_last)  // 一帧输入完成
                src_frame_done <= (src_valid & src_ready) ? 1'b1 : src_frame_done;
            else if(dst_last)  // 一帧输出完成
                src_frame_done <= 1'b0;
            else
                src_frame_done <= src_frame_done;
        end
    end


    /*buffer的读写地址*/
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            w_addr <= src_width;
        end
        else begin
            if(dst_last)
                w_addr <= src_width;
            else if(src_valid & src_ready)
                w_addr <= src_last ? src_width : w_addr + 1'b1;
            else
                w_addr <= w_addr;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            r_addr <= 1;
        end
        else begin
            if((src_valid & src_ready) | src_frame_done)
                r_addr <= dst_last ? 1 : r_addr + 1'b1;
            else
                r_addr <= r_addr;
        end
    end

    /*数据缓存&窗口滑动*/
    always @(posedge clk) begin
        if((src_valid & src_ready) | src_frame_done) begin
            slide_data[0][0] <= block_data[0][1];
            slide_data[0][1] <= block_data[0][2];
            slide_data[0][2] <= 0;  // r_data[0]
            slide_data[1][0] <= block_data[1][1];
            slide_data[1][1] <= block_data[1][2];
            slide_data[1][2] <= 0;  // r_data[1]
            slide_data[2][0] <= block_data[2][1];
            slide_data[2][1] <= block_data[2][2];
            slide_data[2][2] <= src_data;
        end
    end

    assign  block_data[0][0] = slide_data[0][0];
    assign  block_data[0][1] = slide_data[0][1];
    assign  block_data[0][2] = r_data[0];
    assign  block_data[1][0] = slide_data[1][0];
    assign  block_data[1][1] = slide_data[1][1];
    assign  block_data[1][2] = r_data[1];
    assign  block_data[2][0] = slide_data[2][0];
    assign  block_data[2][1] = slide_data[2][1];
    assign  block_data[2][2] = slide_data[2][2];

    assign  w_data[0] = block_data[1][2];
    assign  w_data[1] = block_data[2][2];

    RAM #(
        .WIDTH      (16),
        .DEPTH      (2048)
    ) buffer(
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (src_valid & src_ready),
        .wr_addr    (w_addr),
        .wr_data    ({w_data[0], w_data[1]}),
        .rd_en      ((src_valid & src_ready) | src_frame_done),
        .rd_addr    (r_addr),
        .rd_data    ({r_data[0], r_data[1]})
    );



    /*输入图像像素点坐标计数*/
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            src_cnt_h <= 0;
            src_cnt_w <= 0;
        end
        else begin
            if(src_valid & src_ready) begin
                if(src_cnt_w < src_width - 1) begin
                    src_cnt_h <= src_cnt_h;
                    src_cnt_w <= src_cnt_w + 1'b1;
                end
                else begin
                    src_cnt_h <= (src_cnt_h < src_height - 1) ? src_cnt_h + 1'b1 : 0;
                    src_cnt_w <= 0;
                end
            end
            else begin
                src_cnt_h <= src_cnt_h;
                src_cnt_w <= src_cnt_w;
            end
        end
    end

    /*当输入数据累积到足够输出时，表示初始化完成*/
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            block_inited <= 1'b0;
        else begin
            if(src_valid & src_ready) begin
                if(src_cnt_h==1 && src_cnt_w==1)
                    block_inited <= 1'b1;
                else if(src_last)
                    block_inited <= 1'b0;
                else
                    block_inited <= block_inited;
            end
            else begin
                block_inited <= block_inited;
            end
        end
    end


    /*输出图像像素点坐标计数*/
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_cnt_h <= 0;
            dst_cnt_w <= 0;
        end
        else begin
            if(dst_valid & dst_ready) begin
                if(dst_cnt_w < src_width - 1) begin
                    dst_cnt_h <= dst_cnt_h;
                    dst_cnt_w <= dst_cnt_w + 1'b1;
                end
                else begin
                    dst_cnt_h <= (dst_cnt_h < src_height - 1) ? dst_cnt_h + 1'b1 : 0;
                    dst_cnt_w <= 0;
                end
            end
            else begin
                dst_cnt_h <= dst_cnt_h;
                dst_cnt_w <= dst_cnt_w;
            end
        end
    end


    /*判断边界情况*/
    wire    [1:0]       rows[0:2];
    wire    [1:0]       cols[0:2];
    assign  rows[0] = (dst_cnt_h==0) ? 2'd1 : 2'd0;
    assign  rows[1] = 2'd1;
    assign  rows[2] = (dst_cnt_h==src_height-1'b1) ? 2'd1 : 2'd2;
    assign  cols[0] = (dst_cnt_w==0) ? 2'd1 : 2'd0;
    assign  cols[1] = 2'd1;
    assign  cols[2] = (dst_cnt_w==src_width-1'b1) ? 2'd1 : 2'd2;

    /*考虑边界情况的输出映射（复制临近的值）*/
    wire    [7:0]       block_data_ex[0:8];
    assign  block_data_ex[0] = block_data[rows[0]][cols[0]];
    assign  block_data_ex[1] = block_data[rows[0]][cols[1]];
    assign  block_data_ex[2] = block_data[rows[0]][cols[2]];
    assign  block_data_ex[3] = block_data[rows[1]][cols[0]];
    assign  block_data_ex[4] = block_data[rows[1]][cols[1]];
    assign  block_data_ex[5] = block_data[rows[1]][cols[2]];
    assign  block_data_ex[6] = block_data[rows[2]][cols[0]];
    assign  block_data_ex[7] = block_data[rows[2]][cols[1]];
    assign  block_data_ex[8] = block_data[rows[2]][cols[2]];


    /*输出*/
    assign  dst_valid = (block_inited & src_valid) | src_frame_done;
    generate
        for (var=0; var<9; var=var+1) begin: block
            assign  dst_data[8*var+7:8*var] = dst_valid ? block_data_ex[var] : 8'h00;
        end
    endgenerate



endmodule
