`timescale 1ns/1ps

// System-level integration testbench for systolic_array_top.
// Tests the full pipeline: matrix_controller + systolic_array.

module tb_systolic_array;

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;   // 100 MHz, period = 10 ns

    reg rst_n;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         start  = 0;
    reg [255:0] a_flat = 0;
    reg [255:0] b_flat = 0;
    wire        busy;
    wire        done;
    wire [511:0] result;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    systolic_array_top dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (start),
        .a_flat (a_flat),
        .b_flat (b_flat),
        .busy   (busy),
        .done   (done),
        .result (result)
    );

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("simulation/waveforms/tb_systolic_array.vcd");
        $dumpvars(0, tb_systolic_array);
    end

    // -------------------------------------------------------------------------
    // Test infrastructure
    // -------------------------------------------------------------------------
    integer test_num = 0;
    integer errors   = 0;
    integer r, c, k;

    // Software reference arrays (signed 32-bit)
    integer A[0:3][0:3];
    integer B[0:3][0:3];
    integer C_exp[0:3][0:3];

    // Pack A and B into flat buses
    task pack_matrices;
        integer pr, pc;
        begin
            for (pr = 0; pr < 4; pr = pr + 1)
                for (pc = 0; pc < 4; pc = pc + 1) begin
                    a_flat[8*(4*pr+pc) +: 8] = A[pr][pc][7:0];
                    b_flat[8*(4*pr+pc) +: 8] = B[pr][pc][7:0];
                end
        end
    endtask

    // Compute software reference C = A*B (signed 8-bit inputs, 32-bit accum)
    task compute_expected;
        integer er, ec, ek, sum;
        begin
            for (er = 0; er < 4; er = er + 1)
                for (ec = 0; ec < 4; ec = ec + 1) begin
                    sum = 0;
                    for (ek = 0; ek < 4; ek = ek + 1)
                        sum = sum + $signed(A[er][ek][7:0]) * $signed(B[ek][ec][7:0]);
                    C_exp[er][ec] = sum;
                end
        end
    endtask

    // Issue a start pulse (apply at negedge, sample at posedge)
    task issue_start;
        begin
            @(negedge clk);
            start = 1;
            @(posedge clk);
            @(negedge clk);
            start = 0;
        end
    endtask

    // Wait for done pulse (timeout guard = 200 cycles)
    integer wait_cyc;
    task wait_done;
        begin
            wait_cyc = 0;
            @(posedge clk);        // consume the posedge that latched start
            while (!done && wait_cyc < 200) begin
                @(posedge clk);
                wait_cyc = wait_cyc + 1;
            end
            if (!done) begin
                $display("ERROR test %0d: timeout waiting for done", test_num);
                errors = errors + 1;
            end
        end
    endtask

    // Check result against C_exp; read result at negedge after done posedge
    task check_result;
        integer cr, cc, got, exp_val;
        begin
            @(negedge clk);
            for (cr = 0; cr < 4; cr = cr + 1)
                for (cc = 0; cc < 4; cc = cc + 1) begin
                    got     = $signed(result[32*(4*cr+cc) +: 32]);
                    exp_val = C_exp[cr][cc];
                    if (got !== exp_val) begin
                        $display("FAIL test %0d C[%0d][%0d]: expected %0d, got %0d",
                                 test_num, cr, cc, exp_val, got);
                        errors = errors + 1;
                    end
                end
        end
    endtask

    // Full run: pack -> start -> wait done -> check
    task run_test;
        begin
            pack_matrices;
            compute_expected;
            issue_start;
            wait_done;
            check_result;
            if (errors == 0)
                $display("PASS test %0d", test_num);
            test_num = test_num + 1;
        end
    endtask

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #500000;
        $fatal(1, "Global timeout — testbench hung");
    end

    // -------------------------------------------------------------------------
    // Reset sequence
    // -------------------------------------------------------------------------
    initial begin
        rst_n = 0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // Tests added in subsequent commits
        run_all_tests;

        if (errors == 0)
            $display("ALL TESTS PASSED (%0d tests)", test_num);
        else
            $display("FAILED: %0d error(s) across %0d tests", errors, test_num);
        $finish;
    end

    task run_all_tests;
        begin
            // Placeholder — test tasks added in commits 8-11
        end
    endtask

endmodule
