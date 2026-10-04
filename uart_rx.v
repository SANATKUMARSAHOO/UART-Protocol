// =====================================================================
// Module      : uart_rx
// Description : UART Receiver
//               Samples an incoming serial line (rx) and reconstructs
//               the original 8-bit parallel data. Standard frame:
//               1 Start bit, 8 Data bits (LSB first), 1 Stop bit.
//               Uses mid-bit sampling for reliable data capture.
// =====================================================================

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,             // serial input line (idles high)
    output reg  [7:0] rx_data,        // received parallel byte
    output reg        rx_done         // pulses high for 1 clk when a byte is ready
);

    localparam integer BIT_PERIOD    = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_PERIOD   = BIT_PERIOD / 2;

    // FSM states
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_shift;

    // Two-stage synchronizer to avoid metastability on the async rx line
    reg rx_sync_0, rx_sync_1;
    always @(posedge clk) begin
        rx_sync_0 <= rx;
        rx_sync_1 <= rx_sync_0;
    end

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_shift  <= 0;
            rx_data   <= 0;
            rx_done   <= 1'b0;
        end else begin
            rx_done <= 1'b0;  // default: deassert (single-cycle pulse)

            case (state)

                // ---------------------------------------------------
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync_1 == 1'b0) begin
                        // falling edge detected -> possible start bit
                        state <= START;
                    end
                end

                // ---------------------------------------------------
                START: begin
                    // wait to sample at the middle of the start bit
                    // to confirm it's a valid start (not noise/glitch)
                    if (clk_count < HALF_PERIOD - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        if (rx_sync_1 == 1'b0) begin
                            clk_count <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE; // false start, glitch on line
                        end
                    end
                end

                // ---------------------------------------------------
                DATA: begin
                    // sample each data bit at the middle of its bit period
                    if (clk_count < BIT_PERIOD - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_shift[bit_index] <= rx_sync_1; // capture LSB first
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end

                // ---------------------------------------------------
                STOP: begin
                    if (clk_count < BIT_PERIOD - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_data   <= rx_shift;
                        rx_done   <= 1'b1;   // valid byte received
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
