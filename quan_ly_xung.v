module quan_ly_xung (
    input  wire clk_100m,
    input  wire reset,
    output wire clk_25m,
    output wire clk_24m,
    output wire locked
);
    clk_wiz_0 u_clk_wiz (
        .clk_in1 (clk_100m),
        .reset   (reset),
        .clk_out1(clk_25m),
        .clk_out2(clk_24m),
        .locked  (locked)
    );
endmodule