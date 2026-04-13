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
  input  logic Tx_ValidFrame,
  input  logic Tx_AbortedTrans,
  input  logic Rx,
  input  logic Rx_FlagDetect,
  input  logic Rx_ValidFrame,
  input  logic Rx_AbortDetect,
  input  logic Rx_AbortSignal,
  input  logic Rx_Overflow,
  input  logic Rx_WrBuff
);

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
      ($fell(Tx_ValidFrame) && !Tx_AbortedTrans) |-> ##[0:2] Tx_flag;
  endproperty

  TX_EndFlag_Assert : assert property (TX_EndFlag) begin
    $display("PASS: TX end flag");
  end else begin
    $error("TX end flag (01111110) was not generated.");
    ErrCntAssertions++;
  end

endmodule
