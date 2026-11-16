`timescale 1ns/1ps

module tb_systolic_array;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n;

    reg         start  = 0;
    reg [255:0] a_flat = 0;
    reg [255:0] b_flat = 0;
    wire        busy;
    wire        done;
    wire [511:0] result;

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

    initial begin
        $dumpfile("simulation/waveforms/tb_systolic_array.vcd");
        $dumpvars(0, tb_systolic_array);
    end

    integer test_num = 0;
    integer errors   = 0;
    integer r, c, k;

    integer A[0:3][0:3];
    integer B[0:3][0:3];
    integer C_exp[0:3][0:3];

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

    task issue_start;
        begin
            @(negedge clk);
            start = 1;
            @(posedge clk);
            @(negedge clk);
            start = 0;
        end
    endtask

    integer wait_cyc;
    task wait_done;
        begin
            wait_cyc = 0;
            @(posedge clk);
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

    integer done_pulse_count;
    task run_test;
        integer ck;
        begin
            pack_matrices;
            compute_expected;
            done_pulse_count = 0;
            issue_start;
            wait_cyc = 0;
            @(posedge clk);
            while (!done && wait_cyc < 200) begin
                @(posedge clk);
                wait_cyc = wait_cyc + 1;
            end
            if (!done) begin
                $display("ERROR test %0d: timeout waiting for done", test_num);
                errors = errors + 1;
            end else begin
                done_pulse_count = done_pulse_count + 1;
                @(posedge clk);
                #1;
                if (done) begin
                    $display("FAIL test %0d: done remained high for >1 cycle", test_num);
                    errors = errors + 1;
                end
            end
            check_result;
            if (errors == 0)
                $display("PASS test %0d", test_num);
            test_num = test_num + 1;
        end
    endtask

    initial begin
        #500000;
        $fatal(1, "Global timeout — testbench hung");
    end

    task test_identity_times_matrix;
        integer ti, tj;
        begin
            for (ti = 0; ti < 4; ti = ti + 1)
                for (tj = 0; tj < 4; tj = tj + 1) begin
                    A[ti][tj] = (ti == tj) ? 1 : 0;
                    B[ti][tj] = 4*ti + tj + 1;
                end
            run_test;
            $display("  identity x M: I*M should equal M");
        end
    endtask

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

    task test_known_positive;
        integer ki, kj;
        begin
            for (ki = 0; ki < 4; ki = ki + 1)
                for (kj = 0; kj < 4; kj = kj + 1) begin
                    A[ki][kj] = 4*ki + kj + 1;
                    B[ki][kj] = 16 - (4*ki + kj);
                end
            run_test;
            $display("  known positive 4x4 multiply");
        end
    endtask

    task test_signed_values;
        integer si, sj;
        begin
            for (si = 0; si < 4; si = si + 1)
                for (sj = 0; sj < 4; sj = sj + 1) begin
                    A[si][sj] = ((si + sj) % 2 == 0) ? -128 : 127;
                    B[si][sj] = ((si + sj) % 2 == 0) ?  127 : -128;
                end
            run_test;
            $display("  signed extreme values (-128/127)");
        end
    endtask

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

    task test_back_to_back;
        integer bi, bj;
        begin
            for (bi = 0; bi < 4; bi = bi + 1)
                for (bj = 0; bj < 4; bj = bj + 1) begin
                    A[bi][bj] = bi + bj + 1;
                    B[bi][bj] = bi - bj;
                end
            run_test;
            $display("  back-to-back op 1");

            for (bi = 0; bi < 4; bi = bi + 1)
                for (bj = 0; bj < 4; bj = bj + 1) begin
                    A[bi][bj] = -1 * (bi + 1);
                    B[bi][bj] = bj + 2;
                end
            run_test;
            $display("  back-to-back op 2");
        end
    endtask

    task test_reset_during_operation;
        integer ri2, rj2, n;
        begin
            for (ri2 = 0; ri2 < 4; ri2 = ri2 + 1)
                for (rj2 = 0; rj2 < 4; rj2 = rj2 + 1) begin
                    A[ri2][rj2] = ri2 + 1;
                    B[ri2][rj2] = rj2 + 1;
                end
            pack_matrices;

            @(negedge clk); start = 1;
            @(posedge clk); @(negedge clk); start = 0;

            repeat(4) @(posedge clk);
            @(negedge clk); rst_n = 0;
            @(posedge clk);

            #1;
            if (busy !== 0 || done !== 0) begin
                $display("FAIL test %0d: busy=%b done=%b should be 0 during reset",
                         test_num, busy, done);
                errors = errors + 1;
            end

            @(negedge clk); rst_n = 1;
            repeat(2) @(posedge clk);

            compute_expected;
            issue_start;
            wait_done;
            check_result;

            if (errors == 0)
                $display("PASS test %0d (reset-during-operation)", test_num);
            test_num = test_num + 1;
        end
    endtask

    task test_result_stability;
        integer si2, sj2, n;
        reg [511:0] captured;
        integer got, exp_val;
        begin
            for (si2 = 0; si2 < 4; si2 = si2 + 1)
                for (sj2 = 0; sj2 < 4; sj2 = sj2 + 1) begin
                    A[si2][sj2] = si2 + 1;
                    B[si2][sj2] = (si2 == sj2) ? 1 : 0;
                end
            compute_expected;
            pack_matrices;
            issue_start;
            wait_done;

            @(negedge clk);
            captured = result;

            repeat(10) @(posedge clk);
            #1;
            if (result !== captured) begin
                $display("FAIL test %0d: result changed after done without new start", test_num);
                errors = errors + 1;
            end else begin
                for (si2 = 0; si2 < 4; si2 = si2 + 1)
                    for (sj2 = 0; sj2 < 4; sj2 = sj2 + 1) begin
                        got     = $signed(result[32*(4*si2+sj2) +: 32]);
                        exp_val = C_exp[si2][sj2];
                        if (got !== exp_val) begin
                            $display("FAIL test %0d stability C[%0d][%0d]: exp %0d got %0d",
                                     test_num, si2, sj2, exp_val, got);
                            errors = errors + 1;
                        end
                    end
            end

            if (errors == 0)
                $display("PASS test %0d (result stability)", test_num);
            test_num = test_num + 1;
        end
    endtask

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
            test_identity_times_matrix;
            test_zero_matrices;
            test_known_positive;
            test_signed_values;
            test_mixed_signs;
            test_back_to_back;
            test_reset_during_operation;
            test_result_stability;
        end
    endtask

endmodule
