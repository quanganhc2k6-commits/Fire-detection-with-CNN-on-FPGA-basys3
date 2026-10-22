// fc_layer.v
// Fully Connected Layer: int8 weights, int32 bias, per-neuron shift
// Dùng cho FC1 (2304→16, ReLU) và FC2 (16→1, không ReLU)

module fc_layer #(
    parameter IN_SIZE  = 2304,  // số input features
    parameter OUT_SIZE = 16,    // số neuron output
    parameter USE_RELU = 1,     // 1=có ReLU (FC1), 0=không (FC2)
    parameter ADDR_W   = 16     // độ rộng địa chỉ
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    // Input BRAM (flatten output)
    output reg  [ADDR_W-1:0]  in_addr,
    input  wire signed [7:0]  in_data,

    // Weight BRAM
    output reg  [ADDR_W-1:0]  w_addr,
    input  wire signed [7:0]  w_data,

    // Bias BRAM (int32)
    output reg  [4:0]         b_addr,
    input  wire signed [31:0] b_data,

    // Shift BRAM
    output reg  [4:0]         s_addr,
    input  wire [3:0]         s_data,

    // Output BRAM
    output reg  [4:0]         out_addr,
    output reg  signed [7:0]  out_data,
    output reg                out_we,

    output reg                done
);

// ─── FSM States ───────────────────────────────────────────────
localparam S_IDLE       = 4'd0;
localparam S_LOAD_BIAS  = 4'd1;
localparam S_WAIT_ADD   = 4'd2; 
localparam S_WAIT_BIAS  = 4'd3;
localparam S_WAIT_LOOP  = 4'd4;
localparam S_MAC_LOOP   = 4'd5;
localparam S_WAIT_ACC   = 4'd6;
localparam S_REQUANT    = 4'd7;
localparam S_WRITE      = 4'd8;
localparam S_NEXT       = 4'd9;
localparam S_DONE       = 4'd10;

reg [3:0] state;

// ─── Counters ─────────────────────────────────────────────────
reg [$clog2(OUT_SIZE)-1:0] neuron_idx;
reg [$clog2(IN_SIZE)-1:0]  feat_idx; // feat_max = 16*16*32

// ─── Accumulator ──────────────────────────────────────────────
reg signed [31:0] acc;
reg signed [31:0] bias_reg;
reg [3:0]         shift_reg;

// ─── MAC ──────────────────────────────────────────────────────
wire signed [15:0] mul_result = w_data * in_data;  // int8×int8→int16

// ─── Requant logic ────────────────────────────────────────────
reg signed [31:0] sum_bias;
reg signed [31:0] shifted;
reg signed [7:0]  clamped;

always @(*) begin
    sum_bias = acc + bias_reg;

    // Right shift (arithmetic)
    shifted = $signed(sum_bias) >>> shift_reg;

    // ReLU + clamp
    if (USE_RELU && sum_bias < 0)
        clamped = 8'sd0;
    else if (shifted > 32'sd127)
        clamped = 8'sd127;
    else if (shifted < -32'sd128)
        clamped = -8'sd128;
    else
        clamped = shifted[7:0];
end

// ─── FSM ──────────────────────────────────────────────────────
always @(posedge clk) begin
    if (rst) begin
        state      <= S_IDLE;
        done       <= 0;
        out_we     <= 0;
        neuron_idx <= 0;
        feat_idx   <= 0;
        acc        <= 0;

    end else begin
        out_we <= 0;
        done   <= 0;

        case (state)

        // ── IDLE ─────────────────────────────────────────────
        S_IDLE: begin
            if (start) begin
                neuron_idx <= 0;
                feat_idx   <= 0;
                state      <= S_LOAD_BIAS;
            end
        end

        // ── NẠP BIAS + SHIFT ─────────────────────────────────
        S_LOAD_BIAS: begin   // neuton=0, feat = 0
            b_addr <= neuron_idx;
            s_addr <= neuron_idx;
            state  <= S_WAIT_ADD;
        end
        S_WAIT_ADD: begin // có add
            state <= S_WAIT_BIAS;
            end
        S_WAIT_BIAS: begin // có data
            bias_reg  <= b_data;
            shift_reg <= s_data;
            acc       <= 0;
            feat_idx  <= 0;

            // Set địa chỉ weight đầu tiên
            // Layout weight: [neuron][feature]
            w_addr <= neuron_idx * IN_SIZE;
            in_addr <= 0;
            state  <= S_WAIT_LOOP;
        end
        S_WAIT_LOOP: begin // có add cho w và in
            state <= S_MAC_LOOP;
            end
        // ── MAC LOOP ─────────────────────────────────────────
        S_MAC_LOOP: begin // có data cho w và in
            // Tích lũy: acc += weight × input
            acc <= acc + {{16{mul_result[15]}}, mul_result};

            if (feat_idx < IN_SIZE - 1) begin     // feat_idx là feature index
                feat_idx <= feat_idx + 1;
                w_addr   <= neuron_idx * IN_SIZE + feat_idx + 1;
                in_addr  <= feat_idx + 1;
                state    <= S_WAIT_LOOP;
            end else begin
                  state <= S_WAIT_ACC;
            end
            end

            S_WAIT_ACC: begin
            state <= S_REQUANT;
            end

        // ── REQUANT (combinational đã tính sẵn) ──────────────
        S_REQUANT: begin
            out_addr <= neuron_idx;
            out_data <= clamped;
            state    <= S_WRITE;
        end

        // ── GHI OUTPUT ───────────────────────────────────────
        S_WRITE: begin
            out_we <= 1;
            state  <= S_NEXT;
        end

        // ── CHUYỂN NEURON TIẾP THEO ──────────────────────────
        S_NEXT: begin
            out_we <= 0;
            if (neuron_idx < OUT_SIZE - 1) begin
                neuron_idx <= neuron_idx + 1;
                state      <= S_LOAD_BIAS;
            end else begin
                state <= S_DONE;
            end
        end

        // ── DONE ─────────────────────────────────────────────
        S_DONE: begin
            done  <= 1;
            state <= S_IDLE;
        end

        endcase
    end
end

endmodule