//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           he_core.v
// Descriptions:        HE算法的核心计算模块
//-----------------------------------------README-----------------------------------------
// 该模块处理单个通道（灰度）图像，需要对RGB图像操作的话，需要在模块外拆分通道或计算灰度。
// 
// 参数可配置图像的分辨率`WIDTH`和`HEIGHT`
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module he_core #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080,
        parameter   IS_SIM = 0
    ) (
        input               clk,
        input               rst_n,
        input               src_valid,
        input       [7:0]   src_data,
        input               src_last,
        output  reg         dst_valid,
        output      [7:0]   dst_data
    );

    reg     pingpong;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pingpong <= 1'b0;
        end
        else begin
            // pingpong <= src_last ? ~pingpong : pingpong;
            pingpong <= src_last ? 1'b1 : pingpong;
        end
    end



    reg                 pdf_ram_wr_en;
    reg     [7:0]       pdf_ram_wr_addr;
    wire    [23:0]      pdf_ram_wr_data;
    wire    [7:0]       pdf_ram_rd_addr;
    wire    [23:0]      pdf_ram_rd_data;

    reg                 cdf_ram_wr_en;
    reg     [7:0]       cdf_ram_wr_addr;
    wire    [7:0]       cdf_ram_wr_data;
    wire    [7:0]       cdf_ram_rd_addr;
    wire    [7:0]       cdf_ram_rd_data;



    /*统计pdf*/
    wire    [23:0]      pdf;
    reg     [23:0]      pdf_reg;
    reg                 src_valid_last;
    reg                 cache_flag;
    wire                cdf_calc_en;
    reg                 cdf_calc_en_dly;
    reg     [8:0]       cdf_cnt;
    reg     [7:0]       cdf_cnt_dly;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pdf_reg <= 0;
            src_valid_last <= 1'b0;
            cache_flag <= 1'b0;
        end
        else begin
            pdf_reg <= src_valid ? pdf_ram_wr_data : 0;
            src_valid_last <= src_valid;
            cache_flag <= (pdf_ram_rd_addr==pdf_ram_wr_addr) ? src_valid_last & src_valid : 1'b0;
        end
    end
    assign  pdf = cache_flag ? pdf_reg + 1'b1 : pdf_ram_rd_data + 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pdf_ram_wr_en <= 0;
            pdf_ram_wr_addr <= 0;
        end
        else begin
            pdf_ram_wr_en <= cdf_calc_en ? 1'b1 : src_valid;
            pdf_ram_wr_addr <= cdf_calc_en ? cdf_cnt : src_data;
        end
    end
    assign  pdf_ram_wr_data = cdf_calc_en_dly ? 0 : pdf;
    assign  pdf_ram_rd_addr = cdf_calc_en ? cdf_cnt : src_data;



    /*计算cdf*/
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf_cnt <= 0;
        end
        else begin
            if(src_last)
                cdf_cnt <= 0;
            else if(cdf_calc_en)
                cdf_cnt <= cdf_cnt + 1'b1;
            else
                cdf_cnt <= cdf_cnt;
        end
    end
    assign  cdf_calc_en = (cdf_cnt < 9'd256) ? 1'b1 : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf_calc_en_dly <= 1'b0;
            cdf_cnt_dly <= 1'b0;
        end
        else begin
            cdf_calc_en_dly <= cdf_calc_en;
            cdf_cnt_dly <= cdf_cnt;
        end
    end

    reg     [23:0]      cdf_tmp;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf_tmp <= 0;
        end
        else begin
            if(src_last)
                cdf_tmp <= 0;
            else if(cdf_calc_en_dly)
                cdf_tmp <= cdf_tmp + pdf_ram_rd_data;
            else
                cdf_tmp <= cdf_tmp;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdf_ram_wr_en <= 0;
            cdf_ram_wr_addr <= 0;
        end
        else begin
            cdf_ram_wr_en <= cdf_calc_en_dly;
            cdf_ram_wr_addr <= cdf_cnt_dly;
        end
    end
    assign  cdf_ram_wr_data = cdf_tmp[20:13];



    /*均衡化*/
    assign  cdf_ram_rd_addr = src_data;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            dst_valid <= 1'b0;
        else
            dst_valid <= pingpong ? src_valid : 1'b0;
    end
    assign  dst_data = pingpong ? cdf_ram_rd_data : 0;



    /*BRAM*/
    RAM #(
        .WIDTH      (24),
        .DEPTH      (256)
    ) pdf_ram_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (pdf_ram_wr_en),
        .wr_addr    (pdf_ram_wr_addr),
        .wr_data    (pdf_ram_wr_data),
        .rd_en      (1'b1),
        .rd_addr    (pdf_ram_rd_addr),
        .rd_data    (pdf_ram_rd_data)
    );
    RAM #(
        .WIDTH      (8),
        .DEPTH      (256)
    ) cdf_ram_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (cdf_ram_wr_en),
        .wr_addr    (cdf_ram_wr_addr),
        .wr_data    (cdf_ram_wr_data),
        .rd_en      (1'b1),
        .rd_addr    (cdf_ram_rd_addr),
        .rd_data    (cdf_ram_rd_data)
    );

endmodule
