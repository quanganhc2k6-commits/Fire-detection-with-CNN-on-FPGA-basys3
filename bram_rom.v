// bram_rom.v
// BRAM chỉ đọc, nạp sẵn dữ liệu từ file .coe lúc synthesis
// Dùng cho: weight, bias, shift của Conv/FC layers

module bram_rom #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 16,
    parameter DEPTH      = 65536,
    parameter INIT_FILE  = ""     // đường dẫn file .coe hoặc .mem (hex)
)(
    input  wire                    clk,
    input  wire [ADDR_WIDTH-1:0]   addr,
    output reg  [DATA_WIDTH-1:0]   data
);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1]; //  mảng 2 chiều

initial begin // nếu đã truyền tên file thì đọc file đó lấy data
    if (INIT_FILE != "")
        $readmemh(INIT_FILE, mem);   // đọc file hex (đã convert từ .coe)
end

always @(posedge clk) begin
    data <= mem[addr];   // đọc đồng bộ, trễ 1 cycle
end

endmodule