// 2-to-1 Multiplexer
module mux_21
#(
    parameter IN_WIDTH  = 16,
    parameter OUT_WIDTH = 16
)
(
    input  [IN_WIDTH-1:0]  A, B,
    input                  sel,
    output reg [OUT_WIDTH-1:0] O
);
    always @(*)
        O = sel ? B : A;
endmodule

// 4-to-1 Multiplexer
module mux_41
#(
    parameter IN_WIDTH  = 16,
    parameter OUT_WIDTH = 16
)
(
    input  [IN_WIDTH-1:0]  A, B, C, D,
    input  [1:0]           sel,
    output reg [OUT_WIDTH-1:0] O
);
    always @(*)
        case (sel)
            2'b00: O = A;
            2'b01: O = B;
            2'b10: O = C;
            2'b11: O = D;
        endcase
endmodule

