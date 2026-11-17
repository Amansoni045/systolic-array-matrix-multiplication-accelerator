`timescale 1ns/1ps

module tb_sequential_baseline;

    parameter ARRAY_SIZE = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;

    reg clk;
    reg rst_n;
    reg start;

    reg signed [ARRAY_SIZE * ARRAY_SIZE * DATA_WIDTH - 1 : 0] a_flat;
    reg signed [ARRAY_SIZE * ARRAY_SIZE * DATA_WIDTH - 1 : 0] b_flat;

    wire busy;
    wire done;
    wire signed [ARRAY_SIZE * ARRAY_SIZE * ACC_WIDTH - 1 : 0] result;

    sequential_matmul_baseline #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a_flat(a_flat),
        .b_flat(b_flat),
        .busy(busy),
        .done(done),
        .result(result)
    );

    always #5 clk = ~clk;

    reg signed [DATA_WIDTH-1:0] mat_a [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    reg signed [DATA_WIDTH-1:0] mat_b [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];
    reg signed [ACC_WIDTH-1:0] exp_c [0:ARRAY_SIZE-1][0:ARRAY_SIZE-1];

    reg signed [ARRAY_SIZE * ARRAY_SIZE * ACC_WIDTH - 1 : 0] saved_result;
    reg signed [DATA_WIDTH-1:0] min_val;
    reg signed [DATA_WIDTH-1:0] max_val;

    integer cycle_count;
    integer latency_ns;
    integer mac_count;
    integer r, c, k;

    task pack_inputs;
        integer pr, pc;
        begin
            for (pr = 0; pr < ARRAY_SIZE; pr = pr + 1) begin
                for (pc = 0; pc < ARRAY_SIZE; pc = pc + 1) begin
                    a_flat[(pr * ARRAY_SIZE + pc) * DATA_WIDTH +: DATA_WIDTH] = mat_a[pr][pc];
                    b_flat[(pr * ARRAY_SIZE + pc) * DATA_WIDTH +: DATA_WIDTH] = mat_b[pr][pc];
                end
            end
        end
    endtask

    task compute_expected;
        integer er, ec, ek;
        reg signed [ACC_WIDTH-1:0] sum;
        begin
            for (er = 0; er < ARRAY_SIZE; er = er + 1) begin
                for (ec = 0; ec < ARRAY_SIZE; ec = ec + 1) begin
                    sum = {ACC_WIDTH{1'b0}};
                    for (ek = 0; ek < ARRAY_SIZE; ek = ek + 1) begin
                        sum = sum + $signed(mat_a[er][ek]) * $signed(mat_b[ek][ec]);
                    end
                    exp_c[er][ec] = sum;
                end
            end
        end
    endtask

    task run_matmul;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            cycle_count = 0;

            while (!done) begin
                @(negedge clk);
                cycle_count = cycle_count + 1;
            end
            latency_ns = cycle_count * 10;
            mac_count = ARRAY_SIZE * ARRAY_SIZE * ARRAY_SIZE;

            $display("Execution metrics: Clock cycles = %0d, Latency = %0d ns, Total MAC ops = %0d",
                     cycle_count, latency_ns, mac_count);
        end
    endtask

    task verify_result;
        input [511:0] test_name;
        integer vr, vc;
        reg signed [ACC_WIDTH-1:0] act_val;
        begin
            for (vr = 0; vr < ARRAY_SIZE; vr = vr + 1) begin
                for (vc = 0; vc < ARRAY_SIZE; vc = vc + 1) begin
                    act_val = result[(vr * ARRAY_SIZE + vc) * ACC_WIDTH +: ACC_WIDTH];
                    if (act_val !== exp_c[vr][vc]) begin
                        $fatal(1, "MISMATCH in %0s at [%0d][%0d]: expected %0d, got %0d",
                               test_name, vr, vc, exp_c[vr][vc], act_val);
                    end
                end
            end
            $display("PASS: %0s", test_name);
        end
    endtask

    initial begin
        if (ARRAY_SIZE == 2)
            $dumpfile("phase2/simulation/waveforms/seq_baseline_2x2.vcd");
        else if (ARRAY_SIZE == 4)
            $dumpfile("phase2/simulation/waveforms/seq_baseline_4x4.vcd");
        else
            $dumpfile("phase2/simulation/waveforms/seq_baseline_8x8.vcd");
        $dumpvars(0, tb_sequential_baseline);

        clk = 0;
        rst_n = 0;
        start = 0;
        a_flat = 0;
        b_flat = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = r * ARRAY_SIZE + c + 1;
                mat_b[r][c] = (r == c) ? 1 : 0;
            end
        end
        compute_expected();
        pack_inputs();
        run_matmul();
        verify_result("Identity matrix test");

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = r + c + 2;
                mat_b[r][c] = 0;
            end
        end
        compute_expected();
        pack_inputs();
        run_matmul();
        verify_result("Zero matrix test");

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = ((r + c) % 2 == 0) ? (r - c + 2) : (c - r - 3);
                mat_b[r][c] = ((r * c) % 2 == 0) ? (c + 1) : (-r - 2);
            end
        end
        compute_expected();
        pack_inputs();
        run_matmul();
        verify_result("Positive and negative values test");

        min_val = - (1 <<< (DATA_WIDTH - 1));
        max_val = (1 <<< (DATA_WIDTH - 1)) - 1;
        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = ((r + c) % 4 == 0) ? min_val :
                              ((r + c) % 4 == 1) ? max_val :
                              ((r + c) % 4 == 2) ? -1 : 1;
                mat_b[r][c] = ((r * 2 + c) % 4 == 0) ? max_val :
                              ((r * 2 + c) % 4 == 1) ? min_val :
                              ((r * 2 + c) % 4 == 2) ? 1 : -1;
            end
        end
        compute_expected();
        pack_inputs();
        run_matmul();
        verify_result("Boundary values test");

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = r + 1;
                mat_b[r][c] = c + 1;
            end
        end
        compute_expected();
        pack_inputs();

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        a_flat = ~a_flat;
        b_flat = ~b_flat;

        while (!done) begin
            @(negedge clk);
        end
        verify_result("Input latching test");

        saved_result = result;
        repeat (10) begin
            @(negedge clk);
            if (result !== saved_result)
                $fatal(1, "Output stability test failed: result changed during idle!");
        end
        $display("PASS: Output stability test");

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = r + 1;
                mat_b[r][c] = c + 1;
            end
        end
        compute_expected();
        pack_inputs();

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        while (!done) begin
            @(negedge clk);
        end
        verify_result("Back-to-back operation 1");

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = r + 3;
                mat_b[r][c] = c + 2;
            end
        end
        compute_expected();
        pack_inputs();

        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        while (!done) begin
            @(negedge clk);
        end
        verify_result("Back-to-back operation 2");
        $display("PASS: Back-to-back matrix operations");

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        repeat (3) @(negedge clk);
        if (!busy)
            $fatal(1, "Reset test failed: DUT should be busy!");

        #2 rst_n = 1'b0;
        #1;
        if (busy !== 1'b0 || done !== 1'b0 || result !== 0)
            $fatal(1, "Reset test failed: registers not cleared!");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin
            for (c = 0; c < ARRAY_SIZE; c = c + 1) begin
                mat_a[r][c] = r + 2;
                mat_b[r][c] = (r == c) ? 1 : 0;
            end
        end
        compute_expected();
        pack_inputs();
        run_matmul();
        verify_result("Post-reset operation test");
        $display("PASS: Reset behaviour test");

        @(negedge clk);
        $display("========================================");
        $display("ALL BASELINE TESTS PASSED SUCCESSFULLY (ARRAY_SIZE=%0d, DATA_WIDTH=%0d, ACC_WIDTH=%0d)",
                 ARRAY_SIZE, DATA_WIDTH, ACC_WIDTH);
        $display("========================================");
        $finish;
    end

endmodule
