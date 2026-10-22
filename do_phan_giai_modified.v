module do_phan_giai (
    input  wire        pclk,
    input  wire        reset,
    input  wire        vsync,
    input  wire        pixel_hople_moi,
    input  wire [9:0]  toa_do_x_goc,
    input  wire [9:0]  toa_do_y_goc,
    input  wire [15:0] pixel_data_goc,
    output reg  [12:0] ram_ghi,
    output reg  [15:0] pixel_data_out,
    output reg         ram_tin_hieu_ghi,
    output reg         frame_done
);
    wire [5:0] x_nho = toa_do_x_goc[8:2];
    wire [15:0] temp_y = toa_do_y_goc * 17;
    wire [5:0] y_nho = temp_y[11:6];

    always @(posedge pclk or posedge reset) begin
        if (reset) begin
            ram_tin_hieu_ghi <= 1'b0;
            ram_ghi          <= 13'd0;
            pixel_data_out   <= 16'd0;
            frame_done       <= 1'b0;
        end else begin
            ram_tin_hieu_ghi <= 1'b0;
            frame_done       <= 1'b0;

            if (pixel_hople_moi &&
                (toa_do_x_goc[2:0] == 3'd0) &&
                (toa_do_y_goc[1:0] == 2'd0)) begin
                if ((x_nho < 6'd64) && (y_nho < 6'd64)) begin
                    pixel_data_out   <= pixel_data_goc;
                    ram_ghi          <= {y_nho, x_nho};
                    ram_tin_hieu_ghi <= 1'b1;
                end
            end

            if (pixel_hople_moi &&
                (toa_do_x_goc == 10'd319) &&
                (toa_do_y_goc == 10'd239)) begin
                frame_done <= 1'b1;
            end
        end
    end
endmodule
