module bat_du_lieu (
    input  wire        clk,
    input  wire        reset,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  data,
    output reg  [15:0] pixel_data,
    output reg         pixel_hople,
    output reg  [9:0]  pixel_x,
    output reg  [9:0]  pixel_y
);
    reg vsync_d1, vsync_d2;
    reg href_d1, href_d2;
    reg [7:0] data_d1, data_d2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            vsync_d1 <= 0; vsync_d2 <= 0;
            href_d1  <= 0; href_d2  <= 0;
            data_d1  <= 0; data_d2  <= 0;
        end else begin
            vsync_d1 <= vsync;    vsync_d2 <= vsync_d1;
            href_d1  <= href;     href_d2  <= href_d1;
            data_d1  <= data;     data_d2  <= data_d1;
        end
    end

    reg        byte_read;
    reg [7:0]  byte_doi;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_x     <= 10'd0;
            pixel_y     <= 10'd0;
            byte_read   <= 1'b0;
            pixel_hople <= 1'b0;
            pixel_data  <= 16'h0000;
            byte_doi    <= 8'h00;
        end else if (vsync_d2) begin
            pixel_x     <= 10'd0;
            pixel_y     <= 10'd0;
            byte_read   <= 1'b0;
            pixel_hople <= 1'b0;
        end else begin
            pixel_hople <= 1'b0;
            if (href_d2) begin
                if (byte_read == 1'b0) begin
                    byte_doi  <= data_d2;
                    byte_read <= 1'b1;
                end else begin
                    pixel_data  <= {byte_doi, data_d2};
                    pixel_hople <= 1'b1;
                    byte_read   <= 1'b0;
                    if (pixel_x < 10'd319)
                        pixel_x <= pixel_x + 10'd1;
                end
            end else begin
                byte_read <= 1'b0;
                if (pixel_x > 10'd0) begin
                    pixel_x <= 10'd0;
                    pixel_y <= pixel_y + 10'd1;
                end
            end
        end
    end
endmodule