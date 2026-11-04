// Combinational 7-segment decoder, common-cathode (active high)
// Bit order: seg = {a, b, c, d, e, f, g}  -> seg[6] = a ... seg[0] = g
//
//        aaa
//       f   b
//        ggg
//       e   c
//        ddd
//
//  count | hex |  a b c d e f g
//  ------+-----+---------------
//  0000  |  0  |  1 1 1 1 1 1 0
//  0001  |  1  |  0 1 1 0 0 0 0
//  0010  |  2  |  1 1 0 1 1 0 1
//  0011  |  3  |  1 1 1 1 0 0 1
//  0100  |  4  |  0 1 1 0 0 1 1
//  0101  |  5  |  1 0 1 1 0 1 1
//  0110  |  6  |  1 0 1 1 1 1 1
//  0111  |  7  |  1 1 1 0 0 0 0
//  1000  |  8  |  1 1 1 1 1 1 1
//  1001  |  9  |  1 1 1 1 0 1 1
//  1010  |  A  |  1 1 1 0 1 1 1
//  1011  |  b  |  0 0 1 1 1 1 1
//  1100  |  C  |  1 0 0 1 1 1 0
//  1101  |  d  |  0 1 1 1 1 0 1
//  1110  |  E  |  1 0 0 1 1 1 1
//  1111  |  F  |  1 0 0 0 1 1 1
module seven_segment (
    input      [3:0] count,
    output reg [6:0] seg
);

    always @(*) begin
        case (count)
            4'b0000: seg = 7'b1111110; // 0
            4'b0001: seg = 7'b0110000; // 1
            4'b0010: seg = 7'b1101101; // 2
            4'b0011: seg = 7'b1111001; // 3
            4'b0100: seg = 7'b0110011; // 4
            4'b0101: seg = 7'b1011011; // 5
            4'b0110: seg = 7'b1011111; // 6
            4'b0111: seg = 7'b1110000; // 7
            4'b1000: seg = 7'b1111111; // 8
            4'b1001: seg = 7'b1111011; // 9
            4'b1010: seg = 7'b1110111; // A
            4'b1011: seg = 7'b0011111; // b
            4'b1100: seg = 7'b1001110; // C
            4'b1101: seg = 7'b0111101; // d
            4'b1110: seg = 7'b1001111; // E
            4'b1111: seg = 7'b1000111; // F
            default: seg = 7'b0000000;
        endcase
    end

endmodule
// Top level: run-controlled counter FSM + 7-segment decoder
module top_module (
    input        clk,
    input        reset,   // synchronous, active high
    input        run,
    output [3:0] count,
    output [6:0] seg      // common-cathode, active high, {a,b,c,d,e,f,g}
);

    // Counter FSM
    counter_fsm C1 (
        .clk   (clk),
        .reset (reset),
        .run   (run),
        .count (count)
    );

    // Seven-segment decoder
    seven_segment S1 (
        .count (count),
        .seg   (seg)
    );

endmodule`timescale 1ns/1ps

// Self-checking testbench for top_module
// Checks: count increases while run=1, holds while run=0,
//         wraps 1111 -> 0000, resets mid-run, and seg matches count.
// Inputs are driven on the falling clock edge to avoid races.
module tb_top_module;

    reg  clk;
    reg  reset;
    reg  run;
    wire [3:0] count;
    wire [6:0] seg;

    top_module dut (
        .clk   (clk),
        .reset (reset),
        .run   (run),
        .count (count),
        .seg   (seg)
    );

    // ---------------- Clock: 10 ns period ----------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- Reference model ----------------
    // The DUT's state is a registered copy of run, so the model
    // uses run delayed by one clock (run_d) to decide when to count.
    reg [3:0] exp_count;
    reg       run_d;

    always @(posedge clk) begin
        if (reset) begin
            exp_count <= 4'd0;
            run_d     <= 1'b0;
        end else begin
            run_d <= run;
            if (run_d)
                exp_count <= exp_count + 4'd1;
        end
    end

    // Reference 7-segment table, {a,b,c,d,e,f,g}
    function [6:0] seg_ref(input [3:0] v);
        case (v)
            4'h0: seg_ref = 7'b1111110;
            4'h1: seg_ref = 7'b0110000;
            4'h2: seg_ref = 7'b1101101;
            4'h3: seg_ref = 7'b1111001;
            4'h4: seg_ref = 7'b0110011;
            4'h5: seg_ref = 7'b1011011;
            4'h6: seg_ref = 7'b1011111;
            4'h7: seg_ref = 7'b1110000;
            4'h8: seg_ref = 7'b1111111;
            4'h9: seg_ref = 7'b1111011;
            4'hA: seg_ref = 7'b1110111;
            4'hB: seg_ref = 7'b0011111;
            4'hC: seg_ref = 7'b1001110;
            4'hD: seg_ref = 7'b0111101;
            4'hE: seg_ref = 7'b1001111;
            4'hF: seg_ref = 7'b1000111;
        endcase
    endfunction

    // ---------------- Continuous checker (every falling edge) ----------------
    integer errors;
    reg     checking;

    always @(negedge clk) begin
        if (checking) begin
            if (count !== exp_count) begin
                errors = errors + 1;
                $display("ERROR t=%0t: count=%h expected=%h", $time, count, exp_count);
            end
            if (seg !== seg_ref(count)) begin
                errors = errors + 1;
                $display("ERROR t=%0t: seg=%b expected=%b for count=%h",
                         $time, seg, seg_ref(count), count);
            end
        end
    end

    // ---------------- Helpers ----------------
    task tick;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(negedge clk);
        end
    endtask

    task expect_eq;
        input [3:0]   actual;
        input [3:0]   expected;
        input [255:0] label;
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s]: got %h, expected %h (t=%0t)", label, actual, expected, $time);
            end else
                $display("PASS [%0s]: %h", label, actual);
        end
    endtask

    // ---------------- Test sequence ----------------
    reg [3:0] saved;
    integer   guard;

    initial begin
        $dumpfile("counter.vcd");
        $dumpvars(1, dut);

        errors   = 0;
        checking = 0;
        reset    = 1;
        run      = 0;

        // 1) Synchronous reset
        tick(2);
        checking = 1;
        expect_eq(count, 4'd0, "after reset");
        reset = 0;

        // 2) HOLD with run = 0: count must stay at 0
        tick(3);
        expect_eq(count, 4'd0, "hold at 0 while run=0");

        // 3) Count increases while run = 1
        //    (state registers run first, so counting starts one clock later)
        run = 1;
        tick(2);
        saved = count;
        tick(3);
        expect_eq(count, saved + 4'd3, "increments by 1 per clock");

        // 4) HOLD: count must not change while run = 0
        run = 0;
        tick(2);                 // let the state settle into HOLD
        saved = count;
        tick(5);
        expect_eq(count, saved, "holds while run=0");

        // 5) Wrap 1111 -> 0000
        run   = 1;
        guard = 0;
        while (count !== 4'hF && guard < 40) begin
            tick(1);
            guard = guard + 1;
        end
        expect_eq(count, 4'hF, "reached F");
        tick(1);
        expect_eq(count, 4'h0, "wrap F -> 0");
        tick(1);
        expect_eq(count, 4'h1, "continues after wrap");

        // 6) Synchronous reset in the middle of a run
        reset = 1;
        tick(1);
        expect_eq(count, 4'h0, "reset while running");
        reset = 0;
        tick(4);

        // 7) Stop
        run = 0;
        tick(3);

        // ---------------- Summary ----------------
        if (errors == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** TESTS FAILED: %0d error(s) ***", errors);

        $finish;
    end

    // Log for the lab report
    initial begin
        $monitor("Time=%0t | Reset=%b | Run=%b | State=%b | Count=%b (%h) | Seg=%b",
                 $time, reset, run, dut.C1.state, count, count, seg);
    end

endmodule



