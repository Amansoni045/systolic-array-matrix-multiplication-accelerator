`timescale 1ns/1ps

// Member 2 unit test: does not depend on Member 3's controller/top-level.
module tb_systolic_array_core;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg clear_acc = 0;
    reg [31:0] a_in = 0, b_in = 0;
    reg [3:0] a_valid_in = 0, b_valid_in = 0;
    wire [511:0] acc_out;
    systolic_array dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a_in), .b_in(b_in),
        .a_valid_in(a_valid_in), .b_valid_in(b_valid_in),
        .acc_out(acc_out)
    );

    integer matrix_a [0:15], matrix_b [0:15];
    integer expected [0:15];
    integer history_a [0:255][0:3], history_b [0:255][0:3];
    reg [3:0] history_av [0:255], history_bv [0:255];
    integer cycle = 0, checked_edges = 0;
    integer test_id, i, k, bubble;
    integer seed = 32'h4d434134;

    // Independent timing oracle: external slot s reaches PE(r,c) at s+r+c.
    // Check every accumulator on every edge, including partially filled arrays.
    task tick;
        integer r, c, slot, index;
        begin
            for (r = 0; r < 4; r = r + 1) begin
                history_a[cycle][r] = $signed(a_in[8*r +: 8]);
                history_b[cycle][r] = $signed(b_in[8*r +: 8]);
            end
            history_av[cycle] = a_valid_in;
            history_bv[cycle] = b_valid_in;
            @(posedge clk);
            if (!rst_n || clear_acc) begin
                for (index = 0; index < 16; index = index + 1)
                    expected[index] = 0;
                cycle = 0;
            end else begin
                for (r = 0; r < 4; r = r + 1)
                    for (c = 0; c < 4; c = c + 1) begin
                        slot = cycle-r-c;
                        if (slot >= 0)
                            if (history_av[slot][r] && history_bv[slot][c])
                                expected[4*r+c] = expected[4*r+c] +
                                    history_a[slot][r]*history_b[slot][c];
                    end
                cycle = cycle + 1;
            end
            #1;
            for (index = 0; index < 16; index = index + 1)
                if ($signed(acc_out[32*index +: 32]) !== expected[index])
                    $fatal(1, "cycle=%0d C[%0d][%0d]: expected %0d, got %0d",
                        cycle, index/4, index%4, expected[index],
                        $signed(acc_out[32*index +: 32]));
            checked_edges = checked_edges + 1;
            @(negedge clk);
        end
    endtask

    task clear_array;
        begin
            clear_acc = 1;
            tick;
            clear_acc = 0;
            a_valid_in = 0;
            b_valid_in = 0;
        end
    endtask

    task drain;
        integer n;
        begin
            a_valid_in = 0;
            b_valid_in = 0;
            // Six edges reach C[3][3]; two extra verify results hold.
            for (n = 0; n < 8; n = n + 1) tick;
        end
    endtask

    task check_matrix;
        integer r, c, term, total;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    total = 0;
                    for (term = 0; term < 4; term = term + 1)
                        total = total + matrix_a[4*r+term]*matrix_b[4*term+c];
                    if ($signed(acc_out[32*(4*r+c) +: 32]) !== total)
                        $fatal(1, "Matrix %0d C[%0d][%0d] mismatch", test_id, r, c);
                end
        end
    endtask

    initial begin
        tick;
        rst_n = 1;
        // Zero, identity, positive, mixed signs, signed extremes, random.
        for (test_id = 0; test_id < 105; test_id = test_id + 1) begin
            clear_array;
            for (i = 0; i < 16; i = i + 1) begin
                case (test_id)
                    0: begin matrix_a[i] = 0; matrix_b[i] = i-8; end
                    1: begin matrix_a[i] = (i/4 == i%4); matrix_b[i] = i-8; end
                    2: begin matrix_a[i] = i+1; matrix_b[i] = 16-i; end
                    3: begin matrix_a[i] = i-8; matrix_b[i] = 7-i; end
                    4: begin
                        matrix_a[i] = (i%2 == 0) ? -128 : 127;
                        matrix_b[i] = (i%3 == 0) ? 127 : -128;
                    end
                    default: begin
                        matrix_a[i] = $random(seed) & 255;
                        matrix_b[i] = $random(seed) & 255;
                        if (matrix_a[i] >= 128) matrix_a[i] = matrix_a[i]-256;
                        if (matrix_b[i] >= 128) matrix_b[i] = matrix_b[i]-256;
                    end
                endcase
            end
            for (k = 0; k < 4; k = k + 1) begin
                // Common bubbles preserve operand k alignment across all lanes.
                bubble = (test_id >= 5) && (($random(seed) & 3) == 0);
                if (bubble) begin
                    a_valid_in = 0; b_valid_in = 0;
                    tick;
                end
                for (i = 0; i < 4; i = i + 1) begin
                    a_in[8*i +: 8] = matrix_a[4*i+k];
                    b_in[8*i +: 8] = matrix_b[4*k+i];
                end
                a_valid_in = 4'b1111; b_valid_in = 4'b1111;
                tick;
            end
            drain;
            check_matrix;
        end

        // Independent validity patterns exercise every neighbour valid path.
        clear_array;
        for (i = 0; i < 40; i = i + 1) begin
            a_in = $random(seed); b_in = $random(seed);
            a_valid_in = $random(seed); b_valid_in = $random(seed);
            tick;
        end
        // Clear while operands are in flight, with all external lanes valid.
        a_valid_in = 15; b_valid_in = 15;
        clear_array;
        drain;
        // Asynchronous reset between edges must cancel a populated pipeline.
        a_valid_in = 15; b_valid_in = 15;
        tick;
        rst_n = 0;
        #1;
        if (acc_out !== 512'b0) $fatal(1, "Asynchronous reset failed");
        tick;
        rst_n = 1;
        drain;
        // Restart immediately following a mid-stream clear.
        a_valid_in = 15; b_valid_in = 15;
        tick;
        clear_array;
        a_in = 32'h01010101; b_in = 32'h02020202;
        a_valid_in = 15; b_valid_in = 15;
        tick;
        drain;
        for (i = 0; i < 16; i = i + 1)
            if ($signed(acc_out[32*i +: 32]) !== 2)
                $fatal(1, "Restart failed at output %0d", i);
        $display("PASS: 105 matrices, valid masks, bubbles, clear/reset/restart; %0d edges checked", checked_edges);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Timeout");
    end
endmodule
