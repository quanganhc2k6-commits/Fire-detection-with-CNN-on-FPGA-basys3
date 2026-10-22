// top.v
// Fire Detection System - Basys3
// Ngu·ªìn ·∫£nh: PC (Python) g·ª≠i qua UART, KH√îNG d√πng camera OV7670
// Pipeline: UART RX -> Frame Buffer -> Conv1->Pool1->Conv2->Pool2->Conv3->FC1->FC2 -> LED

module ai_top_bram (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_done,
    output wire [12:0] cam_bram_rd_addr,
    input  wire [15:0] cam_bram_rd_data,
    output wire [3:0]  LED,
    output wire        inference_done,
    input wire congtac
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// INPUT CAMERA BRAM: 4096 pixel RGB565, CNN v·∫´n nh√¨n th·∫•y RGB888
// theo layout byte xen k·∫Ω R,G,B nh∆∞ frame buffer UART c≈©.
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [13:0] fb_rd_addr;
wire [7:0]  fb_rd_data;

rgb565_bram_to_rgb888_bytes u_camera_input (
    .clk          (clk),
    .byte_addr    (fb_rd_addr),
    .byte_data    (fb_rd_data),
    .bram_rd_addr (cam_bram_rd_addr),
    .bram_rd_data (cam_bram_rd_data)
);

reg frame_ready = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        frame_ready <= 1'b0;
    end else begin
        if (frame_done)
            frame_ready <= 1'b1;
        else if (pipe_state == P_DONE)
            frame_ready <= 1'b0;
    end
end

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// CONV1 WEIGHT / BIAS BRAM
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [7:0]         c1w_addr;// c·∫ßn 3*3 *3 k√™nh * 8 output (t·ª©c l√† s·∫Ω c√≥ 3*8 = 24 c√°i ma tr·∫≠n)
wire signed [7:0]  c1w_data;
wire [2:0]         c1b_addr;// m·ªói output ch·ªâ c·∫ßn 1 bias
wire signed [31:0] c1b_data;

bram_rom #(.DATA_WIDTH(8), .ADDR_WIDTH(8), .DEPTH(216),
           .INIT_FILE("conv1_w.mem"))
u_c1_weight (.clk(clk), .addr(c1w_addr), .data(c1w_data));

bram_rom #(.DATA_WIDTH(32), .ADDR_WIDTH(3), .DEPTH(8),
           .INIT_FILE("conv1_b.mem"))
u_c1_bias (.clk(clk), .addr(c1b_addr), .data(c1b_data)); 

// Conv1 Output Buffer: 64x64x8 = 32768 byte
wire [14:0]        c1o_wr_addr, c1o_rd_addr;
wire signed [7:0]  c1o_wr_data, c1o_rd_data;
wire               c1o_we;

bram_simple2port #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DEPTH(32768))
u_c1_out (
    .clk(clk), .wr_en(c1o_we), .wr_addr(c1o_wr_addr), .wr_data(c1o_wr_data),
    .rd_addr(c1o_rd_addr), .rd_data(c1o_rd_data)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// POOL1 OUTPUT: 32x32x8 = 8192 byte
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [12:0]        p1o_wr_addr, p1o_rd_addr;
wire signed [7:0]  p1o_wr_data, p1o_rd_data;
wire               p1o_we;

bram_simple2port #(.DATA_WIDTH(8), .ADDR_WIDTH(13), .DEPTH(8192))
u_p1_out (
    .clk(clk), .wr_en(p1o_we), .wr_addr(p1o_wr_addr), .wr_data(p1o_wr_data),
    .rd_addr(p1o_rd_addr), .rd_data(p1o_rd_data)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// CONV2 WEIGHT / BIAS BRAM
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [10:0]        c2w_addr;
wire signed [7:0]  c2w_data;
wire [3:0]         c2b_addr;
wire signed [31:0] c2b_data;

bram_rom #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DEPTH(1152),
           .INIT_FILE("conv2_w.mem"))
u_c2_weight (.clk(clk), .addr(c2w_addr), .data(c2w_data));

bram_rom #(.DATA_WIDTH(32), .ADDR_WIDTH(4), .DEPTH(16),
           .INIT_FILE("conv2_b.mem"))
u_c2_bias (.clk(clk), .addr(c2b_addr), .data(c2b_data));

// Conv2 Output: 32x32x16 = 16384 byte
wire [13:0]        c2o_wr_addr, c2o_rd_addr;
wire signed [7:0]  c2o_wr_data, c2o_rd_data;
wire               c2o_we;

bram_simple2port #(.DATA_WIDTH(8), .ADDR_WIDTH(14), .DEPTH(16384))
u_c2_out (
    .clk(clk), .wr_en(c2o_we), .wr_addr(c2o_wr_addr), .wr_data(c2o_wr_data),
    .rd_addr(c2o_rd_addr), .rd_data(c2o_rd_data)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// POOL2 OUTPUT: 16x16x16 = 4096 byte
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [11:0]        p2o_wr_addr, p2o_rd_addr;
wire signed [7:0]  p2o_wr_data, p2o_rd_data;
wire               p2o_we;

bram_simple2port #(.DATA_WIDTH(8), .ADDR_WIDTH(12), .DEPTH(4096))
u_p2_out (
    .clk(clk), .wr_en(p2o_we), .wr_addr(p2o_wr_addr), .wr_data(p2o_wr_data),
    .rd_addr(p2o_rd_addr), .rd_data(p2o_rd_data)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// CONV3 WEIGHT / BIAS / SHIFT BRAM (Conv3 d√πng per-channel shift)
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [11:0]        c3w_addr;
wire signed [7:0]  c3w_data;
wire [3:0]         c3b_addr;
wire signed [31:0] c3b_data;
wire [3:0]         c3s_addr;
wire [3:0]         c3s_data;

bram_rom #(.DATA_WIDTH(8), .ADDR_WIDTH(12), .DEPTH(2304),
           .INIT_FILE("conv3_w.mem"))
u_c3_weight (.clk(clk), .addr(c3w_addr), .data(c3w_data));

bram_rom #(.DATA_WIDTH(32), .ADDR_WIDTH(4), .DEPTH(16),
           .INIT_FILE("conv3_b.mem"))
u_c3_bias (.clk(clk), .addr(c3b_addr), .data(c3b_data));

bram_rom #(.DATA_WIDTH(4), .ADDR_WIDTH(4), .DEPTH(16),
           .INIT_FILE("conv3_shift.mem"))
u_c3_shift (.clk(clk), .addr(c3s_addr), .data(c3s_data));

// Conv3 Output / FC1 Input: 16x16x16 = 4096 byte
wire [11:0]        c3o_wr_addr, c3o_rd_addr;
wire signed [7:0]  c3o_wr_data, c3o_rd_data;
wire               c3o_we;

bram_simple2port #(.DATA_WIDTH(8), .ADDR_WIDTH(12), .DEPTH(4096))
u_c3_out (
    .clk(clk), .wr_en(c3o_we), .wr_addr(c3o_wr_addr), .wr_data(c3o_wr_data),
    .rd_addr(c3o_rd_addr), .rd_data(c3o_rd_data)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// FC1 WEIGHT / BIAS / SHIFT BRAM
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [15:0]        fc1w_addr;
wire signed [7:0]  fc1w_data;
wire [3:0]         fc1b_addr;
wire signed [31:0] fc1b_data;
wire [3:0]         fc1s_addr;
wire [3:0]         fc1s_data;

bram_rom #(.DATA_WIDTH(8), .ADDR_WIDTH(16), .DEPTH(36864),
           .INIT_FILE("fc1_w.mem"))
u_fc1_weight (.clk(clk), .addr(fc1w_addr), .data(fc1w_data));

bram_rom #(.DATA_WIDTH(32), .ADDR_WIDTH(4), .DEPTH(16),
           .INIT_FILE("fc1_b.mem"))
u_fc1_bias (.clk(clk), .addr(fc1b_addr), .data(fc1b_data));

bram_rom #(.DATA_WIDTH(4), .ADDR_WIDTH(4), .DEPTH(16),
           .INIT_FILE("fc1_shift.mem"))
u_fc1_shift (.clk(clk), .addr(fc1s_addr), .data(fc1s_data));

// FC1 Output / FC2 Input: 16 byte
wire [3:0]         fc1o_wr_addr, fc1o_rd_addr;
wire signed [7:0]  fc1o_wr_data, fc1o_rd_data;
wire               fc1o_we;

bram_simple2port #(.DATA_WIDTH(8), .ADDR_WIDTH(4), .DEPTH(16))
u_fc1_out (
    .clk(clk), .wr_en(fc1o_we), .wr_addr(fc1o_wr_addr), .wr_data(fc1o_wr_data),
    .rd_addr(fc1o_rd_addr), .rd_data(fc1o_rd_data)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// FC2 WEIGHT / BIAS BRAM
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
wire [3:0]         fc2w_addr;
wire signed [7:0]  fc2w_data;
wire [0:0]         fc2b_addr;
wire signed [31:0] fc2b_data;

bram_rom #(.DATA_WIDTH(8), .ADDR_WIDTH(4), .DEPTH(16),
           .INIT_FILE("fc2_w.mem"))
u_fc2_weight (.clk(clk), .addr(fc2w_addr), .data(fc2w_data));

bram_rom #(.DATA_WIDTH(32), .ADDR_WIDTH(1), .DEPTH(1),
           .INIT_FILE("fc2_b.mem"))
u_fc2_bias (.clk(clk), .addr(fc2b_addr), .data(fc2b_data));

// FC2 Output: 1 byte (k·∫øt qu·∫£ cu·ªëi c√πng)
wire signed [7:0]  fc2_result;
wire               fc2o_we;
wire [0:0]         fc2o_wr_addr;

// FC2 ch·ªâ c√≥ 1 output -> kh√¥ng c·∫ßn BRAM, d√πng thanh ghi gi·ªØ k·∫øt qu·∫£
reg signed [7:0] fc2_result_reg;
always @(posedge clk) begin
    if (fc2o_we)
        fc2_result_reg <= fc2_result;
end

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// PIPELINE CONTROLLER FSM
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
localparam P_IDLE     = 4'd0;
localparam P_WAIT_IMG = 4'd1;   // ch·ª? frame_done t·ª´ camera
localparam P_CONV1    = 4'd2;
localparam P_POOL1    = 4'd3;
localparam P_CONV2    = 4'd4;
localparam P_POOL2    = 4'd5;
localparam P_CONV3    = 4'd6;
localparam P_FC1      = 4'd7;
localparam P_FC2      = 4'd8;
localparam P_DONE     = 4'd9;

reg [3:0] pipe_state = P_IDLE;

reg conv1_start, pool1_start, conv2_start;
reg pool2_start, conv3_start, fc1_start, fc2_start;

wire conv1_done, pool1_done, conv2_done;
wire pool2_done, conv3_done, fc1_done, fc2_done;

// K·∫øt qu·∫£ FIRE ƒë∆∞·ª£c gi·ªØ ·ªïn ƒë·ªãnh cho t·ªõi khi c√≥ ·∫£nh m·ªõi x·ª≠ l√Ω xong
reg fire_reg = 0;

always @(posedge clk) begin
    if (rst) begin
        pipe_state  <= P_IDLE;
        conv1_start <= 0; pool1_start <= 0;
        conv2_start <= 0; pool2_start <= 0;
        conv3_start <= 0; fc1_start   <= 0; fc2_start <= 0;
        fire_reg    <= 0;

    end else begin
        // M·∫∑c ƒë·ªãnh: t·∫Øt h·∫øt start signal (ch·ªâ b·∫≠t ƒë√∫ng 1 cycle)
        conv1_start <= 0; pool1_start <= 0;
        conv2_start <= 0; pool2_start <= 0;
        conv3_start <= 0; fc1_start   <= 0; fc2_start <= 0;

        case (pipe_state)

        P_IDLE: begin
            pipe_state <= P_WAIT_IMG;
        end

        // Ch·ª? camera ho√†n th√†nh m·ªôt frame 64x64 trong BRAM
        P_WAIT_IMG: begin
            if (frame_ready) begin
                conv1_start <= 1;
                pipe_state  <= P_CONV1;
            end
        end

        P_CONV1: if (conv1_done) begin
            pool1_start <= 1;
            pipe_state  <= P_POOL1;
        end

        P_POOL1: if (pool1_done) begin
            conv2_start <= 1;
            pipe_state  <= P_CONV2;
        end

        P_CONV2: if (conv2_done) begin
            pool2_start <= 1;
            pipe_state  <= P_POOL2;
        end

        P_POOL2: if (pool2_done) begin
            conv3_start <= 1;
            pipe_state  <= P_CONV3;
        end

        P_CONV3: if (conv3_done) begin
            fc1_start  <= 1;
            pipe_state <= P_FC1;
        end

        P_FC1: if (fc1_done) begin
            fc2_start  <= 1;
            pipe_state <= P_FC2;
        end

        P_FC2: if (fc2_done) begin
            // FIRE n·∫øu fc2 output > 0 (t∆∞∆°ng ƒë∆∞∆°ng sigmoid > 0.5)
            fire_reg   <=  (fc2_result > 8'sd40);
            pipe_state <= P_DONE;
        end

        // Xong 1 ·∫£nh -> quay l·∫°i ch·ª? frame camera ti·∫øp theo
        P_DONE: begin
            pipe_state <= P_WAIT_IMG;
        end

        endcase
    end
end

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// INSTANTIATE CONV / POOL / FC LAYERS
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?

// Conv1: 64x64x3 -> 64x64x8 (shift c·ªë ƒë·ªãnh = 9, ƒë·ª?u cho t·∫•t c·∫£ filter)
conv_layer #(.IMG_W(64), .IMG_H(64), .IN_CH(3), .OUT_CH(8),
             .KERNEL(3), .SHIFT_BITS(9))
u_conv1 (
    .clk(clk), .rst(rst), .start(conv1_start),
    .px_addr(fb_rd_addr), .px_data(fb_rd_data),
    .w_addr(c1w_addr),    .w_data(c1w_data),
    .b_addr(c1b_addr),    .b_data(c1b_data),
    .s_addr(),            .s_data(4'd9),     // shift c·ªë ƒë·ªãnh, kh√¥ng c·∫ßn BRAM
    .out_addr(c1o_wr_addr), .out_data(c1o_wr_data),
    .out_we(c1o_we), .done(conv1_done)
);

// Pool1: 64x64x8 -> 32x32x8
maxpool #(.IMG_W(64), .IMG_H(64), .CH(8))
u_pool1 (
    .clk(clk), .rst(rst), .start(pool1_start),
    .in_addr(c1o_rd_addr), .in_data(c1o_rd_data),
    .out_addr(p1o_wr_addr), .out_data(p1o_wr_data),
    .out_we(p1o_we), .done(pool1_done)
);

// Conv2: 32x32x8 -> 32x32x16 (shift c·ªë ƒë·ªãnh = 9)
conv_layer #(.IMG_W(32), .IMG_H(32), .IN_CH(8), .OUT_CH(16),
             .KERNEL(3), .SHIFT_BITS(9))
u_conv2 (
    .clk(clk), .rst(rst), .start(conv2_start),
    .px_addr(p1o_rd_addr), .px_data(p1o_rd_data),
    .w_addr(c2w_addr),     .w_data(c2w_data),
    .b_addr(c2b_addr),     .b_data(c2b_data),
    .s_addr(),             .s_data(4'd9),
    .out_addr(c2o_wr_addr), .out_data(c2o_wr_data),
    .out_we(c2o_we), .done(conv2_done)
);

// Pool2: 32x32x16 -> 16x16x16
maxpool #(.IMG_W(32), .IMG_H(32), .CH(16))
u_pool2 (
    .clk(clk), .rst(rst), .start(pool2_start),
    .in_addr(c2o_rd_addr), .in_data(c2o_rd_data),
    .out_addr(p2o_wr_addr), .out_data(p2o_wr_data),
    .out_we(p2o_we), .done(pool2_done)
);

// Conv3: 16x16x16 -> 16x16x16 (per-channel shift, ƒë·ª?c t·ª´ BRAM)
conv_layer #(.IMG_W(16), .IMG_H(16), .IN_CH(16), .OUT_CH(16),
             .KERNEL(3), .SHIFT_BITS(9))
u_conv3 (
    .clk(clk), .rst(rst), .start(conv3_start),
    .px_addr(p2o_rd_addr), .px_data(p2o_rd_data),
    .w_addr(c3w_addr),     .w_data(c3w_data),
    .b_addr(c3b_addr),     .b_data(c3b_data),
    .s_addr(c3s_addr),     .s_data(c3s_data),
    .out_addr(c3o_wr_addr), .out_data(c3o_wr_data),
    .out_we(c3o_we), .done(conv3_done)
);

// FC1: 2304 -> 16, c√≥ ReLU, per-neuron shift
fc_layer #(.IN_SIZE(2304), .OUT_SIZE(16), .USE_RELU(1), .ADDR_W(16))
u_fc1 (
    .clk(clk), .rst(rst), .start(fc1_start),
    .in_addr(c3o_rd_addr), .in_data(c3o_rd_data),
    .w_addr(fc1w_addr),    .w_data(fc1w_data),
    .b_addr(fc1b_addr),    .b_data(fc1b_data),
    .s_addr(fc1s_addr),    .s_data(fc1s_data),
    .out_addr(fc1o_wr_addr), .out_data(fc1o_wr_data),
    .out_we(fc1o_we), .done(fc1_done)
);

// FC2: 16 -> 1, KH√îNG ReLU, shift c·ªë ƒë·ªãnh = 7
fc_layer #(.IN_SIZE(16), .OUT_SIZE(1), .USE_RELU(0), .ADDR_W(4))
u_fc2 (
    .clk(clk), .rst(rst), .start(fc2_start),
    .in_addr(fc1o_rd_addr), .in_data(fc1o_rd_data),
    .w_addr(fc2w_addr),     .w_data(fc2w_data),
    .b_addr(fc2b_addr),     .b_data(fc2b_data),
    .s_addr(),              .s_data(4'd7),
    .out_addr(fc2o_wr_addr), .out_data(fc2_result),
    .out_we(fc2o_we), .done(fc2_done)
);

// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
// OUTPUT
// ‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?‚ï?
assign LED[0] = congtac;    //fire_reg;
assign LED[1] = (pipe_state == P_WAIT_IMG);
assign LED[2] =  (pipe_state == P_FC2);                //(pipe_state >= P_CONV1) && (pipe_state <= P_FC2);
assign LED[3] = rst;
assign inference_done = (pipe_state == P_DONE);

endmodule
