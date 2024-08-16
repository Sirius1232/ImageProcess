//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           img_scale.v
// Descriptions:        基于双线性插值算法的图像缩放
//-----------------------------------------README-----------------------------------------
// 这里只考虑了把小尺寸图像等比例放大为1920×1080的图像；算法可以支持任意尺寸的放大，但需要修改部分信号位宽。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module img_scale #(
        parameter   WIDTH = 1920,  // 输出图像的宽度
        parameter   HEIGHT = 1080  // 输出图像的高度
    ) (
        input               clk,
        input               rst_n,
        input       [10:0]  src_height,  // 输入图像的高度
        input       [10:0]  src_width,  // 输入图像的宽度
        input               src_valid,
        output              src_ready,
        input       [23:0]  src_data,
        input               src_line_last,  // 表示一行图像的最后一个像素点
        input       [8:0]   param,  // 缩放参数, =256/放大倍率
        output              dst_valid,
        output      [23:0]  dst_data
    );

    genvar  var;


    reg     [10:0]      src_cnt_h;
    reg     [10:0]      src_cnt_w;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            src_cnt_h <= 0;
            src_cnt_w <= 0;
        end
        else if(src_valid & src_ready) begin
            if(src_cnt_w < src_width - 1'b1) begin
                src_cnt_h <= src_cnt_h;
                src_cnt_w <= src_cnt_w + 1'b1;
            end
            else begin
                src_cnt_h <= (src_cnt_h < src_height - 1'b1) ? src_cnt_h + 1'b1 : 0;
                src_cnt_w <= 0;
            end
        end
        else begin
            src_cnt_h <= src_cnt_h;
            src_cnt_w <= src_cnt_w;
        end
    end

    wire                src_move;
    reg     [2:0]       img_cnt;
    reg                 src_frame_done;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            img_cnt <= 3'd0;
        end
        else if(src_frame_done) begin
            img_cnt <= 3'd0;
        end
        else begin
            case ({src_line_last, src_move})
                2'b00 : img_cnt <= img_cnt;
                2'b01 : img_cnt <= (img_cnt > 0) ? img_cnt - 1'b1 : 3'd0;
                2'b10 : img_cnt <= img_cnt + 1'b1;
                2'b11 : img_cnt <= img_cnt;
            endcase
        end
    end
    assign  src_ready = (img_cnt < 4) ? ~src_frame_done : 1'b0;  // 一帧输入完成后暂停输入


    reg     [3:0]       ram_wr_en;
    reg     [10:0]      ram_wr_addr;
    reg     [31:0]      ram_wr_data;
    reg     [10:0]      ram_rd_addr[0:3];
    wire    [31:0]      ram_rd_data[0:3];

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ram_wr_en <= 4'b0000;
        end
        else if(src_valid & src_ready) begin
            case ({src_cnt_h[0], src_cnt_w[0]})
                2'b00 : ram_wr_en <= 4'b0001;
                2'b01 : ram_wr_en <= 4'b0010;
                2'b10 : ram_wr_en <= 4'b0100;
                2'b11 : ram_wr_en <= 4'b1000;
            endcase
        end
        else begin
            ram_wr_en <= 4'b0000;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ram_wr_addr <= 0;
            ram_wr_data <= 0;
        end
        else begin
            ram_wr_addr <= {src_cnt_h[1], src_cnt_w[10:1]};
            ram_wr_data <= {8'b0, src_data};
        end
    end



    /*双线性插值*/
    wire    working;
    assign  working = (img_cnt>3'd2 || src_frame_done) ? 1'b1 : 1'b0;  // 缓存下至少两行数据或一帧图像输入全部完成
    reg     [10:0]      dst_cnt_h, dst_cnt_w;  // 不是最终输出的计数器
    wire                tmp_last = (dst_cnt_h==HEIGHT-1 && dst_cnt_w==WIDTH-1) ? working : 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dst_cnt_h <= 0;
            dst_cnt_w <= 0;
        end
        else if(working) begin
            if(dst_cnt_w < WIDTH - 1'b1) begin
                dst_cnt_h <= dst_cnt_h;
                dst_cnt_w <= dst_cnt_w + 1'b1;
            end
            else begin
                dst_cnt_h <= (dst_cnt_h < HEIGHT - 1'b1) ? dst_cnt_h + 1'b1 : 0;
                dst_cnt_w <= 0;
            end
        end
        else begin
            dst_cnt_h <= dst_cnt_h;
            dst_cnt_w <= dst_cnt_w;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            src_frame_done <= 1'b0;
        end
        else begin
            if(src_line_last && src_cnt_h==src_height-1)  // 一帧输入完成
                src_frame_done <= 1'b1;
            else if(tmp_last)  // 一帧输出完成（全部取出参与计算，可能还没算完）
                src_frame_done <= 1'b0;
            else
                src_frame_done <= src_frame_done;
        end
    end


    /*计算地址，获取数据*/
    reg     [18:0]      tmp_i, tmp_j;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp_i <= 0;
            tmp_j <= 0;
        end
        else if(working) begin
            if(dst_cnt_w < WIDTH - 1'b1) begin
                tmp_i <= tmp_i;
                tmp_j <= tmp_j + param;
            end
            else begin
                tmp_i <= (dst_cnt_h < HEIGHT - 1'b1) ? tmp_i + param : 0;
                tmp_j <= 0;
            end
        end
        else begin
            tmp_i <= tmp_i;
            tmp_j <= tmp_j;
        end
    end

    wire    [10:0]      block_i, block_j;
    assign  block_i = tmp_i[18:8];
    assign  block_j = tmp_j[18:8];

    wire    flag_u_d, flag_l_r;
    assign  flag_u_d = ((block_i == 0) || (block_i == src_height - 1)) ? 1'b0 : 1'b1;
    assign  flag_l_r = ((block_j == 0) || (block_j == src_width - 1)) ? 1'b0 : 1'b1;

    reg     [10:0]      num[0:3][0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            {num[0][0], num[0][1]} <= 0;
            {num[1][0], num[1][1]} <= 0;
            {num[2][0], num[2][1]} <= 0;
            {num[3][0], num[3][1]} <= 0;
        end
        else begin
            {num[0][0], num[0][1]} <= {block_i, block_j};
            {num[1][0], num[1][1]} <= {block_i, block_j + flag_l_r};
            {num[2][0], num[2][1]} <= {block_i + flag_u_d, block_j};
            {num[3][0], num[3][1]} <= {block_i + flag_u_d, block_j + flag_l_r};
        end
    end

    reg     [10:0]      num_dly[0:3][0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            {num_dly[0][0], num_dly[0][1]} <= 0;
            {num_dly[1][0], num_dly[1][1]} <= 0;
            {num_dly[2][0], num_dly[2][1]} <= 0;
            {num_dly[3][0], num_dly[3][1]} <= 0;
        end
        else begin
            {num_dly[0][0], num_dly[0][1]} <= {num[0][0], num[0][1]};
            {num_dly[1][0], num_dly[1][1]} <= {num[1][0], num[1][1]};
            {num_dly[2][0], num_dly[2][1]} <= {num[2][0], num[2][1]};
            {num_dly[3][0], num_dly[3][1]} <= {num[3][0], num[3][1]};
        end
    end

    generate  // 地址映射
        for (var=0; var<4; var=var+1) begin: block1
            always @(*) begin
                if({num[0][0][0], num[0][1][0]}==var)
                    ram_rd_addr[var] = {num[0][0][1], num[0][1][10:1]};
                else if({num[1][0][0], num[1][1][0]}==var)
                    ram_rd_addr[var] = {num[1][0][1], num[1][1][10:1]};
                else if({num[2][0][0], num[2][1][0]}==var)
                    ram_rd_addr[var] = {num[2][0][1], num[2][1][10:1]};
                else if({num[3][0][0], num[3][1][0]}==var)
                    ram_rd_addr[var] = {num[3][0][1], num[3][1][10:1]};
                else
                    ram_rd_addr[var] = 0;
            end
        end
    endgenerate

    reg     [23:0]      tmp_img[0:3];
    generate  // 数据选择
        for (var=0; var<4; var=var+1) begin: block2
            always @(*) begin
                case ({num_dly[var][0][0], num_dly[var][1][0]})
                    2'b00 : tmp_img[var] = ram_rd_data[0][23:0];
                    2'b01 : tmp_img[var] = ram_rd_data[1][23:0];
                    2'b10 : tmp_img[var] = ram_rd_data[2][23:0];
                    2'b11 : tmp_img[var] = ram_rd_data[3][23:0];
                endcase
            end
        end
    endgenerate


    reg     [15:0]      tmp_u[0:1];
    reg     [15:0]      tmp_v[0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp_u[0] <= 0;
            tmp_u[1] <= 0;
            tmp_v[0] <= 0;
            tmp_v[1] <= 0;
        end
        else begin
            tmp_u[0] <= 256 - tmp_j[7:0];
            tmp_u[1] <= tmp_j[7:0];
            tmp_v[0] <= 256 - tmp_i[7:0];
            tmp_v[1] <= tmp_i[7:0];
        end
    end

    reg     [7:0]       u;
    reg     [7:0]       u_dly;
    reg     [7:0]       v;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            u <= 0;
            u_dly <= 0;
            v <= 0;
        end
        else begin
            u <= tmp_u[1];
            u_dly <= u;
            v <= tmp_v[1];
        end
    end


    /*判断是否需要补充数据*/
    reg     [10:0]      num_i_dly;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            num_i_dly <= 0;
        else
            num_i_dly <= block_i;
    end

    assign  src_move = (block_i != num_i_dly) ? 1'b1 : 1'b0;


    /*加权平均*/
    reg     [15:0]      tmp_mul[0:2][0:1];
    reg     [23:0]      tmp[0:2];
    generate
        for (var=0; var<3; var=var+1) begin: block3
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    tmp_mul[var][0] <= 0;
                    tmp_mul[var][1] <= 0;
                    tmp[var] <= 0;
                end
                else begin
                    tmp_mul[var][0] <= (256 - v) * tmp_img[0][8*var+7:8*var] + v * tmp_img[2][8*var+7:8*var];
                    tmp_mul[var][1] <= (256 - v) * tmp_img[1][8*var+7:8*var] + v * tmp_img[3][8*var+7:8*var];
                    tmp[var] <= (256 - u_dly) * tmp_mul[var][0] + u_dly * tmp_mul[var][1];
                end
            end
            assign  dst_data[8*var+7:8*var] = tmp[var][23:16];
        end
    endgenerate

    /*控制信号输出*/
    delay #(
        .WIDTH      (1),
        .DELAY      (4)
    ) delay_working(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        (working),
        .dout       (dst_valid)
    );


    /*BRAM*/
    generate
        for (var=0; var<4; var=var+1) begin: block_ram
            RAM #(
                .WIDTH      (32),
                .DEPTH      (2048)
            ) ram_inst(
                .clk        (clk),
                .rst_n      (rst_n),
                .wr_en      (ram_wr_en[var]),
                .wr_addr    (ram_wr_addr),
                .wr_data    (ram_wr_data),
                .rd_en      (1'b1),
                .rd_addr    (ram_rd_addr[var]),
                .rd_data    (ram_rd_data[var])
            );
        end
    endgenerate


endmodule
