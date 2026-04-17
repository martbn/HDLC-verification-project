//////////////////////////////////////////////////
// Title:   testPr_hdlc
// Author:
// Date:
//////////////////////////////////////////////////

program testPr_hdlc(
  in_hdlc uin_hdlc
);

  int TbErrorCnt;
  bit framesize_checked_normal_seen;
  bit framesize_checked_overflow_seen;

  // Register addresses
  localparam logic [2:0] TXSC   = 3'b000; // TX Status/Control
  localparam logic [2:0] TXBUFF = 3'b001; // TX Data Buffer
  localparam logic [2:0] RXSC   = 3'b010; // RX Status/Control
  localparam logic [2:0] RXBUFF = 3'b011; // RX Data Buffer
  localparam logic [2:0] RXLEN  = 3'b100; // RX Frame Length

  // Run switches
  localparam bit RUN_EXTENDED_STIMULUS = 1'b0;
  localparam bit RUN_COVERAGE_EDGE_STIMULUS = 1'b0;
  localparam bit RUN_HIGH_VOLUME_STIMULUS = 1'b0;
  localparam int HIGH_VOLUME_REPEATS = 2;

  // Wait limits
  localparam int WAIT_MEDIUM_CYCLES = 1200;
  localparam int WAIT_LONG_CYCLES = 2500;

`include "testPr_immediate_checks.svh"
`include "testPr_stimulus_tasks.svh"

  initial begin
    $display("*************************************************************");
    $display("%t - Starting Test Program", $time);
    $display("*************************************************************");

    Init();

    RunDirectedConcurrentStimulus();

    if (RUN_EXTENDED_STIMULUS)
      RunExtendedStimulus();

    if (RUN_COVERAGE_EDGE_STIMULUS)
      RunCoverageEdgeStimulus();

    if (RUN_HIGH_VOLUME_STIMULUS)
      RunHighVolumeStimulus(HIGH_VOLUME_REPEATS);

    $display("*************************************************************");
    $display("%t - Finishing Test Program", $time);
    $display("*************************************************************");
    $stop;
  end

  final begin
    if (!framesize_checked_normal_seen) begin
      $error("Spec 14 stimulus missing: normal RxLen check was never exercised.");
      TbErrorCnt++;
    end

    if (!framesize_checked_overflow_seen) begin
      $error("Spec 14 stimulus missing: overflow RxLen check (expect 126) was never exercised.");
      TbErrorCnt++;
    end

    $display("*********************************");
    $display("*                               *");
    $display("* \tAssertion Errors: %0d\t  *", TbErrorCnt + uin_hdlc.ErrCntAssertions);
    $display("*                               *");
    $display("*********************************");
  end

endprogram
