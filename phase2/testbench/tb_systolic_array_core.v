`timescale 1ns/1ps

// Array-only verification; no controller, top-level or baseline is required.
module tb_systolic_array_core;
    parameter ARRAY_SIZE = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter RANDOM_CASES = 100;
    localparam ELEMENTS = ARRAY_SIZE*ARRAY_SIZE;
    localparam DRAIN_EDGES = 2*(ARRAY_SIZE-1);
    localparam CORE_EDGES = 3*ARRAY_SIZE-2;
    localparam HISTORY_SIZE = 16*ARRAY_SIZE+128;

    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, clear_acc = 0;
    reg [ARRAY_SIZE*DATA_WIDTH-1:0] a_in = 0, b_in = 0;
    reg [ARRAY_SIZE-1:0] a_valid_in = 0, b_valid_in = 0;
    wire [ELEMENTS*ACC_WIDTH-1:0] acc_out;
    systolic_array #(
        .ARRAY_SIZE(ARRAY_SIZE), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_in(a_in), .b_in(b_in),
        .a_valid_in(a_valid_in), .b_valid_in(b_valid_in), .acc_out(acc_out)
    );

    reg signed [DATA_WIDTH-1:0] mat_a [0:ELEMENTS-1], mat_b [0:ELEMENTS-1];
    reg signed [DATA_WIDTH-1:0] history_a [0:HISTORY_SIZE-1][0:ARRAY_SIZE-1];
    reg signed [DATA_WIDTH-1:0] history_b [0:HISTORY_SIZE-1][0:ARRAY_SIZE-1];
    reg [ARRAY_SIZE-1:0] history_av [0:HISTORY_SIZE-1], history_bv [0:HISTORY_SIZE-1];
    reg signed [ACC_WIDTH-1:0] expected [0:ELEMENTS-1];
    reg signed [DATA_WIDTH-1:0] min_val, max_val;
    integer cycle = 0, checked_edges = 0, matrices_checked = 0;
    integer test_id, i, n;
    integer seed = 32'h4d434132;
    integer plain_edges = -1, bubble_edges = -1;
    integer last_result_change = -1;
    reg signed [ACC_WIDTH-1:0] previous_last_result = 0;
    integer report_file;
    string report_path, wave_path;

    // External slot s is consumed at PE(r,c) on edge s+r+c.
    // This oracle uses only the input history, never the DUT interconnect.
    task tick;
        integer r, c, slot, index;
        reg signed [2*DATA_WIDTH-1:0] product;
        reg signed [ACC_WIDTH-1:0] extended_product;
        begin
            if (cycle >= HISTORY_SIZE) $fatal(1, "Scoreboard history exhausted");
            for (r = 0; r < ARRAY_SIZE; r = r+1) begin
                history_a[cycle][r] = a_in[DATA_WIDTH*r +: DATA_WIDTH];
                history_b[cycle][r] = b_in[DATA_WIDTH*r +: DATA_WIDTH];
            end
            history_av[cycle] = a_valid_in;
            history_bv[cycle] = b_valid_in;
            @(posedge clk);
            if (!rst_n || clear_acc) begin
                for (index = 0; index < ELEMENTS; index = index+1) expected[index] = 0;
                cycle = 0;
            end else begin
                for (r = 0; r < ARRAY_SIZE; r = r+1)
                    for (c = 0; c < ARRAY_SIZE; c = c+1) begin
                        slot = cycle-r-c;
                        if (slot >= 0) begin
                            if (history_av[slot][r] && history_bv[slot][c]) begin
                                product = history_a[slot][r]*history_b[slot][c];
                                extended_product = product; // signed extension
                                expected[ARRAY_SIZE*r+c] = expected[ARRAY_SIZE*r+c]+extended_product;
                            end
                        end
                    end
                cycle = cycle+1;
            end
            #1;
            if (!rst_n || clear_acc) begin
                last_result_change = -1;
                previous_last_result = 0;
            end else if ($signed(acc_out[(ELEMENTS-1)*ACC_WIDTH +: ACC_WIDTH]) !== previous_last_result) begin
                last_result_change = cycle-1;
                previous_last_result = acc_out[(ELEMENTS-1)*ACC_WIDTH +: ACC_WIDTH];
            end
            for (index = 0; index < ELEMENTS; index = index+1)
                if ($signed(acc_out[ACC_WIDTH*index +: ACC_WIDTH]) !== expected[index])
                    $fatal(1, "N=%0d D=%0d W=%0d edge=%0d C[%0d][%0d]: expected %0d got %0d",
                        ARRAY_SIZE, DATA_WIDTH, ACC_WIDTH, cycle-1, index/ARRAY_SIZE,
                        index%ARRAY_SIZE, expected[index],
                        $signed(acc_out[ACC_WIDTH*index +: ACC_WIDTH]));
            checked_edges = checked_edges+1;
            @(negedge clk);
        end
    endtask

    // Check forwarding as well as sums: invalid masks must travel independently,
    // including traffic where only one operand is valid and no MAC takes place.
    genvar gr, gc;
    generate
        for (gr = 0; gr < ARRAY_SIZE; gr = gr+1) begin : monitor_rows
            for (gc = 0; gc < ARRAY_SIZE; gc = gc+1) begin : monitor_cols
                integer source_slot;
                reg expected_av, expected_bv;
                always @(posedge clk) begin
                    #2; // after tick's scoreboard and DUT nonblocking updates
                    source_slot = cycle-1-gr-gc;
                    expected_av = 0;
                    expected_bv = 0;
                    if (rst_n && !clear_acc && source_slot >= 0) begin
                        expected_av = history_av[source_slot][gr];
                        expected_bv = history_bv[source_slot][gc];
                    end
                    if (dut.rows[gr].cols[gc].pe.a_valid_out !== expected_av ||
                        dut.rows[gr].cols[gc].pe.b_valid_out !== expected_bv)
                        $fatal(1, "Forwarded valid mismatch at PE(%0d,%0d), edge %0d", gr, gc, cycle-1);
                    if (expected_av)
                        if (dut.rows[gr].cols[gc].pe.a_out !== history_a[source_slot][gr])
                            $fatal(1, "Forwarded A mismatch at PE(%0d,%0d)", gr, gc);
                    if (expected_bv)
                        if (dut.rows[gr].cols[gc].pe.b_out !== history_b[source_slot][gc])
                            $fatal(1, "Forwarded B mismatch at PE(%0d,%0d)", gr, gc);
                end
                always @(negedge rst_n) begin
                    #1;
                    if (dut.rows[gr].cols[gc].pe.a_out !== 0 ||
                        dut.rows[gr].cols[gc].pe.b_out !== 0 ||
                        dut.rows[gr].cols[gc].pe.a_valid_out !== 0 ||
                        dut.rows[gr].cols[gc].pe.b_valid_out !== 0)
                        $fatal(1, "Asynchronous forwarding reset failed at PE(%0d,%0d)", gr, gc);
                end
            end
        end
    endgenerate

    task idle_edges;
        input integer count;
        integer edge_index;
        begin
            a_valid_in = 0; b_valid_in = 0;
            for (edge_index = 0; edge_index < count; edge_index = edge_index+1) begin
                // Invalid data is deliberately nonzero and changing.
                a_in = ~a_in; b_in = ~b_in;
                tick;
            end
        end
    endtask

    task clear_array;
        begin
            clear_acc = 1;
            tick;
            clear_acc = 0;
            a_valid_in = 0; b_valid_in = 0;
        end
    endtask

    task check_matrix;
        integer r, c, k;
        reg signed [2*DATA_WIDTH-1:0] product;
        reg signed [ACC_WIDTH-1:0] total, extended_product;
        begin
            for (r = 0; r < ARRAY_SIZE; r = r+1)
                for (c = 0; c < ARRAY_SIZE; c = c+1) begin
                    total = 0;
                    for (k = 0; k < ARRAY_SIZE; k = k+1) begin
                        product = mat_a[r*ARRAY_SIZE+k]*mat_b[k*ARRAY_SIZE+c];
                        extended_product = product;
                        total = total+extended_product; // modulo 2**ACC_WIDTH
                    end
                    if ($signed(acc_out[(r*ARRAY_SIZE+c)*ACC_WIDTH +: ACC_WIDTH]) !== total)
                        $fatal(1, "Matrix case %0d mismatch at (%0d,%0d)", test_id, r, c);
                end
            matrices_checked = matrices_checked+1;
        end
    endtask

    task stream_matrix;
        input integer with_bubbles;
        integer r, k, bubbles;
        begin
            // Caller clears first; this allows a new first term immediately
            // after the clear edge, with no extra warmup or reset cycle.
            bubbles = 0;
            for (k = 0; k < ARRAY_SIZE; k = k+1) begin
                if (with_bubbles && (k%2 == 0)) begin
                    idle_edges(2);
                    bubbles = bubbles+2;
                end
                for (r = 0; r < ARRAY_SIZE; r = r+1) begin
                    a_in[DATA_WIDTH*r +: DATA_WIDTH] = mat_a[r*ARRAY_SIZE+k];
                    b_in[DATA_WIDTH*r +: DATA_WIDTH] = mat_b[k*ARRAY_SIZE+r];
                end
                a_valid_in = {ARRAY_SIZE{1'b1}};
                b_valid_in = {ARRAY_SIZE{1'b1}};
                tick;
            end
            idle_edges(DRAIN_EDGES);
            if (cycle !== CORE_EDGES+bubbles)
                $fatal(1, "Core latency expected %0d sampling edges, got %0d", CORE_EDGES+bubbles, cycle);
            check_matrix;
            // All-ones products change the final PE on every contributing MAC,
            // so its last transition measures the actual final arrival edge.
            if (test_id == 7 && last_result_change !== CORE_EDGES-1)
                $fatal(1, "Final PE completed on edge %0d, expected %0d",
                    last_result_change, CORE_EDGES-1);
            if (with_bubbles) bubble_edges = cycle;
            else plain_edges = cycle;
            idle_edges(3); // final output retention; no extra valid operands
        end
    endtask

    initial begin
        if (ARRAY_SIZE < 1 || DATA_WIDTH < 2 || ACC_WIDTH < 2*DATA_WIDTH || RANDOM_CASES < 0)
            $fatal(1, "Unsupported testbench parameters");
        if ($value$plusargs("VCD=%s", wave_path)) begin
            $dumpfile(wave_path);
            $dumpvars(0, tb_systolic_array_core);
        end
        min_val = {1'b1, {(DATA_WIDTH-1){1'b0}}};
        max_val = {1'b0, {(DATA_WIDTH-1){1'b1}}};
        tick;
        rst_n = 1;
        // Directed matrix cases followed by deterministic full-width random data.
        for (test_id = 0; test_id < 8+RANDOM_CASES; test_id = test_id+1) begin
            clear_array;
            for (i = 0; i < ELEMENTS; i = i+1) begin
                case (test_id)
                    0: begin mat_a[i] = i+1; mat_b[i] = (i/ARRAY_SIZE == i%ARRAY_SIZE); end
                    1: begin mat_a[i] = i-ARRAY_SIZE; mat_b[i] = 0; end
                    2: begin mat_a[i] = i+1; mat_b[i] = ELEMENTS-i; end
                    3: begin mat_a[i] = i-ARRAY_SIZE; mat_b[i] = ARRAY_SIZE-i; end
                    4: begin mat_a[i] = min_val; mat_b[i] = min_val; end
                    5: begin mat_a[i] = min_val; mat_b[i] = max_val; end
                    6: begin
                        mat_a[i] = (i%2 == 0) ? max_val : min_val;
                        mat_b[i] = (i%3 == 0) ? min_val : max_val;
                    end
                    7: begin mat_a[i] = 1; mat_b[i] = 1; end
                    default: begin mat_a[i] = $random(seed); mat_b[i] = $random(seed); end
                endcase
            end
            // Explicit no-bubble all-ones case verifies the last MAC's arrival.
            stream_matrix(test_id >= 8 && test_id%2 == 0);
        end
        $display("PASS: %0d matrices incl. boundaries, overflow wrapping and bubbles", matrices_checked);

        // A-only and B-only traffic must forward without changing any sum.
        clear_array;
        a_in = {ARRAY_SIZE{max_val}}; b_in = {ARRAY_SIZE{min_val}};
        a_valid_in = {ARRAY_SIZE{1'b1}}; b_valid_in = 0;
        for (n = 0; n < CORE_EDGES; n = n+1) tick;
        idle_edges(DRAIN_EDGES);
        a_valid_in = 0; b_valid_in = {ARRAY_SIZE{1'b1}};
        for (n = 0; n < CORE_EDGES; n = n+1) tick;
        idle_edges(DRAIN_EDGES);
        if (acc_out !== 0) $fatal(1, "One-sided validity caused accumulation");
        clear_array;
        for (n = 0; n < 4*ARRAY_SIZE+7; n = n+1) begin
            for (i = 0; i < ARRAY_SIZE; i = i+1) begin
                a_in[DATA_WIDTH*i +: DATA_WIDTH] = $random(seed);
                b_in[DATA_WIDTH*i +: DATA_WIDTH] = $random(seed);
                a_valid_in[i] = $random(seed);
                b_valid_in[i] = $random(seed);
            end
            tick;
        end
        idle_edges(DRAIN_EDGES);
        $display("PASS: independent masks, every PE's forwarding and valid paths");

        // Interrupt a populated pipeline. Hold clear while all lanes stay valid.
        a_valid_in = {ARRAY_SIZE{1'b1}}; b_valid_in = {ARRAY_SIZE{1'b1}};
        repeat (ARRAY_SIZE+1) tick;
        clear_acc = 1;
        repeat (3) tick;
        clear_acc = 0;
        idle_edges(CORE_EDGES);
        if (acc_out !== 0) $fatal(1, "Clear leaked cancelled operands");
        $display("PASS: mid-flight clear, clear priority, multi-edge clear and flush");

        a_valid_in = {ARRAY_SIZE{1'b1}}; b_valid_in = {ARRAY_SIZE{1'b1}};
        repeat (ARRAY_SIZE+1) tick;
        #2 rst_n = 0; // deliberately away from the rising edge
        #1;
        if (acc_out !== 0) $fatal(1, "Asynchronous accumulator reset failed");
        tick;
        rst_n = 1;
        idle_edges(CORE_EDGES);
        if (acc_out !== 0) $fatal(1, "Reset leaked cancelled operands");
        $display("PASS: mid-flight asynchronous reset and pipeline flush");

        // Different complete operations separated by just one clear edge.
        for (n = 0; n < 2; n = n+1) begin
            a_valid_in = {ARRAY_SIZE{1'b1}}; b_valid_in = {ARRAY_SIZE{1'b1}};
            clear_array;
            for (i = 0; i < ELEMENTS; i = i+1) begin
                mat_a[i] = n+1;
                mat_b[i] = (i/ARRAY_SIZE == i%ARRAY_SIZE) ? -1 : 0;
            end
            stream_matrix(0);
        end
        $display("PASS: immediate post-clear restart and repeated operations");
        $display("LATENCY: N=%0d DATA_WIDTH=%0d ACC_WIDTH=%0d core_edges=%0d drain_edges=%0d elapsed_ns=%0d",
            ARRAY_SIZE, DATA_WIDTH, ACC_WIDTH, plain_edges, DRAIN_EDGES, (plain_edges-1)*10);
        if ($value$plusargs("REPORT=%s", report_path)) begin
            report_file = $fopen(report_path, "w");
            if (report_file == 0) $fatal(1, "Cannot open report %s", report_path);
            $fdisplay(report_file, "array_size,data_width,acc_width,matrices,checked_edges,core_edges,drain_edges,elapsed_ns,status");
            $fdisplay(report_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,PASS",
                ARRAY_SIZE, DATA_WIDTH, ACC_WIDTH, matrices_checked, checked_edges,
                plain_edges, DRAIN_EDGES, (plain_edges-1)*10);
            $fclose(report_file);
        end
        $display("ALL ARRAY CORE TESTS PASSED (N=%0d, DATA_WIDTH=%0d, ACC_WIDTH=%0d, checked_edges=%0d)",
            ARRAY_SIZE, DATA_WIDTH, ACC_WIDTH, checked_edges);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "Array test timeout");
    end
endmodule
