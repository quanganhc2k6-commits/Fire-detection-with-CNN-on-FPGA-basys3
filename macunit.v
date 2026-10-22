// mac_unit.v
// Nhân tích lũy acc = acc + (weight × input)
// weight int8, input int8, acc int32

module mac_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,     // enable tích lũy
    input  wire        clear,  // reset acc về 0
    input  wire signed [7:0]  weight, // int8
    input  wire signed [7:0]  input_val, // int8 (đổi tên tránh trùng từ khóa 'input' của Verilog)
    output reg  signed [31:0] acc     // int32
);

    // Trong Verilog, ta có thể dùng luôn port 'output reg' để tính toán 
    // hoặc dùng reg nội bộ rồi gán assign. Ở đây dùng trực tiếp 'acc' cho gọn.
    
    always @(posedge clk) begin
        if (rst || clear) begin
            acc <= 32'sb0; // Reset về 0 (có dấu)
        end else if (en) begin
            // Verilog tự động thực hiện phép nhân có dấu (signed multiplication)
            // và tự động mở rộng dấu (sign-extend) lên 32-bit trước khi cộng với acc.
            acc <= acc + (weight * input_val);
        end
    end

endmodule