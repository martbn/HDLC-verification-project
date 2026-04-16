//////////////////////////////////////////////////
// Title:   testPr_hdlc
// Author: 
// Date:  
//////////////////////////////////////////////////

/* testPr_hdlc contains the simulation and immediate assertion code of the
   testbench. 

   For this exercise you will write immediate assertions for the Rx module which
   should verify correct values in some of the Rx registers for:
   - Normal behavior
   - Buffer overflow 
   - Aborts

   HINT:
   - A ReadAddress() task is provided, and addresses are documentet in the 
     HDLC Module Design Description
*/

program testPr_hdlc(
  in_hdlc uin_hdlc
);
  
  int TbErrorCnt;
  bit framesize_checked_normal_seen;
  bit framesize_checked_overflow_seen;

  

  /****************************************************************************
   *                                                                          *
   *                               Student code                               *
   *                                                                          *
   ****************************************************************************/

  // Register address definitions
  localparam logic [2:0] TXSC   = 3'b000;  // TX Status/Control
  localparam logic [2:0] TXBUFF = 3'b001;  // TX Data Buffer
  localparam logic [2:0] RXSC   = 3'b010;  // RX Status/Control
  localparam logic [2:0] RXBUFF = 3'b011;  // RX Data Buffer
  localparam logic [2:0] RXLEN  = 3'b100;  // RX Frame Length

  // Immediate checks in this file cover specs: 1, 2, 3, 4, 11 and 14.
  // Spec 12 also has an immediate sanity check here (concurrent check is in assertions_hdlc.sv).

  task automatic CheckBitEq(string msg, logic got, logic exp, logic [7:0] ctx);
    assert (got === exp) else begin
      $error("%s Exp=%0b Got=%0b Ctx=0x%0h", msg, exp, got, ctx);
      TbErrorCnt++;
    end
  endtask

  task automatic CheckByteEq(string msg, logic [7:0] got, logic [7:0] exp);
    assert (got == exp) else begin
      $error("%s Exp=0x%0h Got=0x%0h", msg, exp, got);
      TbErrorCnt++;
    end
  endtask

  task automatic CheckIntLe(string msg, int got, int lim);
    assert (got <= lim) else begin
      $error("%s Limit=%0d Got=%0d", msg, lim, got);
      TbErrorCnt++;
    end
  endtask

  // VerifyAbortReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer is zero after abort.
  task VerifyAbortReceive();
    logic [7:0] rxsc;
    logic [7:0] rxbuff;

    ReadAddress(RXSC, rxsc);
    ReadAddress(RXBUFF, rxbuff);

    // Spec 3: Rx_AbortedFrame bit must be set after abort.
    CheckBitEq("ABORT RXSC[3] mismatch.", rxsc[3], 1'b1, rxsc);
    // Spec 3: RxReady must be low after abort.
    CheckBitEq("ABORT RXSC[0] mismatch.", rxsc[0], 1'b0, rxsc);
    // Spec 2: Reading RX buffer after abort should return zero.
    CheckByteEq("ABORT RXBUFF mismatch.", rxbuff, 8'h00);
  endtask

  // VerifyNormalReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer contains correct data.
  task VerifyNormalReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] rxsc;
    logic [7:0] rxbuff;

    wait(uin_hdlc.Rx_Ready);
    ReadAddress(RXSC, rxsc);

    // Spec 3: RxReady must be high for a normal frame.
    CheckBitEq("NORMAL RXSC[0] mismatch.", rxsc[0], 1'b1, rxsc);
    // Spec 3: FrameError must be low for a normal frame.
    CheckBitEq("NORMAL RXSC[2] mismatch.", rxsc[2], 1'b0, rxsc);
    // Spec 3: AbortedFrame must be low for a normal frame.
    CheckBitEq("NORMAL RXSC[3] mismatch.", rxsc[3], 1'b0, rxsc);
    // Spec 3: Overflow must be low for a normal frame.
    CheckBitEq("NORMAL RXSC[4] mismatch.", rxsc[4], 1'b0, rxsc);

    // Spec 1: Payload in these checks is limited to 126 bytes (128 incl. FCS).
    CheckIntLe("NORMAL payload size exceeds 126 bytes.", Size, 126);

    // Spec 1: RX buffer payload must match received payload bytes.
    // ReadAddress(RXBUFF, ...) auto-increments the internal buffer pointer
    for (int i = 0; i < Size; i++) begin
      ReadAddress(RXBUFF, rxbuff);
      assert (rxbuff == data[i]) else begin
        $error("NORMAL data mismatch at byte %0d. Exp=0x%0h Got=0x%0h", i, data[i], rxbuff);
        TbErrorCnt++;
      end
    end
  endtask

  // VerifyOverflowReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer contains correct data.
  task VerifyOverflowReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] rxsc;
    logic [7:0] rxbuff;

    wait(uin_hdlc.Rx_Ready);
    ReadAddress(RXSC, rxsc);

    // Spec 3: RxReady must be high when overflowed frame is available.
    CheckBitEq("OVERFLOW RXSC[0] mismatch.", rxsc[0], 1'b1, rxsc);
    // Spec 13: Overflow bit must be set after >128 RX bytes.
    CheckBitEq("OVERFLOW RXSC[4] mismatch.", rxsc[4], 1'b1, rxsc);

    // Spec 1: Payload bytes read from RX buffer are bounded by 126 bytes.
    CheckIntLe("OVERFLOW payload size exceeds 126 bytes.", Size, 126);

    // Spec 1: RX buffer payload bytes remain readable (up to buffer limit).
    // ReadAddress(RXBUFF, ...) auto-increments the internal buffer pointer
    for (int i = 0; i < Size; i++) begin
      ReadAddress(RXBUFF, rxbuff);
      assert (rxbuff == data[i]) else begin
        $error("OVERFLOW data mismatch at byte %0d. Exp=0x%0h Got=0x%0h", i, data[i], rxbuff);
        TbErrorCnt++;
      end
    end
  endtask

  // 2 Attempting to read RX buffer after aborted frame, frame error or dropped frame should result
  // in zeros.
  task VerifyReadAfterError();
    logic [7:0] rxbuff;

    wait(uin_hdlc.Rx_Ready == 1'b0);
    ReadAddress(RXBUFF, rxbuff);

    // Spec 2: Reads after abort/frame error/drop should return zero.
    CheckByteEq("READ AFTER ERROR RXBUFF mismatch.", rxbuff, 8'h00);
  endtask

  // Spec 3: Correct bits set in RX status/control register after frame handling.
  task VerifyRxStatusControl(int Abort, int FCSerr, int NonByteAligned, int Overflow, int Drop);
    logic [7:0] rxsc;
    logic [7:0] exp;

    exp[0] = !(Abort || FCSerr || NonByteAligned || Drop); // ready
    exp[1] = 1'b0;                                          // drop
    exp[2] = (FCSerr || NonByteAligned);                    // frame error
    exp[3] = Abort;                                         // aborted frame
    exp[4] = Overflow;                                      // overflow
    exp[5] = (!Overflow && !NonByteAligned);                // fcs enable
    exp[7:6] = 2'b00;

    ReadAddress(RXSC, rxsc);

    CheckBitEq("RXSC[0] mismatch.", rxsc[0], exp[0], rxsc);
    CheckBitEq("RXSC[1] mismatch.", rxsc[1], exp[1], rxsc);
    CheckBitEq("RXSC[2] mismatch.", rxsc[2], exp[2], rxsc);
    CheckBitEq("RXSC[3] mismatch.", rxsc[3], exp[3], rxsc);
    CheckBitEq("RXSC[4] mismatch.", rxsc[4], exp[4], rxsc);
    CheckBitEq("RXSC[5] mismatch.", rxsc[5], exp[5], rxsc);
    // Spec 3: Reserved bits must be zero.
    assert (rxsc[7:6] == 2'b00) else begin
      $error("RXSC[7:6] mismatch. Exp=00 Got=%0b RXSC=0x%0h", rxsc[7:6], rxsc);
      TbErrorCnt++;
    end
  endtask

  // Spec 14: Rx FrameSize should equal number of received payload bytes (max 126).
  task VerifyRxFrameSize(int exp_size, bit is_overflow_case);
    logic [7:0] rxlen;
    if (is_overflow_case)
      framesize_checked_overflow_seen = 1'b1;
    else
      framesize_checked_normal_seen = 1'b1;

    ReadAddress(RXLEN, rxlen);
    CheckByteEq("RXLEN mismatch.", rxlen, exp_size[7:0]);
  endtask

//4. Correct TX output according to written TX buffer.
task ReadTxByteNoStuff(output logic [7:0] TxByte, inout int OnesCnt);
  int BitIdx;
  TxByte = '0;
  BitIdx = 0;
  while (BitIdx < 8) begin
    @(posedge uin_hdlc.Clk);

    // Remove stuffed 0s from transparent transmission.
    if ((OnesCnt == 5) && (uin_hdlc.Tx == 1'b0)) begin
      OnesCnt = 0;
      continue;
    end

    TxByte[BitIdx] = uin_hdlc.Tx;
    if (uin_hdlc.Tx)
      OnesCnt++;
    else
      OnesCnt = 0;
    BitIdx++;
  end
endtask

  task VerifyTxOutput(logic [127:0][7:0] data, int Size);
  logic [127:0][7:0] CRCInputData;
  logic [7:0] ShiftReg;
  logic [7:0] TxByte;
  logic [7:0] TxFCSByte0;
  logic [7:0] TxFCSByte1;
  logic [15:0] ExpFCSBytes;
  int ByteIdx;
  int OnesCnt;
  
  ShiftReg = '0;
  OnesCnt = 0;
  CRCInputData = '0;
  for (int i = 0; i < Size; i++)
    CRCInputData[i] = data[i];
  CRCInputData[Size]   = 8'h00;
  CRCInputData[Size+1] = 8'h00;

  // Synchronize to start flag on TX line: 01111110 (LSB first).
  while (ShiftReg != 8'b0111_1110) begin
    @(posedge uin_hdlc.Clk);
    ShiftReg = {uin_hdlc.Tx, ShiftReg[7:1]};
  end

  for (ByteIdx = 0; ByteIdx < Size; ByteIdx++) begin
    ReadTxByteNoStuff(TxByte, OnesCnt);

    // Spec 4: TX output bytes must match bytes written to TX buffer.
    assert (TxByte == data[ByteIdx]) else begin
      $error("TX OUTPUT mismatch at byte %0d. Exp=0x%0h Got=0x%0h", ByteIdx, data[ByteIdx], TxByte);
      TbErrorCnt++;
    end
  end

  // Spec 11: CRC generation and checking (TX side generation):
  // reuse the same CRC model already used by RX stimulus generation.
  GenerateFCSBytes(CRCInputData, Size, ExpFCSBytes);

  ReadTxByteNoStuff(TxFCSByte0, OnesCnt);
  // Spec 11: First transmitted FCS byte must match model.
  assert (TxFCSByte0 == ExpFCSBytes[7:0]) else begin
    $error("CRC TX byte0 mismatch. Expected 0x%0h, got 0x%0h", ExpFCSBytes[7:0], TxFCSByte0);
    TbErrorCnt++;
  end

  ReadTxByteNoStuff(TxFCSByte1, OnesCnt);
  // Spec 11: Second transmitted FCS byte must match model.
  assert (TxFCSByte1 == ExpFCSBytes[15:8]) else begin
    $error("CRC TX byte1 mismatch. Expected 0x%0h, got 0x%0h", ExpFCSBytes[15:8], TxFCSByte1);
    TbErrorCnt++;
  end
  endtask
  
  



  /****************************************************************************
   *                                                                          *
   *                             Simulation code                              *
   *                                                                          *
   ****************************************************************************/

  localparam bit RUN_EXTENDED_STIMULUS = 1'b0;
  localparam bit RUN_COVERAGE_EDGE_STIMULUS = 1'b1;

  // Directed stimulus plan to exercise concurrent-assertion antecedents.
  task RunDirectedConcurrentStimulus();
    // TX side (Tasks 5, 6, 7, 8, 9, 17, 18)
    Transmit(16, 0, 0); // Task5 + Task7 (normal TX frame with start/end flags)
    Transmit(16, 0, 1); // Task6 TX (transparent payload with heavy zero insertion)
    Transmit(20, 0, 0); // Task17 (normal completion path for Tx_Done)
    Transmit(126, 0, 0); // Task18 (TX full threshold reached at 126 writes)
    Transmit(40, 1, 0); // Task8 + Task9 (abort request, abort pattern, AbortedTrans)

    // RX side (Tasks 6, 10, 12, 13, 14, 15, 16)
    Receive( 24, 0, 0, 0, 0, 0, 0, 1); // Task6 RX + Task12 (transparent non-abort frame)
    Receive( 10, 0, 0, 0, 0, 0, 0, 0); // Task12 + Task15 (baseline frame, RxReady + readout)
    Receive( 18, 0, 0, 0, 0, 0, 0, 0); // Task15 dedicated (explicit ready lifecycle exercise)
    Receive( 20, 0, 1, 0, 0, 0, 0, 0); // Task16 (FCS error -> Rx_FrameError)
    Receive( 20, 0, 0, 1, 0, 0, 0, 0); // Task16 (non-byte-aligned -> Rx_FrameError)
    Receive(126, 0, 0, 0, 0, 0, 0, 0); // Task14 (max-size normal frame: expect RxLen=126)
    Receive( 40, 1, 0, 0, 0, 0, 0, 0); // Task10 (abort during valid RX frame)
    Receive(126, 0, 0, 0, 1, 0, 0, 0); // Task13 (overflow path: >128 bytes total)
  endtask

  // Optional extra scenarios for broader regression.
  task RunExtendedStimulus();
    Receive(40, 0, 1, 0, 0, 0, 0, 0); // FCS error
    Receive(40, 0, 0, 0, 0, 1, 0, 0); // Drop
    Receive(45, 0, 0, 0, 0, 0, 0, 0); // Normal
    Receive(126, 0, 0, 0, 0, 0, 0, 0); // Max-size non-overflow normal
    Receive(122, 1, 0, 0, 0, 0, 0, 0); // Abort near max size
    Receive(25, 0, 0, 0, 0, 0, 0, 0); // Normal
    Receive(47, 0, 0, 0, 0, 0, 0, 0); // Normal
  endtask

  task PulseTxDisableDuringIdle();
    wait(!uin_hdlc.Tx_ValidFrame);
    uin_hdlc.TxEN = 1'b0;
    repeat(8)
      @(posedge uin_hdlc.Clk);
    uin_hdlc.TxEN = 1'b1;
  endtask

  task RunCoverageEdgeStimulus();
    // TX edge and corner cases.
    PulseTxDisableDuringIdle();
    Transmit(8,   0, 0); // Short normal frame.
    Transmit(8,   0, 1); // Short transparent frame.
    Transmit(125, 0, 0); // Near max frame.
    Transmit(60,  1, 0); // Abort with medium frame.
    Transmit(100, 1, 0); // Abort with longer frame.

    // RX edge and corner cases.
    Receive(8,   0, 0, 0, 0, 0, 0, 0); // Short normal frame.
    Receive(8,   0, 0, 0, 0, 0, 0, 1); // Short transparent frame.
    Receive(20,  0, 0, 0, 0, 1, 0, 0); // Drop path.
    Receive(126, 0, 0, 0, 0, 0, 1, 0); // Skip read at max size (leave unread bytes).
    Receive(12,  0, 0, 0, 0, 0, 0, 0); // New frame while previous could be unread.
    Receive(126, 0, 0, 1, 0, 0, 0, 0); // Non-byte-aligned at max size.

    // Compact TX abort timing sweep for controller coverage.
    for (int d = 0; d <= 6; d += 2) begin
      logic [127:0][7:0] tx_data;
      for (int i = 0; i < 12; i++)
        tx_data[i] = $urandom;
      MakeTxStimulus(tx_data, 12);
      repeat(d)
        @(posedge uin_hdlc.Clk);
      WriteAddress(TXSC, 8'h06); // Enable + abort near frame start.
      repeat(200)
        @(posedge uin_hdlc.Clk);
    end

    begin
      logic [127:0][7:0] tx_data;
      for (int i = 0; i < 12; i++)
        tx_data[i] = $urandom;
      MakeTxStimulus(tx_data, 12);
      WriteAddress(TXSC, 8'h02);
      wait(uin_hdlc.Tx_ValidFrame);
      repeat(16)
        @(posedge uin_hdlc.Clk);
      WriteAddress(TXSC, 8'h04); // Abort later during active TX.
      repeat(200)
        @(posedge uin_hdlc.Clk);
    end
  endtask

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

  task Init();
    uin_hdlc.Clk         =   1'b0;
    uin_hdlc.Rst         =   1'b0;
    uin_hdlc.Address     = 3'b000;
    uin_hdlc.WriteEnable =   1'b0;
    uin_hdlc.ReadEnable  =   1'b0;
    uin_hdlc.DataIn      =     '0;
    uin_hdlc.TxEN        =   1'b1;
    uin_hdlc.Rx          =   1'b1;
    uin_hdlc.RxEN        =   1'b1;

		    TbErrorCnt = 0;
    framesize_checked_normal_seen = 1'b0;
    framesize_checked_overflow_seen = 1'b0;

    #1000ns;
    uin_hdlc.Rst         =   1'b1;
  endtask

  task WriteAddress(input logic [2:0] Address ,input logic [7:0] Data);
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Address     = Address;
    uin_hdlc.WriteEnable = 1'b1;
    uin_hdlc.DataIn      = Data;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.WriteEnable = 1'b0;
  endtask

  task ReadAddress(input logic [2:0] Address ,output logic [7:0] Data);
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Address    = Address;
    uin_hdlc.ReadEnable = 1'b1;
    #100ns;
    Data                = uin_hdlc.DataOut;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.ReadEnable = 1'b0;
  endtask

  task MakeTxStimulus(logic [127:0][7:0] Data, int Size);
    for (int i = 0; i < Size; i++) begin
      WriteAddress(TXBUFF, Data[i]);
    end
  endtask

  task Transmit(int Size, int Abort, int Transparent);
    logic [127:0][7:0] TransmitData;
    logic abortReqSeen;
    logic abortedSeen;
    logic [7:0] txsc_after;
    string msg;
    if(Abort)
      msg = "- Abort";
    else if(Transparent)
      msg = "- Transparent";
    else
      msg = "- Normal";

    $display("*************************************************************");
    $display("%t - Starting task Transmit %s", $time, msg);
    $display("*************************************************************");

    for (int i = 0; i < Size; i++) begin
      if(Transparent)
        TransmitData[i] = 8'hFF;
      else
        TransmitData[i] = $urandom;
    end

    MakeTxStimulus(TransmitData, Size);
    WriteAddress(TXSC, 8'h02);

    // Added for task 4
    if(!Abort)
      VerifyTxOutput(TransmitData, Size);


    if(Abort) begin
      // Trigger abort only after TX frame is active.
      wait(uin_hdlc.Tx_ValidFrame);
      repeat(8)
        @(posedge uin_hdlc.Clk);

      abortReqSeen = 1'b0;
      fork
        begin
          repeat(4) begin
            @(posedge uin_hdlc.Clk);
            if(uin_hdlc.Tx_AbortFrame)
              abortReqSeen = 1'b1;
          end
        end
        begin
          WriteAddress(TXSC, 8'h04);
        end
      join

      // Spec 9 stimulus guard: ensure abort request actually reached DUT.
      assert (abortReqSeen) else begin
        $error("ABORT STIM: Tx_AbortFrame pulse was not observed.");
        TbErrorCnt++;
      end

      abortedSeen = 1'b0;
      for(int i = 0; i < 40; i++) begin
        @(posedge uin_hdlc.Clk);
        if(uin_hdlc.Tx_AbortedTrans) begin
          abortedSeen = 1'b1;
          break;
        end
      end
      // Spec 9 stimulus guard: ensure abort transition is exercised.
      assert (abortedSeen) else begin
        $error("ABORT STIM: Tx_AbortedTrans did not assert after abort request.");
        TbErrorCnt++;
      end
    end

    wait(uin_hdlc.Tx_Done);
    ReadAddress(TXSC, txsc_after);

    $display("*************************************************************");
    $display("%t - Finishing task Transmit %s", $time, msg);
    $display("*************************************************************");
  endtask

  task InsertFlagOrAbort(int flag);
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b0;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;
    @(posedge uin_hdlc.Clk);
    if(flag)
      uin_hdlc.Rx = 1'b0;
    else
      uin_hdlc.Rx = 1'b1;
  endtask

  task MakeRxStimulus(logic [127:0][7:0] Data, int Size);
    logic [4:0] PrevData;
    PrevData = '0;
    for (int i = 0; i < Size; i++) begin
      for (int j = 0; j < 8; j++) begin
        if(&PrevData) begin
          @(posedge uin_hdlc.Clk);
          uin_hdlc.Rx = 1'b0;
          PrevData = PrevData >> 1;
          PrevData[4] = 1'b0;
        end

        @(posedge uin_hdlc.Clk);
        uin_hdlc.Rx = Data[i][j];

        PrevData = PrevData >> 1;
        PrevData[4] = Data[i][j];
      end
    end
  endtask

  task VerifyRxCRCAtStopFCS(int ExpectFCSerr);
    logic StopFCSSeen;
    logic FCSerrAtStopFCS;

    StopFCSSeen = 1'b0;
    FCSerrAtStopFCS = 1'b0;

    repeat(24) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Rx_StopFCS && !StopFCSSeen) begin
        StopFCSSeen = 1'b1;
        // RxFCS updates FCSerr in the StopFCS clocked block.
        // Sample one clock later to read the updated value deterministically.
        @(posedge uin_hdlc.Clk);
        FCSerrAtStopFCS = uin_hdlc.Rx_FCSerr;
      end
    end

    // Spec 11: RX must produce StopFCS for completed non-abort frame.
    assert (StopFCSSeen) else begin
      $error("CRC RX check failed: Rx_StopFCS was not observed.");
      TbErrorCnt++;
    end

    if (StopFCSSeen) begin
      // Spec 11: RX FCS error flag must match expected CRC outcome.
      assert (FCSerrAtStopFCS == ExpectFCSerr) else begin
        $error("CRC RX check failed: expected Rx_FCSerr=%0b at StopFCS, got %0b",
               ExpectFCSerr, FCSerrAtStopFCS);
        TbErrorCnt++;
      end
    end
  endtask

  task VerifyRxEoFGenerated();
    logic EoFSeen;

    EoFSeen = uin_hdlc.Rx_EoF;
    repeat(24) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Rx_EoF)
        EoFSeen = 1'b1;
    end

    // Spec 12: End-of-frame pulse must be observed for completed RX frame.
    assert (EoFSeen) else begin
      $error("RX EoF check failed: Rx_EoF was not observed after completed frame.");
      TbErrorCnt++;
    end
  endtask

  task Receive(int Size, int Abort, int FCSerr, int NonByteAligned, int Overflow, int Drop, int SkipRead, int Transparent);
    logic [127:0][7:0] ReceiveData;
    logic       [15:0] FCSBytes;
    logic   [2:0][7:0] OverflowData;
    string msg;
    if(Abort)
      msg = "- Abort";
    else if(FCSerr)
      msg = "- FCS error";
    else if(NonByteAligned)
      msg = "- Non-byte aligned";
    else if(Overflow)
      msg = "- Overflow";
    else if(Drop)
      msg = "- Drop";
    else if(SkipRead)
      msg = "- Skip read";
    else if(Transparent)
      msg = "- Transparent";
    else
      msg = "- Normal";
    $display("*************************************************************");
    $display("%t - Starting task Receive %s", $time, msg);
    $display("*************************************************************");

    for (int i = 0; i < Size; i++) begin
      if(Transparent)
        ReceiveData[i] = 8'hFF;
      else
        ReceiveData[i] = $urandom;
    end
    ReceiveData[Size]   = '0;
    ReceiveData[Size+1] = '0;

    //Calculate FCS bits;
    GenerateFCSBytes(ReceiveData, Size, FCSBytes);
    ReceiveData[Size]   = FCSBytes[7:0];
    ReceiveData[Size+1] = FCSBytes[15:8];

    if(FCSerr)
      ReceiveData[Size][0] = ~ReceiveData[Size][0];

    //Enable FCS
    if(!Overflow && !NonByteAligned)
      WriteAddress(RXSC, 8'h20);
    else
      WriteAddress(RXSC, 8'h00);

    //Generate stimulus
    InsertFlagOrAbort(1);
    
    MakeRxStimulus(ReceiveData, Size + 2);
    
    if(Overflow) begin
      OverflowData[0] = 8'h44;
      OverflowData[1] = 8'hBB;
      OverflowData[2] = 8'hCC;
      MakeRxStimulus(OverflowData, 3);
    end

    if (NonByteAligned) begin
      // Inject a few extra bits before end-flag to force non-byte-aligned end.
      repeat (3) begin
        @(posedge uin_hdlc.Clk);
        uin_hdlc.Rx = $urandom_range(0, 1);
      end
    end

    if(Abort) begin
      InsertFlagOrAbort(0);
    end else begin
      InsertFlagOrAbort(1);
    end

    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;

    // 11 and 12: monitor CRC result and EoF generation in parallel.
    // Skip abort case since this is not a completed frame.
    if (!Abort) begin
      fork
        VerifyRxCRCAtStopFCS(!Overflow && !NonByteAligned && FCSerr);
        VerifyRxEoFGenerated();
      join
    end

    // Allow status/control bits to settle before register reads.
    repeat(8)
      @(posedge uin_hdlc.Clk);

    if(Drop) begin
      wait(uin_hdlc.Rx_Ready);
      WriteAddress(RXSC, 8'h22);
    end

    VerifyRxStatusControl(Abort, FCSerr, NonByteAligned, Overflow, Drop);
    if (!(Abort || FCSerr || NonByteAligned || Drop)) begin
      if (Overflow)
        VerifyRxFrameSize(126, 1'b1);
      else
        VerifyRxFrameSize(Size, 1'b0);
    end

    if(Abort) begin
      VerifyAbortReceive();
      VerifyReadAfterError();
    end
    else if(FCSerr || Drop || NonByteAligned)
      VerifyReadAfterError();
    else if(Overflow)
      VerifyOverflowReceive(ReceiveData, Size);
    else if(!SkipRead)
      VerifyNormalReceive(ReceiveData, Size);
    #5000ns;
  endtask

  task GenerateFCSBytes(logic [127:0][7:0] data, int size, output logic[15:0] FCSBytes);
    logic [23:0] CheckReg;
    CheckReg[15:8]  = data[1];
    CheckReg[7:0]   = data[0];
    for(int i = 2; i < size+2; i++) begin
      CheckReg[23:16] = data[i];
      for(int j = 0; j < 8; j++) begin
        if(CheckReg[0]) begin
          CheckReg[0]    = CheckReg[0] ^ 1;
          CheckReg[1]    = CheckReg[1] ^ 1;
          CheckReg[13:2] = CheckReg[13:2];
          CheckReg[14]   = CheckReg[14] ^ 1;
          CheckReg[15]   = CheckReg[15];
          CheckReg[16]   = CheckReg[16] ^1;
        end
        CheckReg = CheckReg >> 1;
      end
    end
    FCSBytes = CheckReg;
  endtask

endprogram
