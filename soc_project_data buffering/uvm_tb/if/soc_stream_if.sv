// =============================================================================
// Interface: soc_stream_if.sv
// Description: Streaming Sample Interface for Sensor Input
// =============================================================================

`ifndef SOC_STREAM_IF_SV
`define SOC_STREAM_IF_SV

interface soc_stream_if (
    input logic clk,
    input logic rst_n
);

    logic        valid;
    logic [31:0] data;
    logic        ready;

    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns;
        output valid, data;
        input  ready;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input valid, data, ready;
    endclocking

    modport master (clocking drv_cb, input clk, input rst_n);
    modport monitor (clocking mon_cb, input clk, input rst_n);

endinterface : soc_stream_if

`endif // SOC_STREAM_IF_SV
