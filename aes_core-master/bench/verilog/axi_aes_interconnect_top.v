`timescale 1ns/1ps

module axi_aes_interconnect_top;

    wire AWREADY_M1;
    reg [3:0] AWID_M1;
    reg [31:0] AWADDR_M1;
    reg [3:0] AWLEN_M1;
    reg [2:0] AWSIZE_M1;
    reg [1:0] AWBURST_M1;
    reg AWVALID_M1;
    wire WREADY_M1;
    reg [3:0] WID_M1;
    reg [31:0] WDATA_M1;
    reg WLAST_M1;
    reg WVALID_M1;
    wire [3:0] BID_M1;
    wire [1:0] BRESP_M1;
    wire BVALID_M1;
    reg BREADY_M1;
    wire ARREADY_M1;
    reg [3:0] ARID_M1;
    reg [31:0] ARADDR_M1;
    reg [2:0] ARSIZE_M1;
    reg [1:0] ARBURST_M1;
    reg [3:0] ARLEN_M1;
    reg ARVALID_M1;
    wire [3:0] RID_M1;
    wire RLAST_M1;
    wire RVALID_M1;
    wire [1:0] RRESP_M1;
    wire [31:0] RDATA_M1;
    reg RREADY_M1;
    reg clk;
    reg reset;

    wire AWREADY_M2;
    wire [3:0] AWID_M2;
    wire [31:0] AWADDR_M2;
    wire [3:0] AWLEN_M2;
    wire [2:0] AWSIZE_M2;
    wire [1:0] AWBURST_M2;
    wire AWVALID_M2;
    wire WREADY_M2;
    wire [3:0] WID_M2;
    wire [31:0] WDATA_M2;
    wire WLAST_M2;
    wire WVALID_M2;
    wire [3:0] BID_M2;
    wire [1:0] BRESP_M2;
    wire BVALID_M2;
    wire BREADY_M2;
    wire AWREADY_M3;
    wire [3:0] AWID_M3;
    wire [31:0] AWADDR_M3;
    wire [3:0] AWLEN_M3;
    wire [2:0] AWSIZE_M3;
    wire [1:0] AWBURST_M3;
    wire AWVALID_M3;
    wire WREADY_M3;
    wire [3:0] WID_M3;
    wire [31:0] WDATA_M3;
    wire WLAST_M3;
    wire WVALID_M3;
    wire [3:0] BID_M3;
    wire [1:0] BRESP_M3;
    wire BVALID_M3;
    wire BREADY_M3;
    wire AWREADY_M4;
    wire [3:0] AWID_M4;
    wire [31:0] AWADDR_M4;
    wire [3:0] AWLEN_M4;
    wire [2:0] AWSIZE_M4;
    wire [1:0] AWBURST_M4;
    wire AWVALID_M4;
    wire WREADY_M4;
    wire [3:0] WID_M4;
    wire [31:0] WDATA_M4;
    wire WLAST_M4;
    wire WVALID_M4;
    wire [3:0] BID_M4;
    wire [1:0] BRESP_M4;
    wire BVALID_M4;
    wire BREADY_M4;
    wire AWREADY_M5;
    wire [3:0] AWID_M5;
    wire [31:0] AWADDR_M5;
    wire [3:0] AWLEN_M5;
    wire [2:0] AWSIZE_M5;
    wire [1:0] AWBURST_M5;
    wire AWVALID_M5;
    wire WREADY_M5;
    wire [3:0] WID_M5;
    wire [31:0] WDATA_M5;
    wire WLAST_M5;
    wire WVALID_M5;
    wire [3:0] BID_M5;
    wire [1:0] BRESP_M5;
    wire BVALID_M5;
    wire BREADY_M5;
    wire AWREADY_M6;
    wire [3:0] AWID_M6;
    wire [31:0] AWADDR_M6;
    wire [3:0] AWLEN_M6;
    wire [2:0] AWSIZE_M6;
    wire [1:0] AWBURST_M6;
    wire AWVALID_M6;
    wire WREADY_M6;
    wire [3:0] WID_M6;
    wire [31:0] WDATA_M6;
    wire WLAST_M6;
    wire WVALID_M6;
    wire [3:0] BID_M6;
    wire [1:0] BRESP_M6;
    wire BVALID_M6;
    wire BREADY_M6;
    wire AWREADY_M7;
    wire [3:0] AWID_M7;
    wire [31:0] AWADDR_M7;
    wire [3:0] AWLEN_M7;
    wire [2:0] AWSIZE_M7;
    wire [1:0] AWBURST_M7;
    wire AWVALID_M7;
    wire WREADY_M7;
    wire [3:0] WID_M7;
    wire [31:0] WDATA_M7;
    wire WLAST_M7;
    wire WVALID_M7;
    wire [3:0] BID_M7;
    wire [1:0] BRESP_M7;
    wire BVALID_M7;
    wire BREADY_M7;
    wire AWREADY_M8;
    wire [3:0] AWID_M8;
    wire [31:0] AWADDR_M8;
    wire [3:0] AWLEN_M8;
    wire [2:0] AWSIZE_M8;
    wire [1:0] AWBURST_M8;
    wire AWVALID_M8;
    wire WREADY_M8;
    wire [3:0] WID_M8;
    wire [31:0] WDATA_M8;
    wire WLAST_M8;
    wire WVALID_M8;
    wire [3:0] BID_M8;
    wire [1:0] BRESP_M8;
    wire BVALID_M8;
    wire BREADY_M8;
    wire AWREADY_M9;
    wire [3:0] AWID_M9;
    wire [31:0] AWADDR_M9;
    wire [3:0] AWLEN_M9;
    wire [2:0] AWSIZE_M9;
    wire [1:0] AWBURST_M9;
    wire AWVALID_M9;
    wire WREADY_M9;
    wire [3:0] WID_M9;
    wire [31:0] WDATA_M9;
    wire WLAST_M9;
    wire WVALID_M9;
    wire [3:0] BID_M9;
    wire [1:0] BRESP_M9;
    wire BVALID_M9;
    wire BREADY_M9;
    wire AWREADY_M10;
    wire [3:0] AWID_M10;
    wire [31:0] AWADDR_M10;
    wire [3:0] AWLEN_M10;
    wire [2:0] AWSIZE_M10;
    wire [1:0] AWBURST_M10;
    wire AWVALID_M10;
    wire WREADY_M10;
    wire [3:0] WID_M10;
    wire [31:0] WDATA_M10;
    wire WLAST_M10;
    wire WVALID_M10;
    wire [3:0] BID_M10;
    wire [1:0] BRESP_M10;
    wire BVALID_M10;
    wire BREADY_M10;
    wire AWREADY_M11;
    wire [3:0] AWID_M11;
    wire [31:0] AWADDR_M11;
    wire [3:0] AWLEN_M11;
    wire [2:0] AWSIZE_M11;
    wire [1:0] AWBURST_M11;
    wire AWVALID_M11;
    wire WREADY_M11;
    wire [3:0] WID_M11;
    wire [31:0] WDATA_M11;
    wire WLAST_M11;
    wire WVALID_M11;
    wire [3:0] BID_M11;
    wire [1:0] BRESP_M11;
    wire BVALID_M11;
    wire BREADY_M11;
    wire AWREADY_M12;
    wire [3:0] AWID_M12;
    wire [31:0] AWADDR_M12;
    wire [3:0] AWLEN_M12;
    wire [2:0] AWSIZE_M12;
    wire [1:0] AWBURST_M12;
    wire AWVALID_M12;
    wire WREADY_M12;
    wire [3:0] WID_M12;
    wire [31:0] WDATA_M12;
    wire WLAST_M12;
    wire WVALID_M12;
    wire [3:0] BID_M12;
    wire [1:0] BRESP_M12;
    wire BVALID_M12;
    wire BREADY_M12;
    wire AWREADY_M13;
    wire [3:0] AWID_M13;
    wire [31:0] AWADDR_M13;
    wire [3:0] AWLEN_M13;
    wire [2:0] AWSIZE_M13;
    wire [1:0] AWBURST_M13;
    wire AWVALID_M13;
    wire WREADY_M13;
    wire [3:0] WID_M13;
    wire [31:0] WDATA_M13;
    wire WLAST_M13;
    wire WVALID_M13;
    wire [3:0] BID_M13;
    wire [1:0] BRESP_M13;
    wire BVALID_M13;
    wire BREADY_M13;
    wire AWREADY_M14;
    wire [3:0] AWID_M14;
    wire [31:0] AWADDR_M14;
    wire [3:0] AWLEN_M14;
    wire [2:0] AWSIZE_M14;
    wire [1:0] AWBURST_M14;
    wire AWVALID_M14;
    wire WREADY_M14;
    wire [3:0] WID_M14;
    wire [31:0] WDATA_M14;
    wire WLAST_M14;
    wire WVALID_M14;
    wire [3:0] BID_M14;
    wire [1:0] BRESP_M14;
    wire BVALID_M14;
    wire BREADY_M14;
    wire AWREADY_M15;
    wire [3:0] AWID_M15;
    wire [31:0] AWADDR_M15;
    wire [3:0] AWLEN_M15;
    wire [2:0] AWSIZE_M15;
    wire [1:0] AWBURST_M15;
    wire AWVALID_M15;
    wire WREADY_M15;
    wire [3:0] WID_M15;
    wire [31:0] WDATA_M15;
    wire WLAST_M15;
    wire WVALID_M15;
    wire [3:0] BID_M15;
    wire [1:0] BRESP_M15;
    wire BVALID_M15;
    wire BREADY_M15;
    wire [3:0] AWID_S1;
    wire [31:0] AWADDR_S1;
    wire [3:0] AWLEN_S1;
    wire [2:0] AWSIZE_S1;
    wire [1:0] AWBURST_S1;
    wire AWVALID_S1;
    wire AWREADY_S1;
    wire [3:0] WID_S1;
    wire [31:0] WDATA_S1;
    wire WLAST_S1;
    wire WVALID_S1;
    wire WREADY_S1;
    wire BREADY_S1;
    wire [3:0] BID_S1;
    wire [1:0] BRESP_S1;
    wire BVALID_S1;
    wire [3:0] AWID_S2;
    wire [31:0] AWADDR_S2;
    wire [3:0] AWLEN_S2;
    wire [2:0] AWSIZE_S2;
    wire [1:0] AWBURST_S2;
    wire AWVALID_S2;
    wire AWREADY_S2;
    wire [3:0] WID_S2;
    wire [31:0] WDATA_S2;
    wire WLAST_S2;
    wire WVALID_S2;
    wire WREADY_S2;
    wire BREADY_S2;
    wire [3:0] BID_S2;
    wire [1:0] BRESP_S2;
    wire BVALID_S2;
    wire [3:0] AWID_S3;
    wire [31:0] AWADDR_S3;
    wire [3:0] AWLEN_S3;
    wire [2:0] AWSIZE_S3;
    wire [1:0] AWBURST_S3;
    wire AWVALID_S3;
    wire AWREADY_S3;
    wire [3:0] WID_S3;
    wire [31:0] WDATA_S3;
    wire WLAST_S3;
    wire WVALID_S3;
    wire WREADY_S3;
    wire BREADY_S3;
    wire [3:0] BID_S3;
    wire [1:0] BRESP_S3;
    wire BVALID_S3;
    wire [3:0] AWID_S4;
    wire [31:0] AWADDR_S4;
    wire [3:0] AWLEN_S4;
    wire [2:0] AWSIZE_S4;
    wire [1:0] AWBURST_S4;
    wire AWVALID_S4;
    wire AWREADY_S4;
    wire [3:0] WID_S4;
    wire [31:0] WDATA_S4;
    wire WLAST_S4;
    wire WVALID_S4;
    wire WREADY_S4;
    wire BREADY_S4;
    wire [3:0] BID_S4;
    wire [1:0] BRESP_S4;
    wire BVALID_S4;
    wire ARREADY_M2;
    wire [3:0] ARID_M2;
    wire [31:0] ARADDR_M2;
    wire [2:0] ARSIZE_M2;
    wire [1:0] ARBURST_M2;
    wire [3:0] ARLEN_M2;
    wire ARVALID_M2;
    wire [3:0] RID_M2;
    wire RLAST_M2;
    wire RVALID_M2;
    wire [1:0] RRESP_M2;
    wire [31:0] RDATA_M2;
    wire RREADY_M2;
    wire ARREADY_M3;
    wire [3:0] ARID_M3;
    wire [31:0] ARADDR_M3;
    wire [2:0] ARSIZE_M3;
    wire [1:0] ARBURST_M3;
    wire [3:0] ARLEN_M3;
    wire ARVALID_M3;
    wire [3:0] RID_M3;
    wire RLAST_M3;
    wire RVALID_M3;
    wire [1:0] RRESP_M3;
    wire [31:0] RDATA_M3;
    wire RREADY_M3;
    wire ARREADY_M4;
    wire [3:0] ARID_M4;
    wire [31:0] ARADDR_M4;
    wire [2:0] ARSIZE_M4;
    wire [1:0] ARBURST_M4;
    wire [3:0] ARLEN_M4;
    wire ARVALID_M4;
    wire [3:0] RID_M4;
    wire RLAST_M4;
    wire RVALID_M4;
    wire [1:0] RRESP_M4;
    wire [31:0] RDATA_M4;
    wire RREADY_M4;
    wire ARREADY_M5;
    wire [3:0] ARID_M5;
    wire [31:0] ARADDR_M5;
    wire [2:0] ARSIZE_M5;
    wire [1:0] ARBURST_M5;
    wire [3:0] ARLEN_M5;
    wire ARVALID_M5;
    wire [3:0] RID_M5;
    wire RLAST_M5;
    wire RVALID_M5;
    wire [1:0] RRESP_M5;
    wire [31:0] RDATA_M5;
    wire RREADY_M5;
    wire ARREADY_M6;
    wire [3:0] ARID_M6;
    wire [31:0] ARADDR_M6;
    wire [2:0] ARSIZE_M6;
    wire [1:0] ARBURST_M6;
    wire [3:0] ARLEN_M6;
    wire ARVALID_M6;
    wire [3:0] RID_M6;
    wire RLAST_M6;
    wire RVALID_M6;
    wire [1:0] RRESP_M6;
    wire [31:0] RDATA_M6;
    wire RREADY_M6;
    wire ARREADY_M7;
    wire [3:0] ARID_M7;
    wire [31:0] ARADDR_M7;
    wire [2:0] ARSIZE_M7;
    wire [1:0] ARBURST_M7;
    wire [3:0] ARLEN_M7;
    wire ARVALID_M7;
    wire [3:0] RID_M7;
    wire RLAST_M7;
    wire RVALID_M7;
    wire [1:0] RRESP_M7;
    wire [31:0] RDATA_M7;
    wire RREADY_M7;
    wire ARREADY_M8;
    wire [3:0] ARID_M8;
    wire [31:0] ARADDR_M8;
    wire [2:0] ARSIZE_M8;
    wire [1:0] ARBURST_M8;
    wire [3:0] ARLEN_M8;
    wire ARVALID_M8;
    wire [3:0] RID_M8;
    wire RLAST_M8;
    wire RVALID_M8;
    wire [1:0] RRESP_M8;
    wire [31:0] RDATA_M8;
    wire RREADY_M8;
    wire ARREADY_M9;
    wire [3:0] ARID_M9;
    wire [31:0] ARADDR_M9;
    wire [2:0] ARSIZE_M9;
    wire [1:0] ARBURST_M9;
    wire [3:0] ARLEN_M9;
    wire ARVALID_M9;
    wire [3:0] RID_M9;
    wire RLAST_M9;
    wire RVALID_M9;
    wire [1:0] RRESP_M9;
    wire [31:0] RDATA_M9;
    wire RREADY_M9;
    wire ARREADY_M10;
    wire [3:0] ARID_M10;
    wire [31:0] ARADDR_M10;
    wire [2:0] ARSIZE_M10;
    wire [1:0] ARBURST_M10;
    wire [3:0] ARLEN_M10;
    wire ARVALID_M10;
    wire [3:0] RID_M10;
    wire RLAST_M10;
    wire RVALID_M10;
    wire [1:0] RRESP_M10;
    wire [31:0] RDATA_M10;
    wire RREADY_M10;
    wire ARREADY_M11;
    wire [3:0] ARID_M11;
    wire [31:0] ARADDR_M11;
    wire [2:0] ARSIZE_M11;
    wire [1:0] ARBURST_M11;
    wire [3:0] ARLEN_M11;
    wire ARVALID_M11;
    wire [3:0] RID_M11;
    wire RLAST_M11;
    wire RVALID_M11;
    wire [1:0] RRESP_M11;
    wire [31:0] RDATA_M11;
    wire RREADY_M11;
    wire ARREADY_M12;
    wire [3:0] ARID_M12;
    wire [31:0] ARADDR_M12;
    wire [2:0] ARSIZE_M12;
    wire [1:0] ARBURST_M12;
    wire [3:0] ARLEN_M12;
    wire ARVALID_M12;
    wire [3:0] RID_M12;
    wire RLAST_M12;
    wire RVALID_M12;
    wire [1:0] RRESP_M12;
    wire [31:0] RDATA_M12;
    wire RREADY_M12;
    wire ARREADY_M13;
    wire [3:0] ARID_M13;
    wire [31:0] ARADDR_M13;
    wire [2:0] ARSIZE_M13;
    wire [1:0] ARBURST_M13;
    wire [3:0] ARLEN_M13;
    wire ARVALID_M13;
    wire [3:0] RID_M13;
    wire RLAST_M13;
    wire RVALID_M13;
    wire [1:0] RRESP_M13;
    wire [31:0] RDATA_M13;
    wire RREADY_M13;
    wire ARREADY_M14;
    wire [3:0] ARID_M14;
    wire [31:0] ARADDR_M14;
    wire [2:0] ARSIZE_M14;
    wire [1:0] ARBURST_M14;
    wire [3:0] ARLEN_M14;
    wire ARVALID_M14;
    wire [3:0] RID_M14;
    wire RLAST_M14;
    wire RVALID_M14;
    wire [1:0] RRESP_M14;
    wire [31:0] RDATA_M14;
    wire RREADY_M14;
    wire ARREADY_M15;
    wire [3:0] ARID_M15;
    wire [31:0] ARADDR_M15;
    wire [2:0] ARSIZE_M15;
    wire [1:0] ARBURST_M15;
    wire [3:0] ARLEN_M15;
    wire ARVALID_M15;
    wire [3:0] RID_M15;
    wire RLAST_M15;
    wire RVALID_M15;
    wire [1:0] RRESP_M15;
    wire [31:0] RDATA_M15;
    wire RREADY_M15;
    wire ARREADY_S1;
    wire [3:0] ARID_S1;
    wire [31:0] ARADDR_S1;
    wire [2:0] ARSIZE_S1;
    wire [1:0] ARBURST_S1;
    wire [3:0] ARLEN_S1;
    wire ARVALID_S1;
    wire [3:0] RID_S1;
    wire RLAST_S1;
    wire RVALID_S1;
    wire [1:0] RRESP_S1;
    wire [31:0] RDATA_S1;
    wire RREADY_S1;
    wire ARREADY_S2;
    wire [3:0] ARID_S2;
    wire [31:0] ARADDR_S2;
    wire [2:0] ARSIZE_S2;
    wire [1:0] ARBURST_S2;
    wire [3:0] ARLEN_S2;
    wire ARVALID_S2;
    wire [3:0] RID_S2;
    wire RLAST_S2;
    wire RVALID_S2;
    wire [1:0] RRESP_S2;
    wire [31:0] RDATA_S2;
    wire RREADY_S2;
    wire ARREADY_S3;
    wire [3:0] ARID_S3;
    wire [31:0] ARADDR_S3;
    wire [2:0] ARSIZE_S3;
    wire [1:0] ARBURST_S3;
    wire [3:0] ARLEN_S3;
    wire ARVALID_S3;
    wire [3:0] RID_S3;
    wire RLAST_S3;
    wire RVALID_S3;
    wire [1:0] RRESP_S3;
    wire [31:0] RDATA_S3;
    wire RREADY_S3;
    wire ARREADY_S4;
    wire [3:0] ARID_S4;
    wire [31:0] ARADDR_S4;
    wire [2:0] ARSIZE_S4;
    wire [1:0] ARBURST_S4;
    wire [3:0] ARLEN_S4;
    wire ARVALID_S4;
    wire [3:0] RID_S4;
    wire RLAST_S4;
    wire RVALID_S4;
    wire [31:0] RDATA_S4;
    wire [1:0] RRESP_S4;
    wire RREADY_S4;

    // Tie unused master and S2-S4 input channels inactive.
    assign AWID_M2 = 4'b0;
    assign AWADDR_M2 = 32'b0;
    assign AWLEN_M2 = 4'b0;
    assign AWSIZE_M2 = 3'b0;
    assign AWBURST_M2 = 2'b0;
    assign AWVALID_M2 = 1'b0;
    assign WID_M2 = 4'b0;
    assign WDATA_M2 = 32'b0;
    assign WLAST_M2 = 1'b0;
    assign WVALID_M2 = 1'b0;
    assign BREADY_M2 = 1'b0;
    assign AWID_M3 = 4'b0;
    assign AWADDR_M3 = 32'b0;
    assign AWLEN_M3 = 4'b0;
    assign AWSIZE_M3 = 3'b0;
    assign AWBURST_M3 = 2'b0;
    assign AWVALID_M3 = 1'b0;
    assign WID_M3 = 4'b0;
    assign WDATA_M3 = 32'b0;
    assign WLAST_M3 = 1'b0;
    assign WVALID_M3 = 1'b0;
    assign BREADY_M3 = 1'b0;
    assign AWID_M4 = 4'b0;
    assign AWADDR_M4 = 32'b0;
    assign AWLEN_M4 = 4'b0;
    assign AWSIZE_M4 = 3'b0;
    assign AWBURST_M4 = 2'b0;
    assign AWVALID_M4 = 1'b0;
    assign WID_M4 = 4'b0;
    assign WDATA_M4 = 32'b0;
    assign WLAST_M4 = 1'b0;
    assign WVALID_M4 = 1'b0;
    assign BREADY_M4 = 1'b0;
    assign AWID_M5 = 4'b0;
    assign AWADDR_M5 = 32'b0;
    assign AWLEN_M5 = 4'b0;
    assign AWSIZE_M5 = 3'b0;
    assign AWBURST_M5 = 2'b0;
    assign AWVALID_M5 = 1'b0;
    assign WID_M5 = 4'b0;
    assign WDATA_M5 = 32'b0;
    assign WLAST_M5 = 1'b0;
    assign WVALID_M5 = 1'b0;
    assign BREADY_M5 = 1'b0;
    assign AWID_M6 = 4'b0;
    assign AWADDR_M6 = 32'b0;
    assign AWLEN_M6 = 4'b0;
    assign AWSIZE_M6 = 3'b0;
    assign AWBURST_M6 = 2'b0;
    assign AWVALID_M6 = 1'b0;
    assign WID_M6 = 4'b0;
    assign WDATA_M6 = 32'b0;
    assign WLAST_M6 = 1'b0;
    assign WVALID_M6 = 1'b0;
    assign BREADY_M6 = 1'b0;
    assign AWID_M7 = 4'b0;
    assign AWADDR_M7 = 32'b0;
    assign AWLEN_M7 = 4'b0;
    assign AWSIZE_M7 = 3'b0;
    assign AWBURST_M7 = 2'b0;
    assign AWVALID_M7 = 1'b0;
    assign WID_M7 = 4'b0;
    assign WDATA_M7 = 32'b0;
    assign WLAST_M7 = 1'b0;
    assign WVALID_M7 = 1'b0;
    assign BREADY_M7 = 1'b0;
    assign AWID_M8 = 4'b0;
    assign AWADDR_M8 = 32'b0;
    assign AWLEN_M8 = 4'b0;
    assign AWSIZE_M8 = 3'b0;
    assign AWBURST_M8 = 2'b0;
    assign AWVALID_M8 = 1'b0;
    assign WID_M8 = 4'b0;
    assign WDATA_M8 = 32'b0;
    assign WLAST_M8 = 1'b0;
    assign WVALID_M8 = 1'b0;
    assign BREADY_M8 = 1'b0;
    assign AWID_M9 = 4'b0;
    assign AWADDR_M9 = 32'b0;
    assign AWLEN_M9 = 4'b0;
    assign AWSIZE_M9 = 3'b0;
    assign AWBURST_M9 = 2'b0;
    assign AWVALID_M9 = 1'b0;
    assign WID_M9 = 4'b0;
    assign WDATA_M9 = 32'b0;
    assign WLAST_M9 = 1'b0;
    assign WVALID_M9 = 1'b0;
    assign BREADY_M9 = 1'b0;
    assign AWID_M10 = 4'b0;
    assign AWADDR_M10 = 32'b0;
    assign AWLEN_M10 = 4'b0;
    assign AWSIZE_M10 = 3'b0;
    assign AWBURST_M10 = 2'b0;
    assign AWVALID_M10 = 1'b0;
    assign WID_M10 = 4'b0;
    assign WDATA_M10 = 32'b0;
    assign WLAST_M10 = 1'b0;
    assign WVALID_M10 = 1'b0;
    assign BREADY_M10 = 1'b0;
    assign AWID_M11 = 4'b0;
    assign AWADDR_M11 = 32'b0;
    assign AWLEN_M11 = 4'b0;
    assign AWSIZE_M11 = 3'b0;
    assign AWBURST_M11 = 2'b0;
    assign AWVALID_M11 = 1'b0;
    assign WID_M11 = 4'b0;
    assign WDATA_M11 = 32'b0;
    assign WLAST_M11 = 1'b0;
    assign WVALID_M11 = 1'b0;
    assign BREADY_M11 = 1'b0;
    assign AWID_M12 = 4'b0;
    assign AWADDR_M12 = 32'b0;
    assign AWLEN_M12 = 4'b0;
    assign AWSIZE_M12 = 3'b0;
    assign AWBURST_M12 = 2'b0;
    assign AWVALID_M12 = 1'b0;
    assign WID_M12 = 4'b0;
    assign WDATA_M12 = 32'b0;
    assign WLAST_M12 = 1'b0;
    assign WVALID_M12 = 1'b0;
    assign BREADY_M12 = 1'b0;
    assign AWID_M13 = 4'b0;
    assign AWADDR_M13 = 32'b0;
    assign AWLEN_M13 = 4'b0;
    assign AWSIZE_M13 = 3'b0;
    assign AWBURST_M13 = 2'b0;
    assign AWVALID_M13 = 1'b0;
    assign WID_M13 = 4'b0;
    assign WDATA_M13 = 32'b0;
    assign WLAST_M13 = 1'b0;
    assign WVALID_M13 = 1'b0;
    assign BREADY_M13 = 1'b0;
    assign AWID_M14 = 4'b0;
    assign AWADDR_M14 = 32'b0;
    assign AWLEN_M14 = 4'b0;
    assign AWSIZE_M14 = 3'b0;
    assign AWBURST_M14 = 2'b0;
    assign AWVALID_M14 = 1'b0;
    assign WID_M14 = 4'b0;
    assign WDATA_M14 = 32'b0;
    assign WLAST_M14 = 1'b0;
    assign WVALID_M14 = 1'b0;
    assign BREADY_M14 = 1'b0;
    assign AWID_M15 = 4'b0;
    assign AWADDR_M15 = 32'b0;
    assign AWLEN_M15 = 4'b0;
    assign AWSIZE_M15 = 3'b0;
    assign AWBURST_M15 = 2'b0;
    assign AWVALID_M15 = 1'b0;
    assign WID_M15 = 4'b0;
    assign WDATA_M15 = 32'b0;
    assign WLAST_M15 = 1'b0;
    assign WVALID_M15 = 1'b0;
    assign BREADY_M15 = 1'b0;
    assign AWREADY_S2 = 1'b0;
    assign WREADY_S2 = 1'b0;
    assign BID_S2 = 4'b0;
    assign BRESP_S2 = 2'b0;
    assign BVALID_S2 = 1'b0;
    assign AWREADY_S3 = 1'b0;
    assign WREADY_S3 = 1'b0;
    assign BID_S3 = 4'b0;
    assign BRESP_S3 = 2'b0;
    assign BVALID_S3 = 1'b0;
    assign AWREADY_S4 = 1'b0;
    assign WREADY_S4 = 1'b0;
    assign BID_S4 = 4'b0;
    assign BRESP_S4 = 2'b0;
    assign BVALID_S4 = 1'b0;
    assign ARID_M2 = 4'b0;
    assign ARADDR_M2 = 32'b0;
    assign ARSIZE_M2 = 3'b0;
    assign ARBURST_M2 = 2'b0;
    assign ARLEN_M2 = 4'b0;
    assign ARVALID_M2 = 1'b0;
    assign RREADY_M2 = 1'b0;
    assign ARID_M3 = 4'b0;
    assign ARADDR_M3 = 32'b0;
    assign ARSIZE_M3 = 3'b0;
    assign ARBURST_M3 = 2'b0;
    assign ARLEN_M3 = 4'b0;
    assign ARVALID_M3 = 1'b0;
    assign RREADY_M3 = 1'b0;
    assign ARID_M4 = 4'b0;
    assign ARADDR_M4 = 32'b0;
    assign ARSIZE_M4 = 3'b0;
    assign ARBURST_M4 = 2'b0;
    assign ARLEN_M4 = 4'b0;
    assign ARVALID_M4 = 1'b0;
    assign RREADY_M4 = 1'b0;
    assign ARID_M5 = 4'b0;
    assign ARADDR_M5 = 32'b0;
    assign ARSIZE_M5 = 3'b0;
    assign ARBURST_M5 = 2'b0;
    assign ARLEN_M5 = 4'b0;
    assign ARVALID_M5 = 1'b0;
    assign RREADY_M5 = 1'b0;
    assign ARID_M6 = 4'b0;
    assign ARADDR_M6 = 32'b0;
    assign ARSIZE_M6 = 3'b0;
    assign ARBURST_M6 = 2'b0;
    assign ARLEN_M6 = 4'b0;
    assign ARVALID_M6 = 1'b0;
    assign RREADY_M6 = 1'b0;
    assign ARID_M7 = 4'b0;
    assign ARADDR_M7 = 32'b0;
    assign ARSIZE_M7 = 3'b0;
    assign ARBURST_M7 = 2'b0;
    assign ARLEN_M7 = 4'b0;
    assign ARVALID_M7 = 1'b0;
    assign RREADY_M7 = 1'b0;
    assign ARID_M8 = 4'b0;
    assign ARADDR_M8 = 32'b0;
    assign ARSIZE_M8 = 3'b0;
    assign ARBURST_M8 = 2'b0;
    assign ARLEN_M8 = 4'b0;
    assign ARVALID_M8 = 1'b0;
    assign RREADY_M8 = 1'b0;
    assign ARID_M9 = 4'b0;
    assign ARADDR_M9 = 32'b0;
    assign ARSIZE_M9 = 3'b0;
    assign ARBURST_M9 = 2'b0;
    assign ARLEN_M9 = 4'b0;
    assign ARVALID_M9 = 1'b0;
    assign RREADY_M9 = 1'b0;
    assign ARID_M10 = 4'b0;
    assign ARADDR_M10 = 32'b0;
    assign ARSIZE_M10 = 3'b0;
    assign ARBURST_M10 = 2'b0;
    assign ARLEN_M10 = 4'b0;
    assign ARVALID_M10 = 1'b0;
    assign RREADY_M10 = 1'b0;
    assign ARID_M11 = 4'b0;
    assign ARADDR_M11 = 32'b0;
    assign ARSIZE_M11 = 3'b0;
    assign ARBURST_M11 = 2'b0;
    assign ARLEN_M11 = 4'b0;
    assign ARVALID_M11 = 1'b0;
    assign RREADY_M11 = 1'b0;
    assign ARID_M12 = 4'b0;
    assign ARADDR_M12 = 32'b0;
    assign ARSIZE_M12 = 3'b0;
    assign ARBURST_M12 = 2'b0;
    assign ARLEN_M12 = 4'b0;
    assign ARVALID_M12 = 1'b0;
    assign RREADY_M12 = 1'b0;
    assign ARID_M13 = 4'b0;
    assign ARADDR_M13 = 32'b0;
    assign ARSIZE_M13 = 3'b0;
    assign ARBURST_M13 = 2'b0;
    assign ARLEN_M13 = 4'b0;
    assign ARVALID_M13 = 1'b0;
    assign RREADY_M13 = 1'b0;
    assign ARID_M14 = 4'b0;
    assign ARADDR_M14 = 32'b0;
    assign ARSIZE_M14 = 3'b0;
    assign ARBURST_M14 = 2'b0;
    assign ARLEN_M14 = 4'b0;
    assign ARVALID_M14 = 1'b0;
    assign RREADY_M14 = 1'b0;
    assign ARID_M15 = 4'b0;
    assign ARADDR_M15 = 32'b0;
    assign ARSIZE_M15 = 3'b0;
    assign ARBURST_M15 = 2'b0;
    assign ARLEN_M15 = 4'b0;
    assign ARVALID_M15 = 1'b0;
    assign RREADY_M15 = 1'b0;
    assign ARREADY_S2 = 1'b0;
    assign RID_S2 = 4'b0;
    assign RLAST_S2 = 1'b0;
    assign RVALID_S2 = 1'b0;
    assign RRESP_S2 = 2'b0;
    assign RDATA_S2 = 32'b0;
    assign ARREADY_S3 = 1'b0;
    assign RID_S3 = 4'b0;
    assign RLAST_S3 = 1'b0;
    assign RVALID_S3 = 1'b0;
    assign RRESP_S3 = 2'b0;
    assign RDATA_S3 = 32'b0;
    assign ARREADY_S4 = 1'b0;
    assign RID_S4 = 4'b0;
    assign RLAST_S4 = 1'b0;
    assign RVALID_S4 = 1'b0;
    assign RDATA_S4 = 32'b0;
    assign RRESP_S4 = 2'b0;

    // AES is connected to slave port S1.
    aes_axi_slave u_aes (
        .clk     (clk),
        .reset   (reset),
        .AWID    (AWID_S1),
        .AWADDR  (AWADDR_S1),
        .AWLEN   (AWLEN_S1),
        .AWSIZE  (AWSIZE_S1),
        .AWBURST (AWBURST_S1),
        .AWVALID (AWVALID_S1),
        .AWREADY (AWREADY_S1),
        .WID     (WID_S1),
        .WDATA   (WDATA_S1),
        .WLAST   (WLAST_S1),
        .WVALID  (WVALID_S1),
        .WREADY  (WREADY_S1),
        .BID     (BID_S1),
        .BRESP   (BRESP_S1),
        .BVALID  (BVALID_S1),
        .BREADY  (BREADY_S1),
        .ARID    (ARID_S1),
        .ARADDR  (ARADDR_S1),
        .ARLEN   (ARLEN_S1),
        .ARSIZE  (ARSIZE_S1),
        .ARBURST (ARBURST_S1),
        .ARVALID (ARVALID_S1),
        .ARREADY (ARREADY_S1),
        .RID     (RID_S1),
        .RDATA   (RDATA_S1),
        .RRESP   (RRESP_S1),
        .RVALID  (RVALID_S1),
        .RLAST   (RLAST_S1),
        .RREADY  (RREADY_S1)
    );

    // The existing interconnect uses ack as its clock input.
    interconnect u_interconnect (
        .ack   (clk),
        .reset (reset),
        .AWREADY_M1 (AWREADY_M1),
        .AWID_M1 (AWID_M1),
        .AWADDR_M1 (AWADDR_M1),
        .AWLEN_M1 (AWLEN_M1),
        .AWSIZE_M1 (AWSIZE_M1),
        .AWBURST_M1 (AWBURST_M1),
        .AWVALID_M1 (AWVALID_M1),
        .WREADY_M1 (WREADY_M1),
        .WID_M1 (WID_M1),
        .WDATA_M1 (WDATA_M1),
        .WLAST_M1 (WLAST_M1),
        .WVALID_M1 (WVALID_M1),
        .BID_M1 (BID_M1),
        .BRESP_M1 (BRESP_M1),
        .BVALID_M1 (BVALID_M1),
        .BREADY_M1 (BREADY_M1),
        .AWREADY_M2 (AWREADY_M2),
        .AWID_M2 (AWID_M2),
        .AWADDR_M2 (AWADDR_M2),
        .AWLEN_M2 (AWLEN_M2),
        .AWSIZE_M2 (AWSIZE_M2),
        .AWBURST_M2 (AWBURST_M2),
        .AWVALID_M2 (AWVALID_M2),
        .WREADY_M2 (WREADY_M2),
        .WID_M2 (WID_M2),
        .WDATA_M2 (WDATA_M2),
        .WLAST_M2 (WLAST_M2),
        .WVALID_M2 (WVALID_M2),
        .BID_M2 (BID_M2),
        .BRESP_M2 (BRESP_M2),
        .BVALID_M2 (BVALID_M2),
        .BREADY_M2 (BREADY_M2),
        .AWREADY_M3 (AWREADY_M3),
        .AWID_M3 (AWID_M3),
        .AWADDR_M3 (AWADDR_M3),
        .AWLEN_M3 (AWLEN_M3),
        .AWSIZE_M3 (AWSIZE_M3),
        .AWBURST_M3 (AWBURST_M3),
        .AWVALID_M3 (AWVALID_M3),
        .WREADY_M3 (WREADY_M3),
        .WID_M3 (WID_M3),
        .WDATA_M3 (WDATA_M3),
        .WLAST_M3 (WLAST_M3),
        .WVALID_M3 (WVALID_M3),
        .BID_M3 (BID_M3),
        .BRESP_M3 (BRESP_M3),
        .BVALID_M3 (BVALID_M3),
        .BREADY_M3 (BREADY_M3),
        .AWREADY_M4 (AWREADY_M4),
        .AWID_M4 (AWID_M4),
        .AWADDR_M4 (AWADDR_M4),
        .AWLEN_M4 (AWLEN_M4),
        .AWSIZE_M4 (AWSIZE_M4),
        .AWBURST_M4 (AWBURST_M4),
        .AWVALID_M4 (AWVALID_M4),
        .WREADY_M4 (WREADY_M4),
        .WID_M4 (WID_M4),
        .WDATA_M4 (WDATA_M4),
        .WLAST_M4 (WLAST_M4),
        .WVALID_M4 (WVALID_M4),
        .BID_M4 (BID_M4),
        .BRESP_M4 (BRESP_M4),
        .BVALID_M4 (BVALID_M4),
        .BREADY_M4 (BREADY_M4),
        .AWREADY_M5 (AWREADY_M5),
        .AWID_M5 (AWID_M5),
        .AWADDR_M5 (AWADDR_M5),
        .AWLEN_M5 (AWLEN_M5),
        .AWSIZE_M5 (AWSIZE_M5),
        .AWBURST_M5 (AWBURST_M5),
        .AWVALID_M5 (AWVALID_M5),
        .WREADY_M5 (WREADY_M5),
        .WID_M5 (WID_M5),
        .WDATA_M5 (WDATA_M5),
        .WLAST_M5 (WLAST_M5),
        .WVALID_M5 (WVALID_M5),
        .BID_M5 (BID_M5),
        .BRESP_M5 (BRESP_M5),
        .BVALID_M5 (BVALID_M5),
        .BREADY_M5 (BREADY_M5),
        .AWREADY_M6 (AWREADY_M6),
        .AWID_M6 (AWID_M6),
        .AWADDR_M6 (AWADDR_M6),
        .AWLEN_M6 (AWLEN_M6),
        .AWSIZE_M6 (AWSIZE_M6),
        .AWBURST_M6 (AWBURST_M6),
        .AWVALID_M6 (AWVALID_M6),
        .WREADY_M6 (WREADY_M6),
        .WID_M6 (WID_M6),
        .WDATA_M6 (WDATA_M6),
        .WLAST_M6 (WLAST_M6),
        .WVALID_M6 (WVALID_M6),
        .BID_M6 (BID_M6),
        .BRESP_M6 (BRESP_M6),
        .BVALID_M6 (BVALID_M6),
        .BREADY_M6 (BREADY_M6),
        .AWREADY_M7 (AWREADY_M7),
        .AWID_M7 (AWID_M7),
        .AWADDR_M7 (AWADDR_M7),
        .AWLEN_M7 (AWLEN_M7),
        .AWSIZE_M7 (AWSIZE_M7),
        .AWBURST_M7 (AWBURST_M7),
        .AWVALID_M7 (AWVALID_M7),
        .WREADY_M7 (WREADY_M7),
        .WID_M7 (WID_M7),
        .WDATA_M7 (WDATA_M7),
        .WLAST_M7 (WLAST_M7),
        .WVALID_M7 (WVALID_M7),
        .BID_M7 (BID_M7),
        .BRESP_M7 (BRESP_M7),
        .BVALID_M7 (BVALID_M7),
        .BREADY_M7 (BREADY_M7),
        .AWREADY_M8 (AWREADY_M8),
        .AWID_M8 (AWID_M8),
        .AWADDR_M8 (AWADDR_M8),
        .AWLEN_M8 (AWLEN_M8),
        .AWSIZE_M8 (AWSIZE_M8),
        .AWBURST_M8 (AWBURST_M8),
        .AWVALID_M8 (AWVALID_M8),
        .WREADY_M8 (WREADY_M8),
        .WID_M8 (WID_M8),
        .WDATA_M8 (WDATA_M8),
        .WLAST_M8 (WLAST_M8),
        .WVALID_M8 (WVALID_M8),
        .BID_M8 (BID_M8),
        .BRESP_M8 (BRESP_M8),
        .BVALID_M8 (BVALID_M8),
        .BREADY_M8 (BREADY_M8),
        .AWREADY_M9 (AWREADY_M9),
        .AWID_M9 (AWID_M9),
        .AWADDR_M9 (AWADDR_M9),
        .AWLEN_M9 (AWLEN_M9),
        .AWSIZE_M9 (AWSIZE_M9),
        .AWBURST_M9 (AWBURST_M9),
        .AWVALID_M9 (AWVALID_M9),
        .WREADY_M9 (WREADY_M9),
        .WID_M9 (WID_M9),
        .WDATA_M9 (WDATA_M9),
        .WLAST_M9 (WLAST_M9),
        .WVALID_M9 (WVALID_M9),
        .BID_M9 (BID_M9),
        .BRESP_M9 (BRESP_M9),
        .BVALID_M9 (BVALID_M9),
        .BREADY_M9 (BREADY_M9),
        .AWREADY_M10 (AWREADY_M10),
        .AWID_M10 (AWID_M10),
        .AWADDR_M10 (AWADDR_M10),
        .AWLEN_M10 (AWLEN_M10),
        .AWSIZE_M10 (AWSIZE_M10),
        .AWBURST_M10 (AWBURST_M10),
        .AWVALID_M10 (AWVALID_M10),
        .WREADY_M10 (WREADY_M10),
        .WID_M10 (WID_M10),
        .WDATA_M10 (WDATA_M10),
        .WLAST_M10 (WLAST_M10),
        .WVALID_M10 (WVALID_M10),
        .BID_M10 (BID_M10),
        .BRESP_M10 (BRESP_M10),
        .BVALID_M10 (BVALID_M10),
        .BREADY_M10 (BREADY_M10),
        .AWREADY_M11 (AWREADY_M11),
        .AWID_M11 (AWID_M11),
        .AWADDR_M11 (AWADDR_M11),
        .AWLEN_M11 (AWLEN_M11),
        .AWSIZE_M11 (AWSIZE_M11),
        .AWBURST_M11 (AWBURST_M11),
        .AWVALID_M11 (AWVALID_M11),
        .WREADY_M11 (WREADY_M11),
        .WID_M11 (WID_M11),
        .WDATA_M11 (WDATA_M11),
        .WLAST_M11 (WLAST_M11),
        .WVALID_M11 (WVALID_M11),
        .BID_M11 (BID_M11),
        .BRESP_M11 (BRESP_M11),
        .BVALID_M11 (BVALID_M11),
        .BREADY_M11 (BREADY_M11),
        .AWREADY_M12 (AWREADY_M12),
        .AWID_M12 (AWID_M12),
        .AWADDR_M12 (AWADDR_M12),
        .AWLEN_M12 (AWLEN_M12),
        .AWSIZE_M12 (AWSIZE_M12),
        .AWBURST_M12 (AWBURST_M12),
        .AWVALID_M12 (AWVALID_M12),
        .WREADY_M12 (WREADY_M12),
        .WID_M12 (WID_M12),
        .WDATA_M12 (WDATA_M12),
        .WLAST_M12 (WLAST_M12),
        .WVALID_M12 (WVALID_M12),
        .BID_M12 (BID_M12),
        .BRESP_M12 (BRESP_M12),
        .BVALID_M12 (BVALID_M12),
        .BREADY_M12 (BREADY_M12),
        .AWREADY_M13 (AWREADY_M13),
        .AWID_M13 (AWID_M13),
        .AWADDR_M13 (AWADDR_M13),
        .AWLEN_M13 (AWLEN_M13),
        .AWSIZE_M13 (AWSIZE_M13),
        .AWBURST_M13 (AWBURST_M13),
        .AWVALID_M13 (AWVALID_M13),
        .WREADY_M13 (WREADY_M13),
        .WID_M13 (WID_M13),
        .WDATA_M13 (WDATA_M13),
        .WLAST_M13 (WLAST_M13),
        .WVALID_M13 (WVALID_M13),
        .BID_M13 (BID_M13),
        .BRESP_M13 (BRESP_M13),
        .BVALID_M13 (BVALID_M13),
        .BREADY_M13 (BREADY_M13),
        .AWREADY_M14 (AWREADY_M14),
        .AWID_M14 (AWID_M14),
        .AWADDR_M14 (AWADDR_M14),
        .AWLEN_M14 (AWLEN_M14),
        .AWSIZE_M14 (AWSIZE_M14),
        .AWBURST_M14 (AWBURST_M14),
        .AWVALID_M14 (AWVALID_M14),
        .WREADY_M14 (WREADY_M14),
        .WID_M14 (WID_M14),
        .WDATA_M14 (WDATA_M14),
        .WLAST_M14 (WLAST_M14),
        .WVALID_M14 (WVALID_M14),
        .BID_M14 (BID_M14),
        .BRESP_M14 (BRESP_M14),
        .BVALID_M14 (BVALID_M14),
        .BREADY_M14 (BREADY_M14),
        .AWREADY_M15 (AWREADY_M15),
        .AWID_M15 (AWID_M15),
        .AWADDR_M15 (AWADDR_M15),
        .AWLEN_M15 (AWLEN_M15),
        .AWSIZE_M15 (AWSIZE_M15),
        .AWBURST_M15 (AWBURST_M15),
        .AWVALID_M15 (AWVALID_M15),
        .WREADY_M15 (WREADY_M15),
        .WID_M15 (WID_M15),
        .WDATA_M15 (WDATA_M15),
        .WLAST_M15 (WLAST_M15),
        .WVALID_M15 (WVALID_M15),
        .BID_M15 (BID_M15),
        .BRESP_M15 (BRESP_M15),
        .BVALID_M15 (BVALID_M15),
        .BREADY_M15 (BREADY_M15),
        .AWID_S1 (AWID_S1),
        .AWADDR_S1 (AWADDR_S1),
        .AWLEN_S1 (AWLEN_S1),
        .AWSIZE_S1 (AWSIZE_S1),
        .AWBURST_S1 (AWBURST_S1),
        .AWVALID_S1 (AWVALID_S1),
        .AWREADY_S1 (AWREADY_S1),
        .WID_S1 (WID_S1),
        .WDATA_S1 (WDATA_S1),
        .WLAST_S1 (WLAST_S1),
        .WVALID_S1 (WVALID_S1),
        .WREADY_S1 (WREADY_S1),
        .BREADY_S1 (BREADY_S1),
        .BID_S1 (BID_S1),
        .BRESP_S1 (BRESP_S1),
        .BVALID_S1 (BVALID_S1),
        .AWID_S2 (AWID_S2),
        .AWADDR_S2 (AWADDR_S2),
        .AWLEN_S2 (AWLEN_S2),
        .AWSIZE_S2 (AWSIZE_S2),
        .AWBURST_S2 (AWBURST_S2),
        .AWVALID_S2 (AWVALID_S2),
        .AWREADY_S2 (AWREADY_S2),
        .WID_S2 (WID_S2),
        .WDATA_S2 (WDATA_S2),
        .WLAST_S2 (WLAST_S2),
        .WVALID_S2 (WVALID_S2),
        .WREADY_S2 (WREADY_S2),
        .BREADY_S2 (BREADY_S2),
        .BID_S2 (BID_S2),
        .BRESP_S2 (BRESP_S2),
        .BVALID_S2 (BVALID_S2),
        .AWID_S3 (AWID_S3),
        .AWADDR_S3 (AWADDR_S3),
        .AWLEN_S3 (AWLEN_S3),
        .AWSIZE_S3 (AWSIZE_S3),
        .AWBURST_S3 (AWBURST_S3),
        .AWVALID_S3 (AWVALID_S3),
        .AWREADY_S3 (AWREADY_S3),
        .WID_S3 (WID_S3),
        .WDATA_S3 (WDATA_S3),
        .WLAST_S3 (WLAST_S3),
        .WVALID_S3 (WVALID_S3),
        .WREADY_S3 (WREADY_S3),
        .BREADY_S3 (BREADY_S3),
        .BID_S3 (BID_S3),
        .BRESP_S3 (BRESP_S3),
        .BVALID_S3 (BVALID_S3),
        .AWID_S4 (AWID_S4),
        .AWADDR_S4 (AWADDR_S4),
        .AWLEN_S4 (AWLEN_S4),
        .AWSIZE_S4 (AWSIZE_S4),
        .AWBURST_S4 (AWBURST_S4),
        .AWVALID_S4 (AWVALID_S4),
        .AWREADY_S4 (AWREADY_S4),
        .WID_S4 (WID_S4),
        .WDATA_S4 (WDATA_S4),
        .WLAST_S4 (WLAST_S4),
        .WVALID_S4 (WVALID_S4),
        .WREADY_S4 (WREADY_S4),
        .BREADY_S4 (BREADY_S4),
        .BID_S4 (BID_S4),
        .BRESP_S4 (BRESP_S4),
        .BVALID_S4 (BVALID_S4),
        .ARREADY_M1 (ARREADY_M1),
        .ARID_M1 (ARID_M1),
        .ARADDR_M1 (ARADDR_M1),
        .ARSIZE_M1 (ARSIZE_M1),
        .ARBURST_M1 (ARBURST_M1),
        .ARLEN_M1 (ARLEN_M1),
        .ARVALID_M1 (ARVALID_M1),
        .RID_M1 (RID_M1),
        .RLAST_M1 (RLAST_M1),
        .RVALID_M1 (RVALID_M1),
        .RRESP_M1 (RRESP_M1),
        .RDATA_M1 (RDATA_M1),
        .RREADY_M1 (RREADY_M1),
        .ARREADY_M2 (ARREADY_M2),
        .ARID_M2 (ARID_M2),
        .ARADDR_M2 (ARADDR_M2),
        .ARSIZE_M2 (ARSIZE_M2),
        .ARBURST_M2 (ARBURST_M2),
        .ARLEN_M2 (ARLEN_M2),
        .ARVALID_M2 (ARVALID_M2),
        .RID_M2 (RID_M2),
        .RLAST_M2 (RLAST_M2),
        .RVALID_M2 (RVALID_M2),
        .RRESP_M2 (RRESP_M2),
        .RDATA_M2 (RDATA_M2),
        .RREADY_M2 (RREADY_M2),
        .ARREADY_M3 (ARREADY_M3),
        .ARID_M3 (ARID_M3),
        .ARADDR_M3 (ARADDR_M3),
        .ARSIZE_M3 (ARSIZE_M3),
        .ARBURST_M3 (ARBURST_M3),
        .ARLEN_M3 (ARLEN_M3),
        .ARVALID_M3 (ARVALID_M3),
        .RID_M3 (RID_M3),
        .RLAST_M3 (RLAST_M3),
        .RVALID_M3 (RVALID_M3),
        .RRESP_M3 (RRESP_M3),
        .RDATA_M3 (RDATA_M3),
        .RREADY_M3 (RREADY_M3),
        .ARREADY_M4 (ARREADY_M4),
        .ARID_M4 (ARID_M4),
        .ARADDR_M4 (ARADDR_M4),
        .ARSIZE_M4 (ARSIZE_M4),
        .ARBURST_M4 (ARBURST_M4),
        .ARLEN_M4 (ARLEN_M4),
        .ARVALID_M4 (ARVALID_M4),
        .RID_M4 (RID_M4),
        .RLAST_M4 (RLAST_M4),
        .RVALID_M4 (RVALID_M4),
        .RRESP_M4 (RRESP_M4),
        .RDATA_M4 (RDATA_M4),
        .RREADY_M4 (RREADY_M4),
        .ARREADY_M5 (ARREADY_M5),
        .ARID_M5 (ARID_M5),
        .ARADDR_M5 (ARADDR_M5),
        .ARSIZE_M5 (ARSIZE_M5),
        .ARBURST_M5 (ARBURST_M5),
        .ARLEN_M5 (ARLEN_M5),
        .ARVALID_M5 (ARVALID_M5),
        .RID_M5 (RID_M5),
        .RLAST_M5 (RLAST_M5),
        .RVALID_M5 (RVALID_M5),
        .RRESP_M5 (RRESP_M5),
        .RDATA_M5 (RDATA_M5),
        .RREADY_M5 (RREADY_M5),
        .ARREADY_M6 (ARREADY_M6),
        .ARID_M6 (ARID_M6),
        .ARADDR_M6 (ARADDR_M6),
        .ARSIZE_M6 (ARSIZE_M6),
        .ARBURST_M6 (ARBURST_M6),
        .ARLEN_M6 (ARLEN_M6),
        .ARVALID_M6 (ARVALID_M6),
        .RID_M6 (RID_M6),
        .RLAST_M6 (RLAST_M6),
        .RVALID_M6 (RVALID_M6),
        .RRESP_M6 (RRESP_M6),
        .RDATA_M6 (RDATA_M6),
        .RREADY_M6 (RREADY_M6),
        .ARREADY_M7 (ARREADY_M7),
        .ARID_M7 (ARID_M7),
        .ARADDR_M7 (ARADDR_M7),
        .ARSIZE_M7 (ARSIZE_M7),
        .ARBURST_M7 (ARBURST_M7),
        .ARLEN_M7 (ARLEN_M7),
        .ARVALID_M7 (ARVALID_M7),
        .RID_M7 (RID_M7),
        .RLAST_M7 (RLAST_M7),
        .RVALID_M7 (RVALID_M7),
        .RRESP_M7 (RRESP_M7),
        .RDATA_M7 (RDATA_M7),
        .RREADY_M7 (RREADY_M7),
        .ARREADY_M8 (ARREADY_M8),
        .ARID_M8 (ARID_M8),
        .ARADDR_M8 (ARADDR_M8),
        .ARSIZE_M8 (ARSIZE_M8),
        .ARBURST_M8 (ARBURST_M8),
        .ARLEN_M8 (ARLEN_M8),
        .ARVALID_M8 (ARVALID_M8),
        .RID_M8 (RID_M8),
        .RLAST_M8 (RLAST_M8),
        .RVALID_M8 (RVALID_M8),
        .RRESP_M8 (RRESP_M8),
        .RDATA_M8 (RDATA_M8),
        .RREADY_M8 (RREADY_M8),
        .ARREADY_M9 (ARREADY_M9),
        .ARID_M9 (ARID_M9),
        .ARADDR_M9 (ARADDR_M9),
        .ARSIZE_M9 (ARSIZE_M9),
        .ARBURST_M9 (ARBURST_M9),
        .ARLEN_M9 (ARLEN_M9),
        .ARVALID_M9 (ARVALID_M9),
        .RID_M9 (RID_M9),
        .RLAST_M9 (RLAST_M9),
        .RVALID_M9 (RVALID_M9),
        .RRESP_M9 (RRESP_M9),
        .RDATA_M9 (RDATA_M9),
        .RREADY_M9 (RREADY_M9),
        .ARREADY_M10 (ARREADY_M10),
        .ARID_M10 (ARID_M10),
        .ARADDR_M10 (ARADDR_M10),
        .ARSIZE_M10 (ARSIZE_M10),
        .ARBURST_M10 (ARBURST_M10),
        .ARLEN_M10 (ARLEN_M10),
        .ARVALID_M10 (ARVALID_M10),
        .RID_M10 (RID_M10),
        .RLAST_M10 (RLAST_M10),
        .RVALID_M10 (RVALID_M10),
        .RRESP_M10 (RRESP_M10),
        .RDATA_M10 (RDATA_M10),
        .RREADY_M10 (RREADY_M10),
        .ARREADY_M11 (ARREADY_M11),
        .ARID_M11 (ARID_M11),
        .ARADDR_M11 (ARADDR_M11),
        .ARSIZE_M11 (ARSIZE_M11),
        .ARBURST_M11 (ARBURST_M11),
        .ARLEN_M11 (ARLEN_M11),
        .ARVALID_M11 (ARVALID_M11),
        .RID_M11 (RID_M11),
        .RLAST_M11 (RLAST_M11),
        .RVALID_M11 (RVALID_M11),
        .RRESP_M11 (RRESP_M11),
        .RDATA_M11 (RDATA_M11),
        .RREADY_M11 (RREADY_M11),
        .ARREADY_M12 (ARREADY_M12),
        .ARID_M12 (ARID_M12),
        .ARADDR_M12 (ARADDR_M12),
        .ARSIZE_M12 (ARSIZE_M12),
        .ARBURST_M12 (ARBURST_M12),
        .ARLEN_M12 (ARLEN_M12),
        .ARVALID_M12 (ARVALID_M12),
        .RID_M12 (RID_M12),
        .RLAST_M12 (RLAST_M12),
        .RVALID_M12 (RVALID_M12),
        .RRESP_M12 (RRESP_M12),
        .RDATA_M12 (RDATA_M12),
        .RREADY_M12 (RREADY_M12),
        .ARREADY_M13 (ARREADY_M13),
        .ARID_M13 (ARID_M13),
        .ARADDR_M13 (ARADDR_M13),
        .ARSIZE_M13 (ARSIZE_M13),
        .ARBURST_M13 (ARBURST_M13),
        .ARLEN_M13 (ARLEN_M13),
        .ARVALID_M13 (ARVALID_M13),
        .RID_M13 (RID_M13),
        .RLAST_M13 (RLAST_M13),
        .RVALID_M13 (RVALID_M13),
        .RRESP_M13 (RRESP_M13),
        .RDATA_M13 (RDATA_M13),
        .RREADY_M13 (RREADY_M13),
        .ARREADY_M14 (ARREADY_M14),
        .ARID_M14 (ARID_M14),
        .ARADDR_M14 (ARADDR_M14),
        .ARSIZE_M14 (ARSIZE_M14),
        .ARBURST_M14 (ARBURST_M14),
        .ARLEN_M14 (ARLEN_M14),
        .ARVALID_M14 (ARVALID_M14),
        .RID_M14 (RID_M14),
        .RLAST_M14 (RLAST_M14),
        .RVALID_M14 (RVALID_M14),
        .RRESP_M14 (RRESP_M14),
        .RDATA_M14 (RDATA_M14),
        .RREADY_M14 (RREADY_M14),
        .ARREADY_M15 (ARREADY_M15),
        .ARID_M15 (ARID_M15),
        .ARADDR_M15 (ARADDR_M15),
        .ARSIZE_M15 (ARSIZE_M15),
        .ARBURST_M15 (ARBURST_M15),
        .ARLEN_M15 (ARLEN_M15),
        .ARVALID_M15 (ARVALID_M15),
        .RID_M15 (RID_M15),
        .RLAST_M15 (RLAST_M15),
        .RVALID_M15 (RVALID_M15),
        .RRESP_M15 (RRESP_M15),
        .RDATA_M15 (RDATA_M15),
        .RREADY_M15 (RREADY_M15),
        .ARREADY_S1 (ARREADY_S1),
        .ARID_S1 (ARID_S1),
        .ARADDR_S1 (ARADDR_S1),
        .ARSIZE_S1 (ARSIZE_S1),
        .ARBURST_S1 (ARBURST_S1),
        .ARLEN_S1 (ARLEN_S1),
        .ARVALID_S1 (ARVALID_S1),
        .RID_S1 (RID_S1),
        .RLAST_S1 (RLAST_S1),
        .RVALID_S1 (RVALID_S1),
        .RRESP_S1 (RRESP_S1),
        .RDATA_S1 (RDATA_S1),
        .RREADY_S1 (RREADY_S1),
        .ARREADY_S2 (ARREADY_S2),
        .ARID_S2 (ARID_S2),
        .ARADDR_S2 (ARADDR_S2),
        .ARSIZE_S2 (ARSIZE_S2),
        .ARBURST_S2 (ARBURST_S2),
        .ARLEN_S2 (ARLEN_S2),
        .ARVALID_S2 (ARVALID_S2),
        .RID_S2 (RID_S2),
        .RLAST_S2 (RLAST_S2),
        .RVALID_S2 (RVALID_S2),
        .RRESP_S2 (RRESP_S2),
        .RDATA_S2 (RDATA_S2),
        .RREADY_S2 (RREADY_S2),
        .ARREADY_S3 (ARREADY_S3),
        .ARID_S3 (ARID_S3),
        .ARADDR_S3 (ARADDR_S3),
        .ARSIZE_S3 (ARSIZE_S3),
        .ARBURST_S3 (ARBURST_S3),
        .ARLEN_S3 (ARLEN_S3),
        .ARVALID_S3 (ARVALID_S3),
        .RID_S3 (RID_S3),
        .RLAST_S3 (RLAST_S3),
        .RVALID_S3 (RVALID_S3),
        .RRESP_S3 (RRESP_S3),
        .RDATA_S3 (RDATA_S3),
        .RREADY_S3 (RREADY_S3),
        .ARREADY_S4 (ARREADY_S4),
        .ARID_S4 (ARID_S4),
        .ARADDR_S4 (ARADDR_S4),
        .ARSIZE_S4 (ARSIZE_S4),
        .ARBURST_S4 (ARBURST_S4),
        .ARLEN_S4 (ARLEN_S4),
        .ARVALID_S4 (ARVALID_S4),
        .RID_S4 (RID_S4),
        .RLAST_S4 (RLAST_S4),
        .RVALID_S4 (RVALID_S4),
        .RDATA_S4 (RDATA_S4),
        .RRESP_S4 (RRESP_S4),
        .RREADY_S4 (RREADY_S4)
    );


    task automatic axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            AWID_M1    = 4'd1;
            AWADDR_M1  = addr;
            AWLEN_M1   = 4'd0;
            AWSIZE_M1  = 3'd2;
            AWBURST_M1 = 2'b01;
            AWVALID_M1 = 1'b1;
            while (!AWREADY_M1) @(posedge clk);
            @(posedge clk);
            AWVALID_M1 = 1'b0;

            WID_M1    = 4'd1;
            WDATA_M1  = data;
            WLAST_M1  = 1'b1;
            WVALID_M1 = 1'b1;
            while (!WREADY_M1) @(posedge clk);
            @(posedge clk);
            WVALID_M1 = 1'b0;
            WLAST_M1  = 1'b0;

            BREADY_M1 = 1'b1;
            while (!BVALID_M1) @(posedge clk);
            @(posedge clk);
            BREADY_M1 = 1'b0;
        end
    endtask

    task automatic axi_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            ARID_M1    = 4'd1;
            ARADDR_M1  = addr;
            ARSIZE_M1  = 3'd2;
            ARBURST_M1 = 2'b01;
            ARLEN_M1   = 4'd0;
            ARVALID_M1 = 1'b1;
            while (!ARREADY_M1) @(posedge clk);
            @(posedge clk);
            ARVALID_M1 = 1'b0;

            RREADY_M1 = 1'b1;
            while (!RVALID_M1) @(posedge clk);
            data = RDATA_M1;
            @(posedge clk);
            RREADY_M1 = 1'b0;
        end
    endtask

    reg [31:0] rd_data;
    reg [31:0] status;
    reg [31:0] cipher0, cipher1, cipher2, cipher3;
    reg [31:0] dec0, dec1, dec2, dec3;
    integer errors;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        errors = 0;
        reset = 1'b0;

        AWID_M1 = 0; AWADDR_M1 = 0; AWLEN_M1 = 0; AWSIZE_M1 = 0;
        AWBURST_M1 = 0; AWVALID_M1 = 0;
        WID_M1 = 0; WDATA_M1 = 0; WLAST_M1 = 0; WVALID_M1 = 0;
        BREADY_M1 = 0;
        ARID_M1 = 0; ARADDR_M1 = 0; ARSIZE_M1 = 0; ARBURST_M1 = 0;
        ARLEN_M1 = 0; ARVALID_M1 = 0; RREADY_M1 = 0;

`ifdef WAVES
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, axi_aes_interconnect_top);
`endif

        repeat (5) @(posedge clk);
        reset = 1'b1;
        repeat (2) @(posedge clk);

        $display("==============================================");
        $display(" AXI INTERCONNECT -> AES ENCRYPT + DECRYPT TEST START");
        $display("==============================================");

        // ------------------------------------------------------------
        // AES-128 test vector
        // Key       = 000102030405060708090a0b0c0d0e0f
        // Plaintext = 00112233445566778899aabbccddeeff
        // Expected ciphertext = 69c4e0d86a7b0430d8cdb78070b4c55a
        // S1 base address = 0x2000_0000
        // ------------------------------------------------------------

        $display("Writing AES-128 key...");
        axi_write(32'h2000_0000, 32'h0c0d0e0f);
        axi_write(32'h2000_0004, 32'h08090a0b);
        axi_write(32'h2000_0008, 32'h04050607);
        axi_write(32'h2000_000c, 32'h00010203);

        $display("Writing plaintext...");
        axi_write(32'h2000_0010, 32'hccddeeff);
        axi_write(32'h2000_0014, 32'h8899aabb);
        axi_write(32'h2000_0018, 32'h44556677);
        axi_write(32'h2000_001c, 32'h00112233);

        // ------------------------------------------------------------
        // ENCRYPTION
        // ------------------------------------------------------------
        $display("Starting AES encryption...");
        axi_write(32'h2000_0020, 32'h00000001);

        status = 32'h0;
        begin : wait_enc_done
            integer timeout;
            timeout = 0;

            while (timeout < 200) begin
                axi_read(32'h2000_0024, status);

                $display("[%0t] STATUS = 0x%08h | ENC_DONE=%0d DEC_DONE=%0d",
                         $time, status, status[0], status[1]);

                if (status[0])
                    disable wait_enc_done;

                timeout = timeout + 1;
            end

            if (timeout >= 200) begin
                $display("FAIL: AES encryption timeout.");
                errors = errors + 1;
            end
        end

        // Read encrypted ciphertext
        axi_read(32'h2000_0028, cipher0);
        axi_read(32'h2000_002c, cipher1);
        axi_read(32'h2000_0030, cipher2);
        axi_read(32'h2000_0034, cipher3);

        $display("Encryption ciphertext = %08h_%08h_%08h_%08h",
                 cipher3, cipher2, cipher1, cipher0);

        if ({cipher3, cipher2, cipher1, cipher0} !==
            128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("FAIL: Encryption ciphertext mismatch.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: AES encryption ciphertext is correct.");
        end

        // ------------------------------------------------------------
        // DECRYPTION
        // Feed encryption ciphertext back into DATA_IN.
        // ------------------------------------------------------------
        $display("Writing encryption ciphertext to AES DATA_IN for decryption...");

        axi_write(32'h2000_0010, cipher0);
        axi_write(32'h2000_0014, cipher1);
        axi_write(32'h2000_0018, cipher2);
        axi_write(32'h2000_001c, cipher3);

        $display("Starting AES decryption...");
        axi_write(32'h2000_0020, 32'h00000002);

        status = 32'h0;
        begin : wait_dec_done
            integer timeout;
            timeout = 0;

            while (timeout < 200) begin
                axi_read(32'h2000_0024, status);

                $display("[%0t] STATUS = 0x%08h | ENC_DONE=%0d DEC_DONE=%0d",
                         $time, status, status[0], status[1]);

                if (status[1])
                    disable wait_dec_done;

                timeout = timeout + 1;
            end

            if (timeout >= 200) begin
                $display("FAIL: AES decryption timeout.");
                errors = errors + 1;
            end
        end

        // Read decrypted plaintext
        axi_read(32'h2000_0028, dec0);
        axi_read(32'h2000_002c, dec1);
        axi_read(32'h2000_0030, dec2);
        axi_read(32'h2000_0034, dec3);

        $display("Decrypted plaintext   = %08h_%08h_%08h_%08h",
                 dec3, dec2, dec1, dec0);

        if ({dec3, dec2, dec1, dec0} !==
            128'h00112233445566778899aabbccddeeff) begin
            $display("FAIL: AES decryption did not restore the original plaintext.");
            errors = errors + 1;
        end
        else begin
            $display("PASS: AES decryption restored the original plaintext.");
        end

        // Final status check
        axi_read(32'h2000_0024, status);
        $display("Final STATUS = 0x%08h | ENC_DONE=%0d DEC_DONE=%0d",
                 status, status[0], status[1]);

        if (errors == 0)
            $display("PASS: AXI Interconnect -> AES encryption + decryption test completed with 0 errors.");
        else
            $display("FAIL: AXI Interconnect -> AES test completed with %0d errors.", errors);

        $display("==============================================");
        $finish;
    end

endmodule
