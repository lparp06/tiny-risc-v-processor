module imemory_core0_unlocked (
    input  [31:0] addr,
    input         clk,
    output [31:0] rdata
);

core0unlocked u_core0 (
    .address (addr[11:2]),
    .clock   (clk),
    .data    (32'b0),
    .wren    (1'b0),
    .q       (rdata)
);

endmodule