// relu_requant.v
// Clip âm về 0, sau đó scale int32 → int8

module relu_requant #(
    parameter SHIFT = 8  // scale factor, tính từ quantization params
)(
    input  wire signed [31:0] acc_in,
    output reg  signed [7:0]  out_int8
);

    // Sử dụng biến nội bộ dạng wire để thực hiện phép dịch bit có dấu (Arithmetic Shift Right)
    wire signed [31:0] shifted;
    
    // Trong Verilog, >>> thực hiện phép dịch phải bảo toàn dấu (Arithmetic Shift)
    assign shifted = acc_in >>> SHIFT;

    // Combinational logic (mạch tổ hợp) giải mã ReLU và Clamp
    always @(*) begin
        // 1. Hàm kích hoạt ReLU: Nếu giá trị tích lũy âm, gán bằng 0
        if (acc_in < 32'sb0) begin
            out_int8 = 8'sb0;
        end 
        // 2. Định lượng & Saturation (Clamp)
        else begin
            // Kiểm tra tràn ngưỡng trên (ép về Max của INT8 có dấu)
            if (shifted > 32'sd127) begin
                out_int8 = 8'sd127;
            end
            // Kiểm tra tràn ngưỡng dưới (Thực tế ReLU đã loại bỏ số âm, nhưng viết để đủ mạch Clamp)
            else if (shifted < -32'sd128) begin
                out_int8 = -8'sd128;
            end
            // Nếu nằm trong khoảng an toàn, lấy 8-bit thấp
            else begin
                out_int8 = shifted[7:0];
            end
        end
    end

endmodule