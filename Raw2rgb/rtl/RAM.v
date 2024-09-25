//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           RAM.v
// Descriptions:        BRAM行为级仿真模块
//-----------------------------------------README-----------------------------------------
// 用于模拟Single Dual Port BRAM（一读一写），可配置数据位宽和深度，数据写入/读出均为1cycle延时。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module RAM #(
        parameter   WIDTH = 8,
        parameter   DEPTH = 1024,
        localparam  A_WID = $clog2(DEPTH)  // 地址位宽
    ) (
        input                       clk,
        input                       rst_n,
        input                       wr_en,
        input       [A_WID-1:0]     wr_addr,
        input       [WIDTH-1:0]     wr_data,
        input                       rd_en,
        input       [A_WID-1:0]     rd_addr,
        output  reg [WIDTH-1:0]     rd_data
    );

    integer i;
    reg     [WIDTH-1:0]     array[0:DEPTH-1];

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (i=0; i<DEPTH; i=i+1) begin
                array[i] <= 0;
            end
        end
        else begin
            array[wr_addr] <= wr_en ? wr_data : array[wr_addr];
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data <= 0;
        end
        else begin
            rd_data <= rd_en ? array[rd_addr] : rd_data;
        end
    end


endmodule
