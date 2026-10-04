// =====================================================================
// Module      : uart_tb
// Description : Testbench for uart_top.
//               Drives tx_data through the transmitter, loops tx
//               directly back into rx, and checks that rx_data
//               matches the original byte sent.
// =====================================================================

`timescale 1ns/1ps

module uart_tb;

    // Small clock/baud ratio keeps simulation time short.
    // (16 clocks per bit period is still enough margin for mid-bit sampling)
    localparam CLK_FREQ  = 1_600_000;
    localparam BAUD_RATE = 100_000;
    localparam CLK_PERIOD = 10; // ns -> 100 MHz test clock, scaled for sim speed

    reg        clk;
    reg        rst;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx_line;
    wire       tx_busy;
    wire [7:0] rx_data;
    wire       rx_done;

    integer errors = 0;
    reg [7:0] test_bytes [0:3];
    integer i;

    // -----------------------------------------------------------------
    // DUT instantiation (loopback: tx_line feeds directly into rx)
    // -----------------------------------------------------------------
    uart_top #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (tx_line),
        .tx_busy  (tx_busy),
        .rx       (tx_line),   // loopback
        .rx_data  (rx_data),
        .rx_done  (rx_done)
    );

    // -----------------------------------------------------------------
    // Clock generation
    // -----------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // -----------------------------------------------------------------
    // Stimulus
    // -----------------------------------------------------------------
    initial begin
        clk      = 0;
        rst      = 1;
        tx_start = 0;
        tx_data  = 8'h00;

        test_bytes[0] = 8'h55;  // 0101_0101
        test_bytes[1] = 8'hA3;
        test_bytes[2] = 8'h00;
        test_bytes[3] = 8'hFF;

        repeat (5) @(posedge clk);
        rst = 0;
        @(posedge clk);

        for (i = 0; i < 4; i = i + 1) begin
            send_byte(test_bytes[i]);
            wait (rx_done);
            @(posedge clk); // allow rx_data to settle for the check below
            if (rx_data !== test_bytes[i]) begin
                $display("FAIL: sent 0x%0h, received 0x%0h", test_bytes[i], rx_data);
                errors = errors + 1;
            end else begin
                $display("PASS: sent 0x%0h, received 0x%0h", test_bytes[i], rx_data);
            end
            repeat (20) @(posedge clk); // idle gap between frames
        end

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

    // -----------------------------------------------------------------
    // Task: pulse tx_start for one clock and load tx_data
    // -----------------------------------------------------------------
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            tx_data  = data;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
        end
    endtask

    // Waveform dump for GTKWave / Vivado
    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end

endmodule
