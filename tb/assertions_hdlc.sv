
/***********************************************************************
 *                Concurrent assertion file                            *
 ***********************************************************************/

module assertions_hdlc (
  output int   ErrCntAssertions,
  input  logic Clk,
  input  logic Rst,
  input  logic Tx,
  input  logic TxD,
  input  logic Tx_Done,
  input  logic Tx_Full,
  input  logic Tx_WrBuff,
  input  logic Tx_AbortFrame,
  input  logic Tx_ValidFrame,
  input  logic Tx_AbortedTrans,
  input  logic Rx,
  input  logic Rx_FlagDetect,
  input  logic Rx_ValidFrame,
  input  logic Rx_StartZeroDetect,
  input  logic Rx_AbortDetect,
  input  logic Rx_AbortSignal,
  input  logic Rx_NewByte,
  input  logic RxD,
  input  logic ZeroDetect,
  input  logic Rx_EoF,
  input  logic Rx_Ready,
  input  logic Rx_RdBuff,
  input  logic Rx_FrameError,
  input  logic Rx_FCSerr,
  input  logic Rx_Drop,
  input  logic [7:0] Rx_FrameSize,
  input  logic Rx_Overflow,
  input  logic Rx_WrBuff
);

  logic [8:0] rx_write_count_in_frame;
  logic [7:0] rx_read_count_while_ready;
  logic [7:0] tx_write_count;
  logic tx_done_seen_in_frame;

  initial begin
    ErrCntAssertions = 0;
  end

  /********************************************
   *                Sequences                 *
   ********************************************/

  // Common RX HDLC flag pattern: 01111110
  sequence seq_rx_flag;
    !Rx ##1 Rx [*6] ##1 !Rx;
  endsequence

  // Common TX HDLC flag pattern: 01111110
  sequence seq_tx_flag;
    !Tx ##1 Tx [*6] ##1 !Tx;
  endsequence

  // Stable TX idle observation window: no active frame/abort and line is 11111111.
  sequence seq_tx_idle_stable;
    !Tx_ValidFrame && !Tx_AbortedTrans &&
    (&{Tx, $past(Tx,1), $past(Tx,2), $past(Tx,3),
    $past(Tx,4), $past(Tx,5), $past(Tx,6), $past(Tx,7)});
  endsequence

  // Stable RX idle observation window: no valid frame and received line is 11111111.
  sequence seq_rx_idle_stable;
    !Rx_ValidFrame &&
    (&{Rx, $past(Rx,1), $past(Rx,2), $past(Rx,3),
    $past(Rx,4), $past(Rx,5), $past(Rx,6), $past(Rx,7)});
  endsequence

  // HDLC abort pattern on line (LSB first): 11111110 => 0, then seven 1s
  sequence seq_tx_abort_pattern;
    !Tx ##1 Tx [*7];
  endsequence

  // RX abort pattern on line (LSB first): 11111110 => 0, then seven 1s
  sequence seq_rx_abort_pattern;
    !Rx ##1 Rx [*7];
  endsequence

  // Abort request that occurs while TX frame handling is active.
  sequence seq_tx_abort_req_during_frame;
    $rose(Tx_AbortFrame) && (Tx_ValidFrame || $past(Tx_ValidFrame,1));
  endsequence

  // RX abort detected while frame reception is active.
  sequence seq_rx_abort_detect_during_frame;
    Rx_AbortDetect && Rx_ValidFrame;
  endsequence

  // TX frame active with enough history for safe $past() checks.
  sequence seq_tx_frame_active_for_zero_insert;
    Tx_ValidFrame && $past(Tx_ValidFrame,1) && $past(Tx_ValidFrame,2) && $past(Tx_ValidFrame,3) &&
    $past(Tx_ValidFrame,4) && $past(Tx_ValidFrame,5) && $past(Tx_ValidFrame,10);
  endsequence

  // TX data contains six consecutive ones (bit-stuffing failure pattern).
  sequence seq_tx_six_ones_window;
    TxD && $past(TxD,1) && $past(TxD,2) && $past(TxD,3) && $past(TxD,4) && $past(TxD,5);
  endsequence

  // Shared TX frame-complete event for end-flag and Tx_Done checks.
  sequence seq_tx_frame_end_non_abort;
    $fell(Tx_ValidFrame) && !Tx_AbortedTrans;
  endsequence

  // RX inserted-zero pattern 0111110 observed inside a valid frame.
  sequence seq_rx_inserted_zero_pattern;
    Rx_ValidFrame && !Rx_StartZeroDetect && !RxD && $past(RxD,1) &&
    $past(RxD,2) && $past(RxD,3) && $past(RxD,4) && $past(RxD,5);
  endsequence

  // RX valid frame ends without abort.
  sequence seq_rx_frame_complete_non_abort;
    $fell(Rx_ValidFrame) && !Rx_AbortSignal;
  endsequence

  // RX write strobe occurs after 128 bytes already received in current frame.
  sequence seq_rx_write_beyond_128;
    Rx_ValidFrame && Rx_WrBuff && (rx_write_count_in_frame >= 9'd128);
  endsequence

  // Current RX read consumes the last buffered byte.
  sequence seq_rx_ready_last_read;
    Rx_Ready && Rx_RdBuff && ((rx_read_count_while_ready + 8'd1) >= Rx_FrameSize);
  endsequence

  // any condition that should force Rx_FrameError.
  sequence seq_rx_frame_error_cause;
    (Rx_ValidFrame && Rx_FlagDetect && !Rx_NewByte) or Rx_FCSerr;
  endsequence

  // TX buffer has received at least 126 writes.
  sequence seq_tx_write_126_or_more;
    Tx_WrBuff && (tx_write_count >= 8'd125);
  endsequence

  /********************************************
   *                Properties                *
   ********************************************/

  // [Part A Concurrent Task 1] RX flag should be detected two cycles after pattern.
  property p_rx_flag_detect;
    @(posedge Clk)
      seq_rx_flag |-> ##2 Rx_FlagDetect;
  endproperty

  // [Task 5 | Spec 5] Start flag appears 2 cycles after Tx_ValidFrame rises:

  property p_tx_start_flag;
    @(posedge Clk) disable iff (!Rst)
      $rose(Tx_ValidFrame) |-> ##2 seq_tx_flag;
  endproperty

  // [Task 5 | Spec 5] End flag appears 1 cycle after Tx_ValidFrame falls:
  property p_tx_end_flag;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_frame_end_non_abort |-> ##1 seq_tx_flag;
  endproperty

  // [Task 6 | Spec 6] TX transparent transmission must not emit six consecutive ones.
  property p_tx_zero_insertion;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_frame_active_for_zero_insert |-> not seq_tx_six_ones_window;
  endproperty

  // [Task 6 | Spec 6] Inserted zero pattern on RX must be detected.
  property p_rx_zero_removal_detect;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_inserted_zero_pattern |-> ZeroDetect;
  endproperty

  // [Task 6 | Spec 6] Inserted-zero cycle must not be counted as a completed RX byte.
  property p_rx_zero_removal_no_new_byte;
    @(posedge Clk) disable iff (!Rst)
      (Rx_ValidFrame && ZeroDetect) |=> !Rx_NewByte;
  endproperty

  // [Task 7 | Spec 7] After observing TX idle pattern 11111111, line must stay high.
  property p_tx_idle_pattern;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_idle_stable |=> Tx;
  endproperty

  // [Task 7 | Spec 7] When RX sees idle pattern 11111111, no RX activity should occur.
  property p_rx_idle_pattern;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_idle_stable |-> (!Rx_FlagDetect && !Rx_NewByte && !ZeroDetect);
  endproperty

  // [Task 8 | Spec 8] Abort pattern appears after abort request.
  property p_tx_abort_pattern;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_abort_req_during_frame |=> ##3 seq_tx_abort_pattern;
  endproperty

  // [Task 8 | Spec 8] RX abort pattern observed on line must be detected.
  property p_rx_abort_pattern_detect;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_abort_pattern |-> ##2 Rx_AbortDetect;
  endproperty

  // [Task 9 | Spec 9] Tx_AbortedTrans asserts exactly 2 cycles after Tx_AbortFrame rises
  // due state transition into ABORT and output update in TxController.
  property p_tx_aborted_trans_asserted;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_abort_req_during_frame |-> ##2 Tx_AbortedTrans;
  endproperty

  // [Part A Concurrent Task 2] + [Task 10 | Spec 10] Abort detect during valid frame must raise Rx_AbortSignal.
  property p_rx_abort_signal_after_detect;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_abort_detect_during_frame |-> ##1 Rx_AbortSignal;
  endproperty

  // [Task 12 | Spec 12] Completed RX frame must generate EoF pulse.
  property p_rx_eof_after_frame_complete;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_frame_complete_non_abort |=> Rx_EoF;
  endproperty

  // [Task 13 | Spec 13] Receiving more than 128 bytes must assert Rx_Overflow.
  property p_rx_overflow_on_write_beyond_128;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_write_beyond_128 |-> Rx_Overflow;
  endproperty

  // [Task 15 | Spec 15] Rx_Ready stays high until the final buffer read, then drops next cycle.
  property p_rx_ready_lifecycle;
    @(posedge Clk) disable iff (!Rst)
      (Rx_RdBuff && Rx_Ready) |->
        (Rx_Ready [*0:$] ##0 seq_rx_ready_last_read ##1 !Rx_Ready);
  endproperty

  // [Task 15 | Spec 15] Completed non-aborted, non-error RX frame should make data readable.
  property p_rx_ready_assert_after_frame_complete;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_frame_complete_non_abort |-> ##[1:3] (Rx_Ready || Rx_FrameError);
  endproperty

  // [Task 15 | Spec 15] Last read while ready should clear ready on next cycle.
  property p_rx_ready_drop_after_last_read;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_ready_last_read |=> !Rx_Ready;
  endproperty

  // [Task 16 | Spec 16] Non-byte-aligned or FCS-error condition must raise Rx_FrameError.
  property p_rx_frame_error_on_error_cause;
    @(posedge Clk) disable iff (!Rst)
      seq_rx_frame_error_cause |-> ##[1:2] Rx_FrameError;
  endproperty

  // [Task 17 | Spec 17] Normal TX completion should assert Tx_Done.
  property p_tx_done_on_tx_complete;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_frame_end_non_abort |-> tx_done_seen_in_frame;
  endproperty

  // [Task 18 | Spec 18] After writing 126 or more bytes, Tx_Full should assert.
  property p_tx_full_after_126_writes;
    @(posedge Clk) disable iff (!Rst)
      seq_tx_write_126_or_more |-> ##[0:2] Tx_Full;
  endproperty

  /********************************************
   *                Assertions                *
   ********************************************/

  // Part A Concurrent Task 1
  ASSERT_RX_FLAG_DETECT: assert property (p_rx_flag_detect) else begin
    $error("Flag sequence did not generate Rx_FlagDetect.");
    ErrCntAssertions++;
  end

  //  Spec 5 TX start-of-frame flag generation.
  ASSERT_TX_START_FLAG: assert property (p_tx_start_flag) else begin
    $error("TX start flag (01111110) was not generated.");
    ErrCntAssertions++;
  end

  //  Spec 5 TX end-of-frame flag generation.
  ASSERT_TX_END_FLAG: assert property (p_tx_end_flag) else begin
    $error("TX end flag (01111110) was not generated.");
    ErrCntAssertions++;
  end

  // Spec 6 TX bit-stuffing behavior.
  ASSERT_TX_ZERO_INSERTION: assert property (p_tx_zero_insertion) else begin
    $error("TX zero insertion failed: detected six consecutive ones in TxD.");
    ErrCntAssertions++;
  end

  // Spec 6 RX inserted-zero detection behavior.
  ASSERT_RX_ZERO_REMOVAL_DETECT: assert property (p_rx_zero_removal_detect) else begin
    $error("RX zero removal failed: inserted zero pattern was not detected.");
    ErrCntAssertions++;
  end

  //  Spec 6 Inserted-zero cycles must not produce Rx_NewByte.
  ASSERT_RX_ZERO_REMOVAL_NO_NEW_BYTE: assert property (p_rx_zero_removal_no_new_byte) else begin
    $error("RX zero removal failed: Rx_NewByte asserted during inserted zero cycle.");
    ErrCntAssertions++;
  end

  //  Spec 7 TX idle line behavior.
  ASSERT_TX_IDLE_PATTERN: assert property (p_tx_idle_pattern) else begin
    $error("TX idle pattern failed: Tx is not high during idle.");
    ErrCntAssertions++;
  end

  // Spec 7 RX idle line behavior.
  ASSERT_RX_IDLE_PATTERN: assert property (p_rx_idle_pattern) else begin
    $error("RX idle check failed: activity detected while idle ones were received.");
    ErrCntAssertions++;
  end

  // Spec 8 TX abort line pattern.
  ASSERT_TX_ABORT_PATTERN: assert property (p_tx_abort_pattern) else begin
    $error("TX abort pattern (11111110, LSB first) was not generated.");
    ErrCntAssertions++;
  end

  //  Spec 8 RX abort pattern detection on line.
  ASSERT_RX_ABORT_PATTERN: assert property (p_rx_abort_pattern_detect) else begin
    $error("RX abort pattern (11111110, LSB first) was not detected.");
    ErrCntAssertions++;
  end

  // Spec 9 Tx_AbortedTrans timing.
  ASSERT_TX_ABORTED_TRANS: assert property (p_tx_aborted_trans_asserted) else begin
    $error("Tx_AbortedTrans was not asserted when aborting during transmission.");
    ErrCntAssertions++;
  end

  // Part A Concurrent Task 2 + Spec 10
  ASSERT_RX_ABORT_SIGNAL: assert property (p_rx_abort_signal_after_detect) else begin
    $error("Rx_AbortSignal did not go high after Rx_AbortDetect during valid frame.");
    ErrCntAssertions++;
  end

  // Spec 12 EoF generation after completed RX frame.
  ASSERT_RX_EOF_GENERATED: assert property (p_rx_eof_after_frame_complete) else begin
    $error("Rx_EoF was not generated after a completed RX frame.");
    ErrCntAssertions++;
  end

  //  Spec 13 Overflow on RX frames longer than 128 bytes.
  ASSERT_RX_OVERFLOW: assert property (p_rx_overflow_on_write_beyond_128) else begin
    $error("Rx_Overflow was not asserted when receiving more than 128 bytes.");
    ErrCntAssertions++;
  end

  //Spec 15 Rx_Ready assert/hold/drain lifecycle.
  ASSERT_RX_READY_LIFECYCLE: assert property (p_rx_ready_lifecycle) else begin
    $error("Rx_Ready lifecycle failed: assert/hold/drain behavior was incorrect.");
    ErrCntAssertions++;
  end

  // [Spec 15 Rx_Ready should assert after completed non-aborted frame.
  ASSERT_RX_READY_ASSERT_AFTER_FRAME: assert property (p_rx_ready_assert_after_frame_complete) else begin
    $error("Rx_Ready did not assert after completed non-aborted RX frame.");
    ErrCntAssertions++;
  end

  //  Spec 15 Rx_Ready should deassert after last read.
  ASSERT_RX_READY_DROP_AFTER_LAST_READ: assert property (p_rx_ready_drop_after_last_read) else begin
    $error("Rx_Ready did not deassert after last RX buffer read.");
    ErrCntAssertions++;
  end

  // [Task 16 | Spec 16] Frame error assertion for framing/FCS faults.
  ASSERT_RX_FRAME_ERROR: assert property (p_rx_frame_error_on_error_cause) else begin
    $error("Rx_FrameError was not asserted after non-byte-aligned or FCS-error cause.");
    ErrCntAssertions++;
  end

  // [Task 17 | Spec 17] Tx_Done when TX completes.
  ASSERT_TX_DONE: assert property (p_tx_done_on_tx_complete) else begin
    $error("Tx_Done was not asserted when TX completed.");
    ErrCntAssertions++;
  end

  // [Task 18 | Spec 18] Tx_Full after 126 or more writes.
  ASSERT_TX_FULL: assert property (p_tx_full_after_126_writes) else begin
    $error("Tx_Full was not asserted after writing 126 or more bytes.");
    ErrCntAssertions++;
  end

  /********************************************
   *         Antecedent Coverage Guard        *
   ********************************************/

  // Track whether each assertion antecedent was exercised at least once.
  COV_ANT_RX_FLAG: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_flag);
  COV_ANT_TX_START_FLAG: cover property (@(posedge Clk) disable iff (!Rst) $rose(Tx_ValidFrame));
  COV_ANT_TX_END_FLAG: cover property (@(posedge Clk) disable iff (!Rst) seq_tx_frame_end_non_abort);
  COV_ANT_TX_ZERO_INSERTION: cover property (@(posedge Clk) disable iff (!Rst) seq_tx_frame_active_for_zero_insert);
  COV_ANT_RX_ZERO_DETECT: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_inserted_zero_pattern);
  COV_ANT_RX_ZERO_NO_NEWBYTE: cover property (@(posedge Clk) disable iff (!Rst) (Rx_ValidFrame && ZeroDetect));
  COV_ANT_TX_IDLE: cover property (@(posedge Clk) disable iff (!Rst) seq_tx_idle_stable);
  COV_ANT_RX_IDLE: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_idle_stable);
  COV_ANT_TX_ABORT_REQ: cover property (@(posedge Clk) disable iff (!Rst) seq_tx_abort_req_during_frame);
  COV_ANT_RX_ABORT_PATTERN: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_abort_pattern);
  COV_ANT_RX_ABORT: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_abort_detect_during_frame);
  COV_ANT_RX_EOF: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_frame_complete_non_abort);
  COV_ANT_RX_OVERFLOW: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_write_beyond_128);
  COV_ANT_RX_READY_LIFECYCLE: cover property (@(posedge Clk) disable iff (!Rst)(Rx_RdBuff && Rx_Ready));
  COV_ANT_RX_FRAME_ERROR: cover property (@(posedge Clk) disable iff (!Rst) seq_rx_frame_error_cause);
  COV_ANT_TX_DONE: cover property (@(posedge Clk) disable iff (!Rst) seq_tx_frame_end_non_abort);
  COV_ANT_TX_FULL: cover property (@(posedge Clk) disable iff (!Rst) seq_tx_write_126_or_more);

  // Counts RX write strobes within one valid frame.
  always_ff @(posedge Clk or negedge Rst) begin
    if (!Rst)
      rx_write_count_in_frame <= '0;
    else if (!Rx_ValidFrame)
      rx_write_count_in_frame <= '0;
    else if (Rx_WrBuff)
      rx_write_count_in_frame <= rx_write_count_in_frame + 1'b1;
  end

  // Counts RX read strobes while Rx_Ready is active.
  always_ff @(posedge Clk or negedge Rst) begin
    if (!Rst)
      rx_read_count_while_ready <= '0;
    else if (!Rx_Ready)
      rx_read_count_while_ready <= '0;
    else if (Rx_RdBuff)
      rx_read_count_while_ready <= rx_read_count_while_ready + 1'b1;
  end

  // Counts TX write strobes before TX starts/completes.
  always_ff @(posedge Clk or negedge Rst) begin
    if (!Rst)
      tx_write_count <= '0;
    else if (Tx_WrBuff)
      tx_write_count <= tx_write_count + 1'b1;
    else if (Tx_Done)
      tx_write_count <= '0;
  end

  // Track whether Tx_Done was observed at least once while the frame was active.
  always_ff @(posedge Clk or negedge Rst) begin
    if (!Rst)
      tx_done_seen_in_frame <= 1'b0;
    else if (Tx_Done)
      tx_done_seen_in_frame <= 1'b1;
    else if (!Tx_ValidFrame)
      tx_done_seen_in_frame <= 1'b0;
  end

endmodule