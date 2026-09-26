/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Priority encoder module
 */
module priority_encoder #
(
    parameter WIDTH = 4,
    // LSB priority selection
    parameter LSB_HIGH_PRIORITY = 0
)
(
    input  wire [WIDTH-1:0]         input_unencoded,

    output wire                     output_valid,
    output wire [$clog2(WIDTH)-1:0] output_encoded,
    output wire [WIDTH-1:0]         output_unencoded
);

// power-of-two width for the internal tree
parameter LEVELS = $clog2(WIDTH);
parameter W = 2**LEVELS;

// pad input to next power of two
wire [W-1:0] input_padded = {{W-WIDTH{1'b0}}, input_unencoded};

wire [W/2-1:0] stage_valid[LEVELS];
wire [W/2-1:0] stage_enc  [LEVELS];

genvar l, n;

generate

if (LSB_HIGH_PRIORITY) begin : g_lsb

    // -----------------------------------------------------------------------
    // LSB has highest priority: scan from bit 0 upward
    // -----------------------------------------------------------------------

    // Level 0 – compare adjacent pairs
    for (n = 0; n < W/2; n = n + 1) begin : l0
        assign stage_valid[0][n] = |input_padded[2*n +: 2];
        assign stage_enc  [0][n] =  input_padded[2*n] ? 1'b0 : 1'b1;
    end

    // Levels 1 .. LEVELS-1 – merge pairs of lower-level results
    for (l = 1; l < LEVELS; l = l + 1) begin : lN
        for (n = 0; n < W >> (l+1); n = n + 1) begin : pairs
            assign stage_valid[l][n] = |stage_valid[l-1][2*n +: 2];
            assign stage_enc  [l][n] = stage_valid[l-1][2*n] ?
                                       {1'b0, stage_enc[l-1][2*n  ]} :
                                       {1'b1, stage_enc[l-1][2*n+1]};
        end
    end

end else begin : g_msb

    // -----------------------------------------------------------------------
    // MSB has highest priority: scan from MSB downward
    // -----------------------------------------------------------------------

    // Level 0 – compare adjacent pairs (MSB of each pair wins)
    for (n = 0; n < W/2; n = n + 1) begin : l0
        assign stage_valid[0][n] = |input_padded[2*n +: 2];
        assign stage_enc  [0][n] =  input_padded[2*n+1] ? 1'b1 : 1'b0;
    end

    // Levels 1 .. LEVELS-1
    for (l = 1; l < LEVELS; l = l + 1) begin : lN
        for (n = 0; n < W >> (l+1); n = n + 1) begin : pairs
            assign stage_valid[l][n] = |stage_valid[l-1][2*n +: 2];
            assign stage_enc  [l][n] = stage_valid[l-1][2*n+1] ?
                                       {1'b1, stage_enc[l-1][2*n+1]} :
                                       {1'b0, stage_enc[l-1][2*n  ]};
        end
    end

end

endgenerate

// Final outputs
assign output_valid    = stage_valid[LEVELS-1][0];
assign output_encoded  = stage_enc  [LEVELS-1][0];

// Decode the one-hot unencoded output
assign output_unencoded = output_valid ? ({{WIDTH-1{1'b0}}, 1'b1} << output_encoded) : {WIDTH{1'b0}};

endmodule

`resetall
