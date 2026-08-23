module mp_debouncer
(
    input clk,
    input reset_n,
    input [7:0] mp,
    output [2:0] msel_n,
    output [7:0] a_lo,
    output [7:0] a_hi,
    output [15:0] addr,
    output merq_n,
    output iorq_n,
    output cs1_n,
    output cs2_n,
    output reset_in_n,
    output rfsh_n,
    output cs12_n,
    output m1_n,
    output inputs_latched
);

    localparam int MP_A_LO = 0;
    localparam int MP_A_HI = 8;
    localparam int MP_CTRL = 16;
    localparam int MP_MERQ_N = 16;
    localparam int MP_IORQ_N = 17;
    localparam int MP_CS1_N = 18;
    localparam int MP_CS2_N = 19;
    localparam int MP_RESET_IN_N = 20;
    localparam int MP_RFSH_N = 21;
    localparam int MP_CS12_N = 22;
    localparam int MP_M1_N = 23;

    reg [2:0] msel_reg = 3'b111;
    reg [2:0] scan_phase = 3'd0;
    reg [23:0] previous_sample = 24'hffffff;
    reg [23:0] debounced = 24'hffffff;
    reg [23:0] latched = 24'hffffff;
    reg inputs_latched_reg = 1'b0;

    always_ff @(posedge clk or negedge reset_n)
    begin
        if(!reset_n) begin
            msel_reg <= 3'b111;
            scan_phase <= 3'd0;
            previous_sample <= 24'hffffff;
            debounced <= 24'hffffff;
            latched <= 24'hffffff;
            inputs_latched_reg <= 1'b0;
        end else begin
            inputs_latched_reg <= 1'b0;

            case (scan_phase)
                // Select A[7:0], then allow one clock for the mux to settle.
                3'd0: begin
                    msel_reg <= 3'b110;
                    scan_phase <= 3'd1;
                end
                3'd1: begin
                    for (int i = 0; i < 8; i++) begin
                        case ({previous_sample[MP_A_LO + i], mp[i]})
                            2'b00: debounced[MP_A_LO + i] <= 1'b0;
                            2'b11: debounced[MP_A_LO + i] <= 1'b1;
                            default: debounced[MP_A_LO + i] <= debounced[MP_A_LO + i];
                        endcase
                        previous_sample[MP_A_LO + i] <= mp[i];
                    end
                    msel_reg <= 3'b101;
                    scan_phase <= 3'd2;
                end

                // Select and sample A[15:8].
                3'd2: begin
                    scan_phase <= 3'd3;
                end
                3'd3: begin
                    for (int i = 0; i < 8; i++) begin
                        case ({previous_sample[MP_A_HI + i], mp[i]})
                            2'b00: debounced[MP_A_HI + i] <= 1'b0;
                            2'b11: debounced[MP_A_HI + i] <= 1'b1;
                            default: debounced[MP_A_HI + i] <= debounced[MP_A_HI + i];
                        endcase
                        previous_sample[MP_A_HI + i] <= mp[i];
                    end
                    msel_reg <= 3'b011;
                    scan_phase <= 3'd4;
                end

                // Select and sample the control signals, then publish one
                // coherent snapshot at the end of the six-clock scan.
                3'd4: begin
                    scan_phase <= 3'd5;
                end
                default: begin
                    for (int i = 0; i < 8; i++) begin
                        case ({previous_sample[MP_CTRL + i], mp[i]})
                            2'b00: begin
                                debounced[MP_CTRL + i] <= 1'b0;
                                latched[MP_CTRL + i] <= 1'b0;
                            end
                            2'b11: begin
                                debounced[MP_CTRL + i] <= 1'b1;
                                latched[MP_CTRL + i] <= 1'b1;
                            end
                            default: begin
                                debounced[MP_CTRL + i] <= debounced[MP_CTRL + i];
                                latched[MP_CTRL + i] <= debounced[MP_CTRL + i];
                            end
                        endcase
                        previous_sample[MP_CTRL + i] <= mp[i];
                    end

                    latched[MP_A_LO +: 8] <= debounced[MP_A_LO +: 8];
                    latched[MP_A_HI +: 8] <= debounced[MP_A_HI +: 8];
                    msel_reg <= 3'b110;
                    scan_phase <= 3'd0;
                    inputs_latched_reg <= 1'b1;
                end
            endcase
        end
    end

    assign msel_n = msel_reg;
    assign a_lo = latched[MP_A_LO +: 8];
    assign a_hi = latched[MP_A_HI +: 8];
    assign addr = {a_hi, a_lo};
    assign merq_n = latched[MP_MERQ_N];
    assign iorq_n = latched[MP_IORQ_N];
    assign cs1_n = latched[MP_CS1_N];
    assign cs2_n = latched[MP_CS2_N];
    assign reset_in_n = latched[MP_RESET_IN_N];
    assign rfsh_n = latched[MP_RFSH_N];
    assign cs12_n = latched[MP_CS12_N];
    assign m1_n = latched[MP_M1_N];
    assign inputs_latched = inputs_latched_reg;

endmodule
