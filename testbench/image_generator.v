module image_generator #(
        parameter   WIDTH = 1920,
        parameter   HEIGHT = 1080,
        parameter   PIX_WID = 24,
        parameter   IMG_ADDR = ""
    ) (
        input                       clk,
        input                       rst_n,
        input                       enable,
        output                      img_valid,
        input                       img_ready,
        output      [PIX_WID-1:0]   img_data,
        output                      img_start,
        output                      img_line_last,
        output                      img_last
    );

    localparam  WID_W = $clog2(WIDTH);
    localparam  WID_H = $clog2(HEIGHT);

    reg     [PIX_WID-1:0]   image[0:WIDTH*HEIGHT-1];
    initial begin
        $readmemh(IMG_ADDR, image);
    end

    reg     [WID_W-1:0]     cnt_w;
    reg     [WID_H-1:0]     cnt_h;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_h <= 0;
            cnt_w <= 0;
        end
        else if(enable) begin
            if(img_valid & img_ready) begin
                if(cnt_w < WIDTH - 1'b1) begin
                    cnt_h <= cnt_h;
                    cnt_w <= cnt_w + 1'b1;
                end
                else begin
                    cnt_h <= (cnt_h < HEIGHT - 1'b1) ? cnt_h + 1'b1 : 0;
                    cnt_w <= 0;
                end
            end
            else begin
                cnt_h <= cnt_h;
                cnt_w <= cnt_w;
            end
        end
        else begin
            cnt_h <= 0;
            cnt_w <= 0;
        end
    end
    assign  img_valid = enable;
    assign  img_start = (cnt_w==0 && cnt_h==0) ? img_valid & img_ready : 1'b0;
    assign  img_line_last = (cnt_w==WIDTH-1) ? img_valid & img_ready : 1'b0;
    assign  img_last = (cnt_h==HEIGHT-1) ? img_line_last : 1'b0;

    reg     [WID_H+WID_W-1:0]   cnt_pixel;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_pixel <= 0;
        end
        else if(enable) begin
            if(img_valid & img_ready) begin
                cnt_pixel <= (cnt_pixel < HEIGHT * WIDTH - 1) ? cnt_pixel + 1'b1 : 0;
            end
            else begin
                cnt_pixel <= cnt_pixel;
            end
        end
        else begin
            cnt_pixel <= 0;
        end
    end
    assign  img_data = image[cnt_pixel];

endmodule
