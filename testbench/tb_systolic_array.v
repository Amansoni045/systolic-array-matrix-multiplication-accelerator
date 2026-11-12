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
    // Test case 0: Identity × M = M
    // -------------------------------------------------------------------------
    task test_identity_times_matrix;
        integer ti, tj;
        begin
            // A = 4x4 identity; B = sequential 1..16
            for (ti = 0; ti < 4; ti = ti + 1)
                for (tj = 0; tj < 4; tj = tj + 1) begin
                    A[ti][tj] = (ti == tj) ? 1 : 0;
                    B[ti][tj] = 4*ti + tj + 1;
                end
            run_test;
            $display("  identity x M: I*M should equal M");
        end
    endtask

    // -------------------------------------------------------------------------
    // Test case 1: All-zeros matrices
    // -------------------------------------------------------------------------
    task test_zero_matrices;
        integer zi, zj;
        begin
            for (zi = 0; zi < 4; zi = zi + 1)
                for (zj = 0; zj < 4; zj = zj + 1) begin
                    A[zi][zj] = 0;
                    B[zi][zj] = 0;
                end
            run_test;
            $display("  zero x zero: all outputs should be 0");
        end
    endtask

    // -------------------------------------------------------------------------
    // Test case 2: Known 4×4 multiply with specific positive values
    // -------------------------------------------------------------------------
    task test_known_positive;
        integer ki, kj;
        begin
            // A = [[1,2,3,4],[5,6,7,8],[9,10,11,12],[13,14,15,16]]
            // B = [[16,15,14,13],[12,11,10,9],[8,7,6,5],[4,3,2,1]]
            for (ki = 0; ki < 4; ki = ki + 1)
                for (kj = 0; kj < 4; kj = kj + 1) begin
                    A[ki][kj] = 4*ki + kj + 1;      //  1..16
                    B[ki][kj] = 16 - (4*ki + kj);   // 16..1
                end
            run_test;
            $display("  known positive 4x4 multiply");
        end
    endtask

    // -------------------------------------------------------------------------
    // Test case 3: Signed (negative) values
    // -------------------------------------------------------------------------
    task test_signed_values;
        integer si, sj;
        begin
            // Mix of -128..127 boundary values
            for (si = 0; si < 4; si = si + 1)
                for (sj = 0; sj < 4; sj = sj + 1) begin
                    A[si][sj] = ((si + sj) % 2 == 0) ? -128 : 127;
                    B[si][sj] = ((si + sj) % 2 == 0) ?  127 : -128;
                end
            run_test;
            $display("  signed extreme values (-128/127)");
        end
    endtask

    // -------------------------------------------------------------------------
    // Test case 4: Mixed positive and negative values
    // -------------------------------------------------------------------------
    task test_mixed_signs;
        integer mi, mj;
        begin
            for (mi = 0; mi < 4; mi = mi + 1)
                for (mj = 0; mj < 4; mj = mj + 1) begin
                    A[mi][mj] = (mi % 2 == 0) ? (mi*4 + mj + 1) : -(mi*4 + mj + 1);
                    B[mi][mj] = (mj % 2 == 0) ? (mi*4 + mj + 1) : -(mi*4 + mj + 1);
                end
            run_test;
            $display("  mixed positive/negative values");
        end
    endtask

    // -------------------------------------------------------------------------
    // Test case 5: Back-to-back operations
    // -------------------------------------------------------------------------
    task test_back_to_back;
        integer bi, bj;
        integer done_count;
        begin
            // First multiplication
            for (bi = 0; bi < 4; bi = bi + 1)
                for (bj = 0; bj < 4; bj = bj + 1) begin
                    A[bi][bj] = bi + bj + 1;
                    B[bi][bj] = bi - bj;
                end
            run_test;
            $display("  back-to-back op 1");

            // Second multiplication immediately after (no extra idle cycles)
            for (bi = 0; bi < 4; bi = bi + 1)
                for (bj = 0; bj < 4; bj = bj + 1) begin
                    A[bi][bj] = -1 * (bi + 1);
                    B[bi][bj] = bj + 2;
                end
            run_test;
            $display("  back-to-back op 2");
        end
    endtask

    // -------------------------------------------------------------------------
    // Reset sequence and main test driver
    // -------------------------------------------------------------------------
    initial begin
        rst_n = 0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        run_all_tests;

        if (errors == 0)
            $display("ALL TESTS PASSED (%0d tests)", test_num);
        else
            $display("FAILED: %0d error(s) across %0d tests", errors, test_num);
        $finish;
    end

    task run_all_tests;
        begin
            test_identity_times_matrix;   // test 0
            test_zero_matrices;           // test 1
            test_known_positive;          // test 2
            test_signed_values;           // test 3
            test_mixed_signs;             // test 4
            test_back_to_back;            // tests 5 & 6
            // Reset-during-operation and stability tests added in next commit
        end
    endtask

endmodule
