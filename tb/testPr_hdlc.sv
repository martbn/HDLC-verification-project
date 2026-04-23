
/***********************************************************************
 *                          Main test program                          *
 ***********************************************************************/

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

  // Simple stimulus control
  localparam int RANDOM_STIM_REPEATS = 3;

  // Wait limits
  localparam int WAIT_MEDIUM_CYCLES = 1200;
  localparam int WAIT_LONG_CYCLES = 2500;

  // Include stimulus and check tasks
`include "testPr_immediate_checks.svh"
`include "testPr_stimulus_tasks.svh"

  initial begin
    $display("*************************************************************");
    $display("%t - Starting Test Program", $time);
    $display("*************************************************************");

    Init();

    // 1) Basic directed TX/RX stimulus
    RunBasicStimulus();
    ResetDutPhase();

    // 2) Targeted edge/corner cases
    RunTargetedStimulus();
    ResetDutPhase();

    // 3) Small random block
    RunRandomStimulus(RANDOM_STIM_REPEATS);
    ResetDutPhase();

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
