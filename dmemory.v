module dmemory (
    input         clk,
    input  [31:0] addr,
    input  [31:0] wdata,
    input         wen,
    output [31:0] rdata
);

dmem u_dmem (
    .address (addr[11:2]),
    .clock   (clk),
    .data    (wdata),
    .wren    (wen),
    .q       (rdata)
);

endmodule