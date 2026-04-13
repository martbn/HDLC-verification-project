//////////////////////////////////////////////////
// Title:   assertions_hdlc
// Author:  
// Date:    
//////////////////////////////////////////////////

/* The assertions_hdlc module is a test module containing the concurrent
   assertions. It is used by binding the signals of assertions_hdlc to the
   corresponding signals in the test_hdlc testbench. This is already done in
   bind_hdlc.sv 

   For this exercise you will write concurrent assertions for the Rx module:
   - Verify that Rx_FlagDetect is asserted two cycles after a flag is received
   - Verify that Rx_AbortSignal is asserted after receiving an abort flag
*/

module assertions_hdlc (
  output int   ErrCntAssertions,
  input  logic Clk,
  input  logic Rst,
  input  logic Tx,
  input  logic TxD,
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
  input  logic Rx_Overflow,
  input  logic Rx_WrBuff
);

logic Task10_AbortDetectDuringValidFrameSeen;

  initial begin
    ErrCntAssertions  =  0;
  end

  /*******************************************
   *  Verify correct Rx_FlagDetect behavior  *
   *******************************************/

  sequence Rx_flag;
    // HDLC flag pattern: 01111110
    !Rx ##1 Rx [*6] ##1 !Rx;
  endsequence

  // Check if flag sequence is detected
  property RX_FlagDetect;
    @(posedge Clk) Rx_flag |-> ##2 Rx_FlagDetect;
  endproperty

  RX_FlagDetect_Assert : assert property (RX_FlagDetect) begin
    $display("PASS: Flag detect");
  end else begin 
    $error("Flag sequence did not generate FlagDetect"); 
    ErrCntAssertions++; 
  end

  /********************************************
   *  Verify correct Rx_AbortSignal behavior  *
   ********************************************/

  //If abort is detected during valid frame. then abort signal should go high
  property RX_AbortSignal;
    @(posedge Clk) (Rx_AbortDetect && Rx_ValidFrame) |-> ##1 Rx_AbortSignal;
  endproperty

  RX_AbortSignal_Assert : assert property (RX_AbortSignal) begin
    $display("PASS: Abort signal");
  end else begin 
    $error("AbortSignal did not go high after AbortDetect during validframe"); 
    ErrCntAssertions++; 
  end

  /***********************************************
   *  Verify Tx start/end flag generation (Task5)*
   ***********************************************/

  sequence Tx_flag;
    // HDLC flag pattern: 01111110
    !Tx ##1 Tx [*6] ##1 !Tx;
  endsequence

  // Start flag must appear when TX valid frame starts.
  property TX_StartFlag;
    @(posedge Clk) disable iff (!Rst)
      $rose(Tx_ValidFrame) |-> ##[0:3] Tx_flag;
  endproperty

  TX_StartFlag_Assert : assert property (TX_StartFlag) begin
    $display("PASS: TX start flag");
  end else begin
    $error("TX start flag (01111110) was not generated.");
    ErrCntAssertions++;
  end

  // End flag must appear when TX valid frame finishes (non-abort case).
    property TX_EndFlag;
    @(posedge Clk) disable iff (!Rst)
      ($fell(Tx_ValidFrame) && !Tx_AbortedTrans) |-> ##[0:8] Tx_flag;
  endproperty

  TX_EndFlag_Assert : assert property (TX_EndFlag) begin
    $display("PASS: TX end flag");
  end else begin
    $error("TX end flag (01111110) was not generated.");
    ErrCntAssertions++;
  end

  /********************************************
   *  Verify zero insertion/removal (Task6)   *
   ********************************************/
//t
  // TX transparent transmission: no 6 consecutive ones in data stream.
  // TxD is observed before flag insertion, so it represents payload/FCS data path.
  property TX_ZeroInsertion;
    @(posedge Clk) disable iff (!Rst)
      (Tx_ValidFrame &&
       $past(Tx_ValidFrame,1) &&
       $past(Tx_ValidFrame,2) &&
       $past(Tx_ValidFrame,3) &&
       $past(Tx_ValidFrame,4) &&
       $past(Tx_ValidFrame,5) &&
       $past(Tx_ValidFrame,10))
      |-> !(TxD &&
            $past(TxD,1) &&
            $past(TxD,2) &&
            $past(TxD,3) &&
            $past(TxD,4) &&
            $past(TxD,5));
  endproperty

  TX_ZeroInsertion_Assert : assert property (TX_ZeroInsertion) else begin
    $error("TX zero insertion failed: detected 6 consecutive ones in data path.");
    ErrCntAssertions++;
  end

  // RX transparent transmission: 0111110 inside valid frame should be detected as inserted zero.
  property RX_ZeroRemovalDetect;
    @(posedge Clk) disable iff (!Rst)
      (Rx_ValidFrame &&
       !Rx_StartZeroDetect &&
       !RxD &&
       $past(RxD,1) &&
       $past(RxD,2) &&
       $past(RxD,3) &&
       $past(RxD,4) &&
       $past(RxD,5))
      |-> ZeroDetect;
  endproperty

  RX_ZeroRemovalDetect_Assert : assert property (RX_ZeroRemovalDetect) else begin
    $error("RX zero removal failed: inserted zero pattern was not detected.");
    ErrCntAssertions++;
  end

  // When an inserted zero is detected, RxChannel must not report a completed byte that cycle.
  property RX_ZeroRemovalNoNewByte;
    @(posedge Clk) disable iff (!Rst)
      (Rx_ValidFrame && ZeroDetect) |=> !Rx_NewByte;
  endproperty

  RX_ZeroRemovalNoNewByte_Assert : assert property (RX_ZeroRemovalNoNewByte) else begin
    $error("RX zero removal failed: NewByte asserted while inserted zero was detected.");
    ErrCntAssertions++;
  end

    /********************************************
   *    Verify idle pattern (Task7)           *
   ********************************************/

   sequence TX_IdleStable;
    !Tx_ValidFrame &&
    !Tx_AbortedTrans &&
    Tx &&
    $past(Tx,1) &&
    $past(Tx,2) &&
    $past(Tx,3) &&
    $past(Tx,4) &&
    $past(Tx,5) &&
    $past(Tx,6) &&
    $past(Tx,7) &&
    $past(Tx,8);
  endsequence

  sequence RX_IdleStable;
    !Rx_ValidFrame &&
    Rx &&
    $past(Rx,1) &&
    $past(Rx,2) &&
    $past(Rx,3) &&
    $past(Rx,4) &&
    $past(Rx,5) &&
    $past(Rx,6) &&
    $past(Rx,7);
  endsequence

  // TX idle generation: after stable idle (no active TX frame), line should stay high (1).
  property TX_IdlePattern;
    @(posedge Clk) disable iff (!Rst)
      TX_IdleStable |-> Tx;
  endproperty

  TX_IdlePattern_Assert : assert property (TX_IdlePattern) else begin
    $error("TX idle pattern failed: Tx is not high during idle.");
    ErrCntAssertions++;
  end

  // RX idle checking: while the line stays high in idle and no frame is valid,
  // no new RX activity events should be generated. AbortSignal is a sticky status
  // bit in this design and may remain high after a prior abort, so it is not
  // treated as per-cycle idle activity.
  property RX_IdlePattern;
    @(posedge Clk) disable iff (!Rst)
      RX_IdleStable |-> (!Rx_FlagDetect && !Rx_NewByte && !ZeroDetect);
  endproperty

  RX_IdlePattern_Assert : assert property (RX_IdlePattern) else begin
    $error("RX idle check failed: activity detected while idle ones were received.");
    ErrCntAssertions++;
  end

  /********************************************
   *   Verify abort pattern (Task8)           *
   ********************************************/

  sequence TX_AbortSeq;
    // HDLC abort pattern on line (LSB first): 11111110 => 0, then seven 1s
    !Tx ##1 Tx [*7];
  endsequence

  sequence TX_AbortReqDuringFrame;
    $rose(Tx_AbortFrame) && (Tx_ValidFrame || $past(Tx_ValidFrame,1));
  endsequence

  property TX_AbortPattern;
    @(posedge Clk) disable iff (!Rst)
      TX_AbortReqDuringFrame |=> ##[0:20] TX_AbortSeq;
  endproperty

  TX_AbortPattern_Assert : assert property (TX_AbortPattern) begin
    $display("PASS: TX abort pattern");
  end else begin
    $error("TX abort pattern (11111110, LSB first) was not generated.");
    ErrCntAssertions++;
  end

  /********************************************
   * Verify Tx_AbortedTrans on abort (Task9)  *
   ********************************************/

  property TX_AbortedTransAsserted;
    @(posedge Clk) disable iff (!Rst)
      TX_AbortReqDuringFrame |=> ##[1:3] Tx_AbortedTrans;
  endproperty

  TX_AbortedTransAsserted_Assert : assert property (TX_AbortedTransAsserted) begin
    $display("PASS: TX AbortedTrans asserted");
  end else begin
    $error("Tx_AbortedTrans was not asserted when aborting during transmission.");
    ErrCntAssertions++;
  end

  /********************************************
   * Verify Rx_AbortSignal on abort (Task10)  *
   ********************************************/


  sequence RX_AbortDetectDuringValidFrame_Task10;
    Rx_AbortDetect && Rx_ValidFrame;
  endsequence

  // Abort detected during a valid frame must raise AbortSignal.
  property RX_AbortSignal_Task10;
    @(posedge Clk) disable iff (!Rst)
      RX_AbortDetectDuringValidFrame_Task10 |-> ##1 Rx_AbortSignal;
  endproperty

  RX_AbortSignal_Task10_Assert : assert property (RX_AbortSignal_Task10) begin
    $display("PASS: RX Abort sigaln");
  end else begin 
    $error("AbortSignal did not go high after AbortDetect during validframe"); 
    ErrCntAssertions++; 
  end

  // Non-vacuous guard: Task10 antecedent must be exercised at least once.
  always_ff @(posedge Clk or negedge Rst) begin
    if(!Rst)
      Task10_AbortDetectDuringValidFrameSeen <= 1'b0;
    else if(Rx_AbortDetect && Rx_ValidFrame)
      Task10_AbortDetectDuringValidFrameSeen <= 1'b1;
  end

  final begin
    if(!Task10_AbortDetectDuringValidFrameSeen) begin
      $error("Task10 stimulus missing: no (Rx_AbortDetect && Rx_ValidFrame) event observed.");
      ErrCntAssertions++;
    end
  end

endmodule
