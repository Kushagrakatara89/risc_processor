`timescale 1us/1ns

module pipelined_processor_tb;

reg clk;
reg reset;

// Instantiate DUT
pipelined_processor uut (
    .clk(clk),
    .reset(reset)
);

// Clock generation (20 time units period)
always #10 clk = ~clk;

initial begin
    // Dump file for GTKWave
    $dumpfile("dump.vcd");
    
    // Dump all variables inside DUT
    $dumpvars(0, pipelined_processor_tb);

    // Initialize signals
    clk   = 0;
    reset = 1'b1;

    // Apply reset
    #20;
    reset = 1'b0;

    // Run simulation
    #500;
    
    $finish;
end

endmodule

