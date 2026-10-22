module RAM (
    input  wire        wclk,
    input  wire        we,
    input  wire [12:0] dia_chi_ghi,
    input  wire [15:0] ghi,
    input  wire        rclk,
    input  wire [12:0] dia_chi_doc,
    output reg  [15:0] d_out
);
    (* ram_style = "block" *) reg [15:0] ram [0:8191];
    always @(posedge wclk) begin
        if (we) ram[dia_chi_ghi] <= ghi;
    end
    always @(posedge rclk) begin
        d_out <= ram[dia_chi_doc];
    end
endmodule
