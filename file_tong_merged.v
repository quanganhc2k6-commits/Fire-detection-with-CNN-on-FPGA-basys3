`timescale 1ns / 1ps

module file_tong (
    input  wire        clk_100m,
    input  wire        rst_bntl,
    output wire        led_bao_hieu,
    output wire        led_done,
    output wire [3:0]  LED,
    input  wire        cam_pclk,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_data,
    inout  wire        cam_sda,
    output wire        cam_scl,
    output wire        cam_xclk,
    output wire        cam_reset,
    output wire        cam_pwdn,
    output wire        daura,
    input wire         congtac
);
    wire clk_25m;
    wire clk_24m;
    wire pll_locked;

    reg [20:0] delay_cnt = 0;
    reg        power_on_ready = 0;

    always @(posedge clk_25m or negedge pll_locked) begin
        if (!pll_locked) begin
            delay_cnt      <= 0;
            power_on_ready <= 0;
        end else if (delay_cnt < 21'd1_250_000) begin
            delay_cnt      <= delay_cnt + 1'b1;
            power_on_ready <= 0;
        end else begin
            power_on_ready <= 1'b1;
        end
    end

    wire sys_reset_n    = pll_locked & power_on_ready & (~rst_bntl);
    wire sys_reset_high = ~sys_reset_n;

    assign cam_reset = sys_reset_n;
    assign cam_pwdn  = 1'b0;
    assign cam_xclk  = clk_24m;

    wire [15:0] cap_pixel_data;
    wire        cap_pixel_hople;
    wire [9:0]  cap_pixel_x;
    wire [9:0]  cap_pixel_y;
    wire [12:0] ram_dia_chi_ghi;
    wire [15:0] ram_ghi;
    wire        ram_we_raw;
    wire        cam_pclk_bufg;
    wire        frame_done_raw;

    wire [12:0] ai_ram_rd_addr;
    wire [15:0] ai_ram_rd_data;
    wire        frame_done_ai;
    wire        inference_done;
    wire        ai_done_toggle;
    wire        frame_toggle_pclk;
    wire        ram_we_allow;
    wire        ram_we_final = ram_we_raw & ram_we_allow;

    assign led_bao_hieu = frame_done_raw;

    quan_ly_xung u_xung (
        .clk_100m (clk_100m),
        .reset    (rst_bntl),
        .clk_25m  (clk_25m),
        .clk_24m  (clk_24m),
        .locked   (pll_locked)
    );

    cau_hinh_camera u_cauhinh (
        .clk      (clk_25m),
        .reset    (sys_reset_high),
        .cam_sda  (cam_sda),
        .cam_scl  (cam_scl),
        .led_done (led_done)
    );

    BUFG u_bufg_pclk (
        .I(cam_pclk),
        .O(cam_pclk_bufg)
    );

    bat_du_lieu u_dulieu (
        .clk         (cam_pclk_bufg),
        .reset       (sys_reset_high),
        .vsync       (cam_vsync),
        .href        (cam_href),
        .data        (cam_data),
        .pixel_data  (cap_pixel_data),
        .pixel_hople (cap_pixel_hople),
        .pixel_x     (cap_pixel_x),
        .pixel_y     (cap_pixel_y)
    );

    do_phan_giai u_do_phan_giai (
        .pclk             (cam_pclk_bufg),
        .reset            (sys_reset_high),
        .vsync            (cam_vsync),
        .pixel_hople_moi  (cap_pixel_hople),
        .toa_do_x_goc     (cap_pixel_x),
        .toa_do_y_goc     (cap_pixel_y),
        .pixel_data_goc   (cap_pixel_data),
        .ram_ghi          (ram_dia_chi_ghi),
        .pixel_data_out   (ram_ghi),
        .ram_tin_hieu_ghi (ram_we_raw),
        .frame_done       (frame_done_raw)
    );

    frame_handshake_cdc u_frame_lock (
        .pclk                  (cam_pclk_bufg),
        .rst_pclk              (sys_reset_high),
        .frame_done_raw        (frame_done_raw),
        .ai_done_toggle_async  (ai_done_toggle),
        .camera_ram_we_allow   (ram_we_allow),
        .frame_toggle_pclk     (frame_toggle_pclk)
    );

    frame_toggle_to_pulse u_frame_cdc (
        .clk                (clk_25m),
        .rst                (sys_reset_high),
        .frame_toggle_async (frame_toggle_pclk),
        .frame_done_pulse   (frame_done_ai)
    );

    RAM u_RAM (
        .wclk        (cam_pclk_bufg),
        .we          (ram_we_final),
        .dia_chi_ghi (ram_dia_chi_ghi),
        .ghi         (ram_ghi),
        .rclk        (clk_25m),
        .dia_chi_doc (ai_ram_rd_addr),
        .d_out       (ai_ram_rd_data)
    );

    ai_top_bram u_ai (
        .clk              (clk_25m),
        .rst              (sys_reset_high),
        .frame_done       (frame_done_ai), // doi tu ai de test
        .cam_bram_rd_addr (ai_ram_rd_addr),
        .cam_bram_rd_data (ai_ram_rd_data),
        .LED              (LED),
        .inference_done   (inference_done),
        .congtac(congtac)
    );

    pulse_to_toggle u_ai_done_cdc (
        .clk        (clk_25m),
        .rst        (sys_reset_high),
        .pulse_in   (inference_done),
        .toggle_out (ai_done_toggle)
    );
    assign daura = LED[0];
endmodule
