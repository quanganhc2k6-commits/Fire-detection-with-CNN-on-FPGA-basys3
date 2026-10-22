`timescale 1ns / 1ps

module rgb565_bram_to_rgb888_bytes (
    input  wire        clk,
    input  wire [13:0] byte_addr,
    output reg  [7:0]  byte_data,
    output wire [12:0] bram_rd_addr,
    input  wire [15:0] bram_rd_data
);
    wire [13:0] pixel_index_full = byte_addr / 3;
    wire [1:0]  channel_now      = byte_addr % 3;
    reg  [1:0]  channel_q;

    wire [4:0] r5 = bram_rd_data[15:11];
    wire [5:0] g6 = bram_rd_data[10:5];
    wire [4:0] b5 = bram_rd_data[4:0];

    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};

    assign bram_rd_addr = pixel_index_full[12:0];

    always @(posedge clk) begin
        channel_q <= channel_now;
    end

    always @(*) begin
        case (channel_q)
            2'd0: byte_data = r8;
            2'd1: byte_data = g8;
            2'd2: byte_data = b8;
            default: byte_data = 8'd0;
        endcase
    end
endmodule

module frame_handshake_cdc (
    input  wire pclk,
    input  wire rst_pclk,
    input  wire frame_done_raw,
    input  wire ai_done_toggle_async,
    output wire camera_ram_we_allow,
    output reg  frame_toggle_pclk
);
    reg ai_done_sync1;
    reg ai_done_sync2;
    reg ai_done_sync2_d;
    reg frame_locked;

    assign camera_ram_we_allow = ~frame_locked;

    always @(posedge pclk or posedge rst_pclk) begin
        if (rst_pclk) begin
            ai_done_sync1  <= 1'b0;
            ai_done_sync2  <= 1'b0;
            ai_done_sync2_d<= 1'b0;
            frame_locked   <= 1'b0;
            frame_toggle_pclk <= 1'b0;
        end else begin
            ai_done_sync1   <= ai_done_toggle_async;
            ai_done_sync2   <= ai_done_sync1;
            ai_done_sync2_d <= ai_done_sync2;

            if (ai_done_sync2 ^ ai_done_sync2_d)
                frame_locked <= 1'b0;

            if (frame_done_raw && !frame_locked) begin
                frame_locked      <= 1'b1;
                frame_toggle_pclk <= ~frame_toggle_pclk;
            end
        end
    end
endmodule

module frame_toggle_to_pulse (
    input  wire clk,
    input  wire rst,
    input  wire frame_toggle_async,
    output wire frame_done_pulse
);
    reg sync1;
    reg sync2;
    reg sync2_d;

    always @(posedge clk) begin
        if (rst) begin
            sync1   <= 1'b0;
            sync2   <= 1'b0;
            sync2_d <= 1'b0;
        end else begin
            sync1   <= frame_toggle_async;
            sync2   <= sync1;
            sync2_d <= sync2;
        end
    end

    assign frame_done_pulse = sync2 ^ sync2_d;
endmodule

module pulse_to_toggle (
    input  wire clk,
    input  wire rst,
    input  wire pulse_in,
    output reg  toggle_out
);
    always @(posedge clk) begin
        if (rst)
            toggle_out <= 1'b0;
        else if (pulse_in)
            toggle_out <= ~toggle_out;
    end
endmodule
