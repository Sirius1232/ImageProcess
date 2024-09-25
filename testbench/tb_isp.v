`timescale 1ns / 1ns

module tb_isp();
    localparam  SRC_W = 1936;  // 输入图像宽度
    localparam  SRC_H = 1088;  // 输入图像高度
    localparam  PIX_WID = 8;  // 输入图像像素点位宽

    localparam  DST_W = 1920;  // 输出图像宽度
    localparam  DST_H = 1080;  // 输出图像高度

    localparam  SRC_ADDR = "E:/FPGA/Xilinx/projects/ISP/ISP.srcs/sim_1/new/input/raw_day_0.txt";
    localparam  DST_ADDR = "E:/FPGA/Xilinx/projects/ISP/ISP.srcs/sim_1/new/output/out.txt";

    /*System Port*/
    reg                     clk;
    reg                     rst_n;
    reg                     enable;

    wire                    src_valid;
    wire                    src_ready;
    wire    [PIX_WID-1:0]   src_data;
    wire                    src_start;
    wire                    src_line_last;
    wire                    src_last;

    wire                    dst_valid;
    wire    [23:0]          dst_data;  // 输出默认为RGB格式
    wire                    dst_last;


    //----------------Module Instantiation----------------
    image_generator #(
        .HEIGHT             (SRC_H),
        .WIDTH              (SRC_W),
        .PIX_WID            (PIX_WID),
        .IMG_ADDR           (SRC_ADDR)
    ) image_generator_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .enable             (enable),
        .img_valid          (src_valid),
        .img_ready          (src_ready),
        .img_data           (src_data),
        .img_start          (src_start),
        .img_line_last      (src_line_last),
        .img_last           (src_last)
    );

    raw2rgb raw2rgb_inst(
        .clk                (clk),
        .rst_n              (rst_n),
        .src_width          (SRC_W),
        .src_height         (SRC_H),
        .src_valid          (src_valid),
        .src_ready          (src_ready),
        .src_data           (src_data),
        .dst_width          (DST_W),
        .dst_height         (DST_H),
        .dst_valid          (dst_valid),
        .dst_ready          (1'b1),
        .dst_data           (dst_data),
        .dst_start          (),
        .dst_line_last      (),
        .dst_last           ()
    );


    //----------------Test Conditions----------------
    initial begin
            clk = 1'b1;
            rst_n <= 1'b0;
            enable <= 1'b0;
        #15
            rst_n <= 1'b1;
        #85
            enable <= 1'b1;
    end

    always  #10 clk=~clk;   //clock period 20ns, 50MHz

    // assign  src_ready = 1'b1;


    /*控制结束仿真*/
    reg     [20:0]      dst_cnt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            dst_cnt <= 0;
        else if(dst_valid)
            dst_cnt <= (dst_cnt<DST_H*DST_W-1) ? dst_cnt + 1'b1 : 0;
        else
            dst_cnt <= dst_cnt;
    end
    assign  dst_last = (dst_cnt==DST_H*DST_W-1) ? dst_valid : 1'b0;

    integer dout_txt_id;
    reg     [3:0]   cnt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 0;
        end
        else begin
            if(dst_last)
                cnt <= cnt + 1'b1;
            else
                cnt <= cnt;
            if(cnt==1) begin
                $fclose(dout_txt_id);
                $stop(2);
            end
        end
    end

    initial begin
        dout_txt_id = $fopen(DST_ADDR, "w+");
    end
    always @(posedge clk or negedge rst_n) begin
        if(cnt==0 && dst_valid) begin
            $fwrite(dout_txt_id, "%h\n", dst_data);
        end
    end


endmodule
