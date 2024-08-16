//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           delay.v
// Descriptions:        延时打拍模块
//-----------------------------------------README-----------------------------------------
// 可配置数据位宽和延时周期数。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module delay #(
        parameter   WIDTH = 8,
        parameter   DELAY = 3
    ) (
        input               clk,
        input               rst_n,
        input   [WIDTH-1:0] din,
        output  [WIDTH-1:0] dout
    );

    genvar  var;

    reg     [WIDTH-1:0]     tmp[0:DELAY-1];
    generate
        for (var=0; var<DELAY; var=var+1) begin: block
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n)
                    tmp[var] <= 0;
                else
                    tmp[var] <= (var==0) ? din : tmp[var-1];
            end
        end
    endgenerate
    assign  dout = tmp[DELAY-1];


endmodule
