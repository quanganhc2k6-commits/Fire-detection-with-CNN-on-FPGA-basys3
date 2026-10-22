// bram_simple2port.v
// BRAM đơn giản: 1 cổng ghi, 1 cổng đọc, độc lập địa chỉ
// Dùng cho: frame buffer, output buffer của Conv/Pool/FC

module bram_simple2port #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 16,
    parameter DEPTH      = 65536
)(
    input  wire                    clk,
    input  wire                    wr_en,
    input  wire [ADDR_WIDTH-1:0]   wr_addr, // địa chỉ ghi dữ liệu vào
    input  wire [DATA_WIDTH-1:0]   wr_data, // giá trị mà muốn ghi vào
    input  wire [ADDR_WIDTH-1:0]   rd_addr, // địa chỉ muốn đọc
    output reg  [DATA_WIDTH-1:0]   rd_data  // giá trị đọc
);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

always @(posedge clk) begin
    if (wr_en)
        mem[wr_addr] <= wr_data;
    rd_data <= mem[rd_addr];   // đọc đồng bộ, trễ 1 cycle
end

endmodule