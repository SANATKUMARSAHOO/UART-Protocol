// =====================================================================
// Module      : uart_top
// Description : Top-level wrapper instantiating both the UART
//               transmitter and receiver. Useful for loopback testing
//               (connect tx -> rx externally, or internally as shown).
// =====================================================================

module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
) (
    input  wire       clk,
    input  wire       rst,

    // Transmit side
    input  wire        tx_start,
    input  wire [7:0]  tx_data,
    output wire        tx,
    output wire        tx_busy,

    // Receive side
    input  wire        rx,
    output wire [7:0]  rx_data,
    output wire        rx_done
);

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_tx (
        .clk      (clk),
        .rst      (rst),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (tx),
        .tx_busy  (tx_busy)
    );

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_rx (
        .clk     (clk),
        .rst     (rst),
        .rx      (rx),
        .rx_data (rx_data),
        .rx_done (rx_done)
    );

endmodule
