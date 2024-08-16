//****************************************************************************************//
// Encoding:            UTF-8
//----------------------------------------------------------------------------------------
// File Name:           div.v
// Descriptions:        除法器行为级仿真模块
//-----------------------------------------README-----------------------------------------
// 用于模拟除法器IP，同时计算除法和取模（商和余数）。
// 
// 可配置被除数、除数的数据位宽，以及除法运算的pipeline级数`DELAY`。
// 
//----------------------------------------------------------------------------------------
//****************************************************************************************//


module div #(
        parameter   WIDTH_A = 16,  // 被除数位宽
        parameter   WIDTH_B = 8,  // 除数位宽
        parameter   DELAY = 5
    ) (
        input               clk,
        input               rst_n,
        input               start,
        input       [15:0]  numerator,  // 被除数
        input       [7:0]   denominator,  // 输出
        output              done,
        output      [15:0]  quotient,  // 商
        output      [7:0]   remainder  // 余数
    );

    genvar  var;

    wire    [15:0]      rslt_q;
    wire    [7:0]       rslt_r;
    assign  rslt_q = numerator / denominator;
    assign  rslt_r = numerator % denominator;

    delay #(
        .WIDTH      (25),
        .DELAY      (DELAY)
    ) delay_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .din        ({start, rslt_q, rslt_r}),
        .dout       ({done, quotient, remainder})
    );


endmodule
