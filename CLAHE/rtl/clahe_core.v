//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           clahe_core.v
// Descriptions:        CLAHE算法的核心计算模块
//-----------------------------------------README-----------------------------------------
// 该模块处理单个通道（灰度）图像，需要对RGB图像操作的话，需要在模块外拆分通道或计算灰度。
// 
// 参数可配置图像的分辨率`WIDTH`和`HEIGHT`，以及算法的分块个数（水平、竖直均分为`BLOCK`块，共`BLOCK*BLOCK`块）。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module clahe_core #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080,
        parameter   BLOCK = 8
    ) (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [7:0]   src_data,
        input               src_last,
        output              dst_valid,
        output  reg [7:0]   dst_data
    );

    localparam  BLOCK_W = WIDTH / BLOCK;  // 块的宽度
    localparam  BLOCK_H = HEIGHT / BLOCK;  // 块的高度
    localparam  TOTAL = BLOCK_W * BLOCK_H;  // 块内像素数量
    localparam  LIMIT = 4 * TOTAL / 256;  // 直方图对比度限制
    localparam  SCALE = TOTAL * TOTAL / 255 / 128 / 256;  // 算法内所有小数除法汇总

    localparam  WID_B = $clog2(BLOCK);
    localparam  WID_B_W = $clog2(BLOCK_W);
    localparam  WID_B_H = $clog2(BLOCK_H);

    reg     pingpong;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pingpong <= 1'b0;
        end
        else begin
            pingpong <= src_last ? ~pingpong : pingpong;
        end
    end

    genvar  var;
    integer i;

    /*像素点坐标计数*/
    reg     [WID_B-1:0]     num_w, num_h;
    reg     [WID_B_W-1:0]   cnt_w;
    reg     [WID_B_H-1:0]   cnt_h;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            num_w <= 0;
            num_h <= 0;
            cnt_w <= 0;
            cnt_h <= 0;
        end
        else if(src_valid) begin
            if(cnt_w < BLOCK_W - 1) begin
                cnt_w <= cnt_w + 1'b1;
                num_w <= num_w;
            end
            else begin
                cnt_w <= 0;
                num_w <= num_w + 1'b1;
            end
            if(cnt_w == BLOCK_W - 1 && num_w == BLOCK - 1) begin
                if(cnt_h < BLOCK_H - 1) begin
                    cnt_h <= cnt_h + 1'b1;
                    num_h <= num_h;
                end
                else begin
                    cnt_h <= 0;
                    num_h <= num_h + 1'b1;
                end
            end
            else begin
                cnt_h <= cnt_h;
                num_h <= num_h;
            end
        end
        else begin
            num_w <= num_w;
            num_h <= num_h;
            cnt_w <= cnt_w;
            cnt_h <= cnt_h;
        end
    end

    wire    block_line_done;
    assign  block_line_done = (num_w==BLOCK-1 && cnt_w==BLOCK_W-1 && cnt_h==BLOCK_H-1) ? ~pingpong & src_valid : 1'b0;

    reg                 src_valid_dly;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            src_valid_dly <= 1'b0;
        else
            src_valid_dly <= ~pingpong & src_valid;
    end

    /*统计分布直方图*/
    reg                     cdf_calc, cdf_calc_dly;
    reg     [WID_B+8-1:0]   cdf_cnt, cdf_cnt_dly;

    wire    pdf_pingpong;
    assign  pdf_pingpong = num_h[0];
    reg     pdf_pingpong_dly;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            pdf_pingpong_dly <= 1'b0;
        else
            pdf_pingpong_dly <= pdf_pingpong;
    end

    reg     [1:0]       ram2_wr_en;
    reg     [10:0]      ram2_wr_addr[0:1];
    wire    [15:0]      ram2_wr_data[0:1];
    wire    [10:0]      ram2_rd_addr[0:1];
    wire    [15:0]      ram2_rd_data[0:1];

    wire    [15:0]      pdf;
    reg     [15:0]      pdf_reg;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pdf_reg <= 0;
        end
        else begin
            if(~pingpong & src_valid)
                pdf_reg <= ram2_wr_data[pdf_pingpong_dly];
            else
                pdf_reg <= 0;
        end
    end

    reg     [15:0]  steal[0:1][0:BLOCK-1];

    reg     [2:0]   num_w_dly;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            num_w_dly <= 1'b0;
        else
            num_w_dly <= num_w;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (i=0; i<BLOCK; i=i+1) begin
                steal[0][i] <= 0;
                steal[1][i] <= 0;
            end
        end
        else begin
            if(~pingpong & src_valid) begin
                if(pdf <= LIMIT) begin
                    steal[pdf_pingpong_dly][num_w_dly] <= steal[pdf_pingpong_dly][num_w_dly];
                end
                else begin
                    steal[pdf_pingpong_dly][num_w_dly] <= steal[pdf_pingpong_dly][num_w_dly] + 1'b1;
                end
            end
            else begin
                for (i=0; i<BLOCK; i=i+1) begin
                    steal[pdf_pingpong_dly][i] <= steal[pdf_pingpong_dly][i];
                end
            end
            steal[~pdf_pingpong_dly][cdf_cnt_dly[10:8]] <= &cdf_cnt_dly[7:0] ? 0 : steal[~pdf_pingpong_dly][cdf_cnt_dly[10:8]];
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ram2_wr_en <= 2'b00;
        end
        else begin
            if(~pingpong & src_valid) begin
                ram2_wr_en[0] <= ~pdf_pingpong_dly ? 1'b1 : cdf_calc_dly;
                ram2_wr_en[1] <= pdf_pingpong_dly ? 1'b1 : cdf_calc_dly;
            end
            else
                ram2_wr_en <= 2'b00;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ram2_wr_addr[0] <= 0;
            ram2_wr_addr[1] <= 0;
        end
        else begin
            ram2_wr_addr[0] <= ram2_rd_addr[0];
            ram2_wr_addr[1] <= ram2_rd_addr[1];
        end
    end

    reg                 cache_flag;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cache_flag <= 1'b0;
        end
        else begin
            cache_flag <= (ram2_rd_addr[pdf_pingpong]==ram2_wr_addr[pdf_pingpong_dly]) ? src_valid_dly & src_valid : 1'b0;
        end
    end

    assign  pdf = cache_flag ? pdf_reg + 1'b1 : ram2_rd_data[pdf_pingpong_dly] + 1'b1;
    assign  ram2_wr_data[0] = ~pdf_pingpong_dly ? (pdf <= LIMIT) ? pdf : LIMIT : 0;
    assign  ram2_wr_data[1] = pdf_pingpong_dly ? (pdf <= LIMIT) ? pdf : LIMIT : 0;

    assign  ram2_rd_addr[0] = ~pdf_pingpong ? {num_w, src_data} : cdf_cnt;
    assign  ram2_rd_addr[1] = pdf_pingpong ? {num_w, src_data} : cdf_cnt;


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf_calc <= 1'b0;
        end
        else begin
            if(block_line_done)
                cdf_calc <= 1'b1;
            else if(&cdf_cnt)
                cdf_calc <= 1'b0;
            else
                cdf_calc <= cdf_calc;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            cdf_calc_dly <= 1'b0;
        else
            cdf_calc_dly <= cdf_calc;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf_cnt <= 0;
            cdf_cnt_dly <= cdf_cnt;
        end
        else begin
            cdf_cnt <= cdf_calc ? cdf_cnt + 1'b1 : 0;
            cdf_cnt_dly <= cdf_cnt;
        end
    end

    reg     [14:0]  cdf;  // 累积分布直方图
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf <= 0;
        end
        else if(cdf_calc_dly) begin
            if(cdf_cnt_dly[7:0]==0)
                cdf <= ram2_rd_data[~pdf_pingpong_dly] + steal[~pdf_pingpong_dly][cdf_cnt_dly[10:8]][15:8];
            else
                cdf <= cdf + ram2_rd_data[~pdf_pingpong_dly] + steal[~pdf_pingpong_dly][cdf_cnt_dly[10:8]][15:8];
        end
        else begin
            cdf <= cdf;
        end
    end



    /*输出cdf，即写入RAM*/
    wire    [2*WID_B-1:0]   block_addr;
    assign  block_addr = {num_h-1'b1, cdf_cnt_dly[10:8]};

    reg     [3:0]       ram_wr_en;
    reg     [11:0]      ram_wr_addr;
    wire    [7:0]       ram_wr_data;
    reg     [11:0]      ram_rd_addr[0:3];
    wire    [7:0]       ram_rd_data[0:3];


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ram_wr_en <= 4'b0000;
        end
        else if(cdf_calc_dly) begin
            case ({block_addr[3], block_addr[0]})
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
        if(!rst_n)
            ram_wr_addr <= 0;
        else
            ram_wr_addr <= {block_addr[5:4], block_addr[2:1], cdf_cnt_dly[7:0]};
    end
    assign  ram_wr_data = cdf[14:7];



    /*均衡化*/
    wire    flag_w, flag_h;
    assign  flag_w = (cnt_w < BLOCK_W / 2) ? 1'b1 : 1'b0;
    assign  flag_h = (cnt_h < BLOCK_H / 2) ? 1'b1 : 1'b0;

    wire    [WID_B-1:0]     img_num_i, img_num_j;
    assign  img_num_i = (num_h==0) ? 0 : num_h - flag_h;
    assign  img_num_j = (num_w==0) ? 0 : num_w - flag_w;

    wire    flag_l_r, flag_u_d;
    assign  flag_l_r = ((num_w == 0 && flag_w == 1) || (num_w == BLOCK - 1 && flag_w == 0)) ? 1'b0 : 1'b1;
    assign  flag_u_d = ((num_h == 0 && flag_h == 1) || (num_h == BLOCK - 1 && flag_h == 0)) ? 1'b0 : 1'b1;

    reg     [2*WID_B-1:0]   img_num[0:3];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            img_num[0] <= 0;
            img_num[1] <= 0;
            img_num[2] <= 0;
            img_num[3] <= 0;
        end
        else begin
            img_num[0] <= {img_num_i, img_num_j};
            img_num[1] <= {img_num_i, img_num_j + flag_l_r};
            img_num[2] <= {img_num_i + flag_u_d, img_num_j};
            img_num[3] <= {img_num_i + flag_u_d, img_num_j + flag_l_r};
        end
    end

    reg     [2*WID_B-1:0]   img_num_dly[0:3];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            img_num_dly[0] <= 0;
            img_num_dly[1] <= 0;
            img_num_dly[2] <= 0;
            img_num_dly[3] <= 0;
        end
        else begin
            img_num_dly[0] <= img_num[0];
            img_num_dly[1] <= img_num[1];
            img_num_dly[2] <= img_num[2];
            img_num_dly[3] <= img_num[3];
        end
    end

    reg     [7:0]       src_data_dly;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            src_data_dly <= 0;
        else
            src_data_dly <= src_data;
    end

    generate  // 地址映射
        for (var=0; var<4; var=var+1) begin: block1
            always @(*) begin
                if({img_num[0][3], img_num[0][0]}==var)
                    ram_rd_addr[var] = {img_num[0][5:4], img_num[0][2:1], src_data_dly};
                else if({img_num[1][3], img_num[1][0]}==var)
                    ram_rd_addr[var] = {img_num[1][5:4], img_num[1][2:1], src_data_dly};
                else if({img_num[2][3], img_num[2][0]}==var)
                    ram_rd_addr[var] = {img_num[2][5:4], img_num[2][2:1], src_data_dly};
                else if({img_num[3][3], img_num[3][0]}==var)
                    ram_rd_addr[var] = {img_num[3][5:4], img_num[3][2:1], src_data_dly};
                else
                    ram_rd_addr[var] = 0;
            end
        end
    endgenerate

    reg     [7:0]       tmp_cdf[0:3];
    generate  // 数据选择
        for (var=0; var<4; var=var+1) begin: block2
            always @(*) begin
                case ({img_num_dly[var][3], img_num_dly[var][0]})
                    2'b00 : tmp_cdf[var] = ram_rd_data[0];
                    2'b01 : tmp_cdf[var] = ram_rd_data[1];
                    2'b10 : tmp_cdf[var] = ram_rd_data[2];
                    2'b11 : tmp_cdf[var] = ram_rd_data[3];
                endcase
            end
        end
    endgenerate


    /*计算权重*/
    reg     [WID_B_W-1:0]   tmp_u[0:1];
    reg     [WID_B_H-1:0]   tmp_v[0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp_u[0] <= 0;
            tmp_u[1] <= 0;
            tmp_v[0] <= 0;
            tmp_v[1] <= 0;
        end
        else begin
            tmp_u[0] <= cnt_w - BLOCK_W / 2;
            tmp_u[1] <= (num_w - img_num_j) * BLOCK_W;
            tmp_v[0] <= cnt_h - BLOCK_H / 2;
            tmp_v[1] <= (num_h - img_num_i) * BLOCK_H;
        end
    end

    reg     [WID_B_W-1:0]   u_dly;
    reg     [WID_B_W-1:0]   u;
    reg     [WID_B_H-1:0]   v;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            u <= 0;
            u_dly <= 0;
            v <= 0;
        end
        else begin
            u <= tmp_u[0] + tmp_u[1];
            u_dly <= u;
            v <= tmp_v[0] + tmp_v[1];
        end
    end


    /*加权平均*/
    reg     [15:0]      tmp;
    reg     [15:0]      tmp_mul[0:1];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tmp_mul[0] <= 0;
            tmp_mul[1] <= 0;
            tmp <= 0;
        end
        else begin
            tmp_mul[0] <= (BLOCK_H - v) * tmp_cdf[0] + v * tmp_cdf[2];
            tmp_mul[1] <= (BLOCK_H - v) * tmp_cdf[1] + v * tmp_cdf[3];
            tmp <= (BLOCK_W - u_dly) * tmp_mul[0][15:8] + u_dly * tmp_mul[1][15:8];
        end
    end


    // Signal `src_valid` delayed by 5 cycles
    reg     [5:1]       src_valid_d;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            src_valid_d <= 5'b0;
        else
            src_valid_d <= {pingpong ? src_valid : 1'b0, src_valid_d[5:2]};
    end
    assign  dst_valid = src_valid_d[1];
    /*除法计算，后续要替换为IP核*/
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            dst_data <= 0;
        else
            dst_data <= tmp / SCALE;
    end


    /*RAM*/
    generate
        for (var=0; var<4; var=var+1) begin: block
            RAM #(
                .WIDTH      (8),
                .DEPTH      (4096)
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

    generate
        for (var=0; var<2; var=var+1) begin: block_ram2
            RAM #(
                .WIDTH      (16),
                .DEPTH      (2048)
            ) ram2_inst(
                .clk        (clk),
                .rst_n      (rst_n),
                .wr_en      (ram2_wr_en[var]),
                .wr_addr    (ram2_wr_addr[var]),
                .wr_data    (ram2_wr_data[var]),
                .rd_en      (1'b1),
                .rd_addr    (ram2_rd_addr[var]),
                .rd_data    (ram2_rd_data[var])
            );
        end
    endgenerate

endmodule
