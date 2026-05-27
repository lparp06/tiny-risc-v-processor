module imemory_core1_locked (
    input  [31:0] addr,
    input         clk,
    output [31:0] rdata
);

core1locked u_core1 (
    .address (addr[11:2]),
    .clock   (clk),
    .data    (32'b0),
    .wren    (1'b0),
    .q       (rdata)
);

endmodule