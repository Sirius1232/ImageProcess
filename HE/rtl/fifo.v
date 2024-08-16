//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           fifo.v
// Descriptions:        同步FIFO行为级仿真模块
//-----------------------------------------README-----------------------------------------
// 用于模拟同步FIFO，可配置数据位宽和深度，数据写入/读出均为1cycle延时。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module fifo #(
        parameter   WIDTH = 8,
        parameter   DEPTH = 256
    ) (
        input                       clk,
        input                       rst_n,
        input                       wr_en,
        input       [WIDTH-1:0]     wr_data,
        input                       rd_en,
        output      [WIDTH-1:0]     rd_data,
        output                      empty,
        output                      full
    );

    localparam  WID_ADDR = $clog2(DEPTH);

    integer i;
    reg     [WIDTH-1:0]     ram[0:DEPTH-1];
    reg     [WID_ADDR:0]    cnt;
    wire    wr_valid, rd_valid;
    reg     [WID_ADDR-1:0]  wr_addr, rd_addr;

    assign  wr_valid = wr_en & (~full);
    assign  rd_valid = rd_en & (~empty);

    assign  empty = (cnt==0) ? 1'b1 : 1'b0;
    assign  full = (cnt==DEPTH) ? 1'b1 : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_addr <= 0;
            rd_addr <= 0;
        end
        else begin
            wr_addr <= wr_valid ? wr_addr + 1'b1 : wr_addr;
            rd_addr <= rd_valid ? rd_addr + 1'b1 : rd_addr;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 0;
        end
        else begin
            case ({wr_valid, rd_valid})
                2'b00 : cnt <= cnt;
                2'b01 : cnt <= cnt - 1'b1;
                2'b10 : cnt <= cnt + 1'b1;
                2'b11 : cnt <= cnt;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for (i=0; i<DEPTH; i=i+1) begin
                ram[i] <= 0;
            end
        end
        else begin
            ram[wr_addr] <= wr_valid ? wr_data : ram[wr_addr];
        end
    end
    assign  rd_data = rd_valid ? ram[rd_addr] : 0;

endmodule
