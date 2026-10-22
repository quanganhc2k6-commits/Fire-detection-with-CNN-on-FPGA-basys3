// conv_layer.v
// Generic Conv2D: int8 input, int8 weights, int32 bias, per-channel shift
// padding = VALID  ? output size = (IMG_H - KERNEL + 1) x (IMG_W - KERNEL + 1)
//
// Ki?n tr�c model th?c t? (t? b?ng tensor):
//   Conv1: input 64x64x3  ? output 62x62x8
//   Conv2: input 31x31x8  ? output 29x29x16
//   Conv3: input 14x14x16 ? output 12x12x16
//
// BRAM timing: m?i l?n d?c c?n 2 state: SET_ADDR ? WAIT ? d?c data
// FSM flow per pixel per filter:
//   LOAD_BIAS ? WAIT_BIAS ? CONV_START
//   ? [SET_ADDR ? WAIT_DATA ? MAC] � (KERNEL�KERNEL�IN_CH l?n)
//   ? REQUANT ? WRITE_OUT ? NEXT_FILTER / NEXT_PIXEL

module conv_layer #(
    parameter IMG_W      = 64,   // chi?u r?ng INPUT
    parameter IMG_H      = 64,   // chi?u cao INPUT
    parameter IN_CH      = 3,    // s? channel input
    parameter OUT_CH     = 8,    // s? filter output
    parameter KERNEL     = 3,    // kernel size (ch? h? tr? 3)
    parameter SHIFT_BITS = 9     // default shift n?u kh�ng d�ng per-channel BRAM
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               start,       // pulse 1 cycle d? b?t d?u frame

    // Input pixel BRAM (frame buffer)
    output wire [15:0]        px_addr,
    input  wire signed [7:0]  px_data,

    // Weight BRAM
    output wire [15:0]        w_addr,
    input  wire signed [7:0]  w_data,

    // Bias BRAM (int32, per-channel)
    output reg  [4:0]         b_addr,
    input  wire signed [31:0] b_data,

    // Shift BRAM (per-channel, 4-bit shift value)
    output reg  [4:0]         s_addr,
    input  wire [3:0]         s_data,

    // Output BRAM
    output reg  [15:0]        out_addr,
    output reg  signed [7:0]  out_data,
    output reg                out_we,

    output reg                done        // pulse 1 cycle khi xong frame
);
(* use_dsp = "yes" *) reg signed [31:0] acc;
// --- Output size (valid padding) ------------------------------
localparam OUT_W = IMG_W - KERNEL + 1;   // 64?62, 31?29, 14?12
localparam OUT_H = IMG_H - KERNEL + 1;

// --- FSM States -----------------------------------------------
localparam S_IDLE        = 4'd0,
           S_LOAD_BIAS   = 4'd1,   // ghi b_addr, s_addr v�o BRAM
           S_WAIT_BIAS   = 4'd2,   // ch? 1 cycle BRAM tr? b_data, s_data
           S_CONV_START  = 4'd3,   // latch bias_reg, shift_reg; reset acc, counters
           S_SET_ADDR    = 4'd4,   // ghi w_addr + px_addr (1 � kernel)
           S_WAIT_DATA   = 4'd5,   // ch? 1 cycle BRAM tr? w_data, px_data
           S_MAC         = 4'd6,   // d?c data + c?ng v�o acc + tang counter
           S_REQUANT     = 4'd7,   // ReLU + shift + clamp v? int8
           S_WRITE_OUT   = 4'd8,   // ghi out_data ra output BRAM
           S_NEXT_FILTER = 4'd9,   // chuy?n filter ti?p theo ho?c sang NEXT_PIXEL
           S_NEXT_PIXEL  = 4'd10,  // chuy?n pixel output ti?p theo
           S_DONE        = 4'd11;

reg [3:0] state;

// --- Counters -------------------------------------------------
// row, col l� t?a d? pixel OUTPUT (valid range: 0..OUT_H-1, 0..OUT_W-1)
integer row, col, filter_idx;
integer kr, kc, ch;   // v? tr� trong c?a s? kernel 3�3�IN_CH

// --- Accumulator & latch --------------------------------------
// đánh dấu reg signed[31:0] acc;
reg signed [31:0] bias_reg;
integer           shift_reg;

// --- Address registers ----------------------------------------
integer w_addr_int;
integer p_addr_int;

assign w_addr  = w_addr_int[15:0];
assign px_addr = p_addr_int[15:0];

// --- Requant temporaries (d�ng trong S_REQUANT) ---------------
reg signed [31:0] sum_with_bias;
reg signed [31:0] shifted_val;
reg signed [7:0]  clamped;

// --- MAC intermediate -----------------------------------------
// int8 � int8 ? int16, sign-extend l�n int32 tru?c khi c?ng v�o acc
wire signed [15:0] mul16 = w_data * px_data;
wire signed [31:0] mul32 = {{16{mul16[15]}}, mul16};  // sign-extend

// ---------------------------------------------------------------
// FSM CH�NH
// ---------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        state      <= S_IDLE;
        done       <= 0;
        out_we     <= 0;
        row        <= 0;  col        <= 0;
        filter_idx <= 0;  kr         <= 0;
        kc         <= 0;  ch         <= 0;
        acc        <= 0;
        bias_reg   <= 0;
        shift_reg  <= SHIFT_BITS;
        w_addr_int <= 0;
        p_addr_int <= 0;
        b_addr     <= 0;
        s_addr     <= 0;
        out_addr   <= 0;
        out_data   <= 0;

    end else begin
        out_we <= 0;
        done   <= 0;

        case (state)

        // ----------------------------------------------------
        // IDLE: ch? start pulse
        // ----------------------------------------------------
        S_IDLE: begin
            if (start) begin
                row        <= 0;
                col        <= 0;
                filter_idx <= 0;
                state      <= S_LOAD_BIAS;
            end
        end

        // ----------------------------------------------------
        // LOAD_BIAS: ghi d?a ch? bias + shift BRAM cho filter hi?n t?i
        // ----------------------------------------------------
        S_LOAD_BIAS: begin
            b_addr <= filter_idx[4:0];
            s_addr <= filter_idx[4:0];
            state  <= S_WAIT_BIAS;
        end

        // ----------------------------------------------------
        // WAIT_BIAS: BRAM dang x? l� d?a ch?,
        // data s? h?p l? ? cycle TI?P THEO (S_CONV_START)
        // ----------------------------------------------------
        S_WAIT_BIAS: begin
            state <= S_CONV_START;
        end

        // ----------------------------------------------------
        // CONV_START: b_data & s_data d� h?p l? ? latch v�o reg
        //             reset acc, kh?i t?o kernel counters
        // ----------------------------------------------------
        S_CONV_START: begin
            bias_reg  <= b_data;
            // N?u s_data == 0 (kh�ng d�ng per-channel BRAM) ? d�ng SHIFT_BITS m?c d?nh
            shift_reg <= (s_data == 0) ? SHIFT_BITS : s_data;
            acc       <= 0;
            kr        <= 0;
            kc        <= 0;
            ch        <= 0;
            state     <= S_SET_ADDR;
        end

        // ----------------------------------------------------
        // SET_ADDR: t�nh d?a ch? weight + pixel cho 1 � trong c?a s? kernel
        //
        // Valid padding: kh�ng c?n ki?m tra padding
        // Pixel input tuong ?ng v?i output pixel (row, col)
        // t?i kernel offset (kr, kc) l�:
        //   input_row = row + kr      (kh�ng tr? KERNEL/2 nhu same padding)
        //   input_col = col + kc
        // T?t c? d?u h?p l? v� row ? [0, OUT_H-1], kr ? [0, KERNEL-1]
        // ? input_row ? [0, OUT_H-1+KERNEL-1] = [0, IMG_H-1] ?
        // ----------------------------------------------------
        S_SET_ADDR: begin
            // Pixel input address: layout [row][col][ch]
            p_addr_int <= (row + kr) * IMG_W * IN_CH
                        + (col + kc) * IN_CH
                        + ch;

            // Weight address: layout [filter][kr][kc][ch]
            w_addr_int <= filter_idx * (KERNEL * KERNEL * IN_CH)
                        + kr         * (KERNEL * IN_CH)
                        + kc         * IN_CH
                        + ch;

            state <= S_WAIT_DATA;
        end

        // ----------------------------------------------------
        // WAIT_DATA: BRAM dang x? l� d?a ch?,
        // w_data v� px_data h?p l? ? cycle TI?P THEO (S_MAC)
        // ----------------------------------------------------
        S_WAIT_DATA: begin
            state <= S_MAC;
        end

        // ----------------------------------------------------
        // MAC: w_data v� px_data d� h?p l?
        //      C?ng d?n v�o acc, sau d� tang kernel counter
        // ----------------------------------------------------
        S_MAC: begin
            // Kh�ng c?n ki?m tra is_pad (valid padding, m?i � d?u h?p l?)
            acc <= acc + mul32;

            // Tang counter: ch ? kc ? kr
            if (ch < IN_CH - 1) begin
                ch    <= ch + 1;
                state <= S_SET_ADDR;
            end else if (kc < KERNEL - 1) begin
                kc    <= kc + 1;
                ch    <= 0;
                state <= S_SET_ADDR;
            end else if (kr < KERNEL - 1) begin
                kr    <= kr + 1;
                kc    <= 0;
                ch    <= 0;
                state <= S_SET_ADDR;
            end else begin
                // Xong kernel 3�3�IN_CH ? sang requantize
                state <= S_REQUANT;
            end
        end

        // ----------------------------------------------------
        // REQUANT: ReLU + right shift + clamp v? int8
        // ----------------------------------------------------
        S_REQUANT: begin
            sum_with_bias = acc + bias_reg;

            if (sum_with_bias < 0) begin
                // ReLU: clip �m v? 0
                clamped = 8'sh00;
            end else begin
                // Arithmetic right shift (gi? d?u)
                shifted_val = $signed(sum_with_bias) >>> shift_reg;

                // Clamp v? range int8 [-128, 127]
                if (shifted_val > 32'sh0000007F)
                    clamped = 8'sh7F;          // 127
                else if (shifted_val < -32'sh00000080)
                    clamped = -8'sh80;         // -128
                else
                    clamped = shifted_val[7:0];
            end

            // Output address: layout [row][col][filter]
            // D�ng OUT_W (k�ch thu?c output sau valid padding)
            out_addr <= row * OUT_W * OUT_CH
                      + col * OUT_CH
                      + filter_idx;
            out_data <= clamped;

            state <= S_WRITE_OUT;
        end

        // ----------------------------------------------------
        // WRITE_OUT: b?t out_we d? ghi v�o output BRAM
        // ----------------------------------------------------
        S_WRITE_OUT: begin
            out_we <= 1;
            state  <= S_NEXT_FILTER;
        end

        // ----------------------------------------------------
        // NEXT_FILTER: chuy?n sang filter ti?p theo c?a c�ng pixel output
        //              ho?c sang pixel output ti?p theo n?u h?t filter
        // ----------------------------------------------------
        S_NEXT_FILTER: begin
            out_we <= 0;
            if (filter_idx < OUT_CH - 1) begin
                filter_idx <= filter_idx + 1;
                state      <= S_LOAD_BIAS;     // n?p bias cho filter m?i
            end else begin
                filter_idx <= 0;
                state      <= S_NEXT_PIXEL;
            end
        end

        // ----------------------------------------------------
        // NEXT_PIXEL: tang col ? row ? DONE
        // Ch� �: loop theo k�ch thu?c OUTPUT (OUT_W, OUT_H)
        //        kh�ng ph?i IMG_W, IMG_H
        // ----------------------------------------------------
        S_NEXT_PIXEL: begin
            if (col < OUT_W - 1) begin
                col   <= col + 1;
                state <= S_LOAD_BIAS;
            end else if (row < OUT_H - 1) begin
                row   <= row + 1;
                col   <= 0;
                state <= S_LOAD_BIAS;
            end else begin
                state <= S_DONE;
            end
        end

        // ----------------------------------------------------
        // DONE: b�o hi?u xong frame
        // ----------------------------------------------------
        S_DONE: begin
            done  <= 1;
            state <= S_IDLE;
        end

        default: state <= S_IDLE;

        endcase
    end
end

endmodule