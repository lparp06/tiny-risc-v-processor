module imemory (
    input  [31:0] addr,
    input         clk,
    output [31:0] rdata
);

imem u_imem (
    .address (addr[11:2]),
    .clock   (clk),
    .data    (32'b0),
    .wren    (1'b0),
    .q       (rdata)
);

endmodule