// maxpool.v - Fixed version
module maxpool #(
    parameter IMG_W = 64,
    parameter IMG_H = 64,
    parameter CH    = 8
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    output reg  [15:0]       in_addr,
    input  wire signed [7:0] in_data,

    output reg  [15:0]       out_addr,
    output reg  signed [7:0] out_data,
    output reg               out_we,

    output reg               done
);

    localparam OUT_W = IMG_W / 2;
    localparam OUT_H = IMG_H / 2;

    localparam S_IDLE    = 4'd0,
               S_READ_00 = 4'd1,
               S_WAIT_00 = 4'd2,
               S_READ_01 = 4'd3,
               S_READ_10 = 4'd4,
               S_READ_11 = 4'd5,
               S_WAIT    = 4'd6,
               S_COMPARE = 4'd7,
               S_WRITE   = 4'd8,
               S_NEXT    = 4'd9,
               S_DONE    = 4'd10;

    reg [3:0] state;

    reg [$clog2(OUT_H):0] row;
    reg [$clog2(OUT_W):0] col;
    reg [$clog2(CH):0]    ch;

    reg signed [7:0] v00, v01, v10;
    reg signed [7:0] max_val;

    // ─── Combinational max logic ───────────────────────────
    // Tách riêng thành wire để tránh hoàn toàn vấn đề blocking/non-blocking
    wire signed [7:0] max01  = (v01  > v00)    ? v01    : v00;
    wire signed [7:0] max012 = (v10  > max01)  ? v10    : max01;
    wire signed [7:0] max_all= (in_data > max012) ? in_data : max012;
    // in_data ở đây chính là v11 (pixel thứ 4, đọc 1 cycle trước)

    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            done    <= 1'b0;
            out_we  <= 1'b0;
            row     <= 0;
            col     <= 0;
            ch      <= 0;
            v00     <= 8'd0;
            v01     <= 8'd0;
            v10     <= 8'd0;
            max_val <= 8'd0;
        end else begin
            out_we <= 1'b0;
            done   <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        row   <= 0;
                        col   <= 0;
                        ch    <= 0;
                        state <= S_READ_00;
                    end
                end

                S_READ_00: begin
                    in_addr <= (row * 2) * IMG_W * CH + (col * 2) * CH + ch;
                    state   <= S_WAIT_00;
                end
                S_WAIT_00: begin // có địa chỉ 00
                     in_addr <= (row * 2) * IMG_W * CH + (col * 2 + 1) * CH + ch;
                     state   <= S_READ_01;
                     end
                S_READ_01: begin // có địa chỉ 01, có data_00
                    v00     <= in_data;
                    in_addr <= (row * 2 + 1) * IMG_W * CH + (col * 2) * CH + ch;
                    state   <= S_READ_10;
                end

                S_READ_10: begin // v00 có data
                    v01     <= in_data;
                  in_addr <= (row * 2 + 1) * IMG_W * CH + (col * 2 + 1) * CH + ch;
                    state   <= S_READ_11;
                end

                S_READ_11: begin // v01 có data
                    v10     <= in_data;
                    state   <= S_WAIT;
                end
                S_WAIT: begin //v10 có data
                state <= S_COMPARE;
                end
                // ✅ Dùng wire max_all — hoàn toàn combinational, không có race condition
                S_COMPARE: begin // v11 có data
                    max_val  <= max_all;  // max_all dùng in_data (= v11) trực tiếp
                    out_addr <= row * OUT_W * CH + col * CH + ch;
                    state    <= S_WRITE;
                end

                S_WRITE: begin
                    out_data <= max_val;
                    out_we   <= 1'b1;
                    state    <= S_NEXT;
                end

                S_NEXT: begin
                    if (ch < CH - 1) begin
                        ch    <= ch + 1;
                        state <= S_READ_00;
                    end else if (col < OUT_W - 1) begin
                        col   <= col + 1;
                        ch    <= 0;
                        state <= S_READ_00;
                    end else if (row < OUT_H - 1) begin
                        row   <= row + 1;
                        col   <= 0;
                        ch    <= 0;
                        state <= S_READ_00;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule