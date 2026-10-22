module cau_hinh_camera (
    input  wire clk,      // Xung kích gốc 25MHz
    input  wire reset,    // Tín hiệu reset hệ thống (tích cực cao)
    inout  wire cam_sda,  // Đường dữ liệu I2C/SCCB
    output wire cam_scl,  // Đường xung clock I2C/SCCB
    output reg  led_done  // Đèn báo cấu hình xong toàn bộ ROM

);


    // ROM CONFIG OV7670
    reg [15:0] rom_data;
    reg [7:0]  rom_addr;



    always @(*) begin
        case (rom_addr)
            8'd0:  rom_data = 16'h12_80; // COM7: Reset toàn bộ thanh ghi
            8'd1:  rom_data = 16'h12_04; // COM7: Định dạng đầu ra ra COM7
            8'd2:  rom_data = 16'h40_d0; // COM15: Định dạng RGB565
            8'd3:  rom_data = 16'h14_1a; // COM9: Giới hạn mức tăng tự động
            8'd4:  rom_data = 16'h0c_00; // COM3: Thiết lập mặc định
            8'd5:  rom_data = 16'h3e_19; // COM14: Chia tỉ lệ pixel 
            8'd6:  rom_data = 16'h70_3a; // SCALING_XSC
            8'd7:  rom_data = 16'h71_35; // SCALING_YSC
            8'd8:  rom_data = 16'h72_11; // SCALING_DCWCTR
            8'd9:  rom_data = 16'h73_f1; // SCALING_PCLK_DIV
            8'd10: rom_data = 16'ha2_02; // BLC_NUM
            default: rom_data = 16'hFF_FF; // Kết thúc mảng
        endcase
    end


    // SCCB CLOCK GENERATOR WITH ENABLER CONTROL
    reg [7:0] clk_cnt;
    reg scl_reg;
    reg scl_en; // Cho phép xuất xung SCL (Chỉ bật khi đang truyền dữ liệu)



    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_cnt <= 0;
            scl_reg <= 1;
        end else begin
            if (clk_cnt == 249) begin
                clk_cnt <= 0;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end          
            // Tạo xung 50/50
            if (clk_cnt < 125) scl_reg <= 1;
            else               scl_reg <= 0;
        end
    end



    // SCL chỉ dao động ở trạng thái truyền dữ liệu và ACK, còn lại giữ HIGH
    assign cam_scl = (scl_en) ? scl_reg : 1'b1;
    wire tick_mid_high = (clk_cnt == 62);  
    wire tick_mid_low  = (clk_cnt == 187); 



    // SDA TRI-STATE CONTROL


    reg sda_out;
    reg sda_oe;



    assign cam_sda = (sda_oe) ? sda_out : 1'bz;
    wire sda_in = cam_sda;


    // FSM STATES


    reg [3:0] state;



    localparam IDLE       = 4'd0;
    localparam START      = 4'd1;
    localparam ADDR       = 4'd2;
    localparam REG_A      = 4'd3;
    localparam DATA       = 4'd4;
    localparam ACK        = 4'd5;
    localparam STOP       = 4'd6;
    localparam DELAY_RST  = 4'd7;



    localparam CAM_ADDR   = 8'h42;


    reg [7:0] tx_byte;
    reg [2:0] bit_cnt;
    reg [1:0] phase;     
    reg [15:0] delay_cnt;
    reg ack_ok;


    // MAIN FSM

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            rom_addr <= 0;
            led_done <= 0;
            
            sda_out  <= 1;
            sda_oe   <= 0;
            scl_en   <= 0;

            bit_cnt  <= 7;
            phase    <= 0;
            delay_cnt<= 0;
            ack_ok   <= 0;
            tx_byte  <= 8'h00;

        end else begin

             state     <= state;
            rom_addr  <= rom_addr;
            tx_byte   <= tx_byte;
            case (state)



                IDLE: begin
                    scl_en  <= 0; // Tắt xung nhịp SCL khi nghỉ
                    sda_oe  <= 1;
                    sda_out <= 1; 



                    if (rom_data == 16'hFFFF) begin
                        led_done <= 1; 
                    end else begin
                        state <= START;
                    end
                end



                START: begin

                    // Phát START điều kiện: SDA kéo xuống thấp khi SCL cao
                    if (tick_mid_high) begin
                        sda_oe  <= 1;
                        sda_out <= 0; 
                        scl_en  <= 1; // Bật xung SCL chạy kể từ đây

                        

                        tx_byte <= CAM_ADDR;
                        bit_cnt <= 7;
                        phase   <= 0;
                        state   <= ADDR;
                    end
                end



                ADDR, REG_A, DATA: begin
                    if (tick_mid_low) begin
                        sda_oe  <= 1;
                        sda_out <= tx_byte[bit_cnt];
                    end



                    if (tick_mid_high) begin
                        if (bit_cnt == 0) begin
                            state  <= ACK;
                            sda_oe <= 0; // Thả chân SDA cho Slave phản hồi
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end


                ACK: begin

                    // Đọc bit phản hồi từ chân SDA tại đỉnh High của SCL
                    if (tick_mid_high) begin
                        ack_ok <= ~sda_in;                      
                        // Chuyển dịch Phase dựa trên trạng thái hiện tại                      
                        if (phase == 0) begin
                            tx_byte <= rom_data[15:8]; 
                            bit_cnt <= 7;
                            phase   <= 1;
                            state   <= REG_A;
                        end
                        else if (phase == 1) begin
                            tx_byte <= rom_data[7:0];  
                            bit_cnt <= 7;
                            phase   <= 2;
                            state   <= DATA;
                        end
                        else begin
                            state   <= STOP;           
                        end
                    end
                end



                STOP: begin
                    if (tick_mid_low) begin
                        sda_oe  <= 1;
                        sda_out <= 0; // Chuẩn bị SDA ở mức thấp
                    end


                    if (tick_mid_high) begin
                        sda_out <= 1; // Kéo SDA lên cao tạo tín hiệu STOP
                        scl_en  <= 0; // Khóa SCL giữ mức cao ổn định                   
                        if (rom_addr == 8'd0) begin
                            delay_cnt <= 0;
                            state     <= DELAY_RST; 
                        end else begin
                            rom_addr  <= rom_addr + 1; 
                            state     <= IDLE;
                        end
                    end
                end



                DELAY_RST: begin
                    // Đếm độc lập bằng xung clk 25MHz để tạo thời gian trễ ổn định
                    if (delay_cnt == 16'hFFFF) begin // Khoảng 2.6 ms nghỉ
                        rom_addr <= rom_addr + 1;
                        state    <= IDLE;
                    end else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule 