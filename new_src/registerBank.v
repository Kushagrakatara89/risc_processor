module register_n
#(parameter N = 16)
(
    input  [N-1:0] in,
    input          clk, reset, enable,
    output reg [N-1:0] out
);
    always @(posedge clk) begin
        if (reset)
            out <= {N{1'b0}};
        else if (enable)
            out <= in;
    end
endmodule

module register_bank
(
    input         clk, reset,
    input  [2:0]  readAddress1, readAddress2, writeAddress,
    input  [15:0] writeData,
    input         writeEnable,
    output reg [15:0] readData1, readData2,
    input  [2:0]  debug_addr,
    output [15:0] debug_data
);
    reg [15:0] registerFile [0:7];
    integer i;

    // Read with write-through (R0 always returns 0)
    always @(*) begin
        readData1 = (readAddress1 == 3'd0) ? 16'd0 :
                    (writeEnable && writeAddress == readAddress1 && writeAddress != 3'd0) ?
                    writeData : registerFile[readAddress1];
        readData2 = (readAddress2 == 3'd0) ? 16'd0 :
                    (writeEnable && writeAddress == readAddress2 && writeAddress != 3'd0) ?
                    writeData : registerFile[readAddress2];
    end

    // Write on clock edge (R0 protected, reset via synchronous reset only)
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1)
                registerFile[i] <= 16'd0;
        end else begin
            if (writeEnable && writeAddress != 3'd0)
                registerFile[writeAddress] <= writeData;
        end
    end

    assign debug_data = (debug_addr == 3'd0) ? 16'd0 : registerFile[debug_addr];
endmodule
