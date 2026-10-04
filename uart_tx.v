// =====================================================================
// Module      : uart_tx
// Description : UART Transmitter
//               Sends 8-bit parallel data serially in the standard
//               UART frame format: 1 Start bit, 8 Data bits (LSB first),
//               1 Stop bit. No parity.
// =====================================================================

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,   // system clock frequency (Hz)
    parameter BAUD_RATE = 9600          // desired baud rate
) (
    input  wire       clk,
    input  wire       rst,             // synchronous active-high reset
    input  wire        tx_start,        // pulse high for 1 clk to begin transmission
    input  wire [7:0]  tx_data,         // parallel data byte to send
    output reg         tx,              // serial output line (idles high)
    output reg         tx_busy          // high while transmission in progress
);

    // Number of clock cycles per bit period
    localparam integer BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    // FSM states
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;

    reg [2:0]  state;
    reg [15:0] clk_count;   // counts clock cycles within one bit period
    reg [2:0]  bit_index;   // tracks which data bit is being sent
    reg [7:0]  tx_shift;    // shift register holding the byte being sent

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;   // idle line is high
            tx_busy   <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            tx_shift  <= 0;
        end else begin
            case (state)

                // ---------------------------------------------------
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        tx_shift <= tx_data;  // latch data to send
                        tx_busy  <= 1'b1;
                        state    <= START;
                    end
                end

                // ---------------------------------------------------
                START: begin
                    tx <= 1'b0;  // start bit is always 0
                    if (clk_count < BIT_PERIOD - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA;
                    end
                end

                // ---------------------------------------------------
                DATA: begin
                    tx <= tx_shift[bit_index]; // send LSB first
                    if (clk_count < BIT_PERIOD - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
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
                    tx <= 1'b1;  // stop bit is always 1
                    if (clk_count < BIT_PERIOD - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_busy   <= 1'b0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
