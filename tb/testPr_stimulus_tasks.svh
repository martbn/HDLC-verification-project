
/****************************************************************************
 *                             Stimulus test tasks                          *
 ****************************************************************************/

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
  uin_hdlc.Rst = 1'b1;
endtask

task ResetDutPhase();
  uin_hdlc.Address     = 3'b000;
  uin_hdlc.WriteEnable = 1'b0;
  uin_hdlc.ReadEnable  = 1'b0;
  uin_hdlc.DataIn      = '0;
  uin_hdlc.TxEN        = 1'b1;
  uin_hdlc.RxEN        = 1'b1;
  uin_hdlc.Rx          = 1'b1;

  uin_hdlc.Rst = 1'b0;
  repeat (4)
    @(posedge uin_hdlc.Clk);
  uin_hdlc.Rst = 1'b1;
  repeat (4)
    @(posedge uin_hdlc.Clk);
endtask

task WriteAddress(input logic [2:0] Address, input logic [7:0] Data);
  @(posedge uin_hdlc.Clk);
  uin_hdlc.Address     = Address;
  uin_hdlc.WriteEnable = 1'b1;
  uin_hdlc.DataIn      = Data;
  @(posedge uin_hdlc.Clk);
  uin_hdlc.WriteEnable = 1'b0;
endtask

task ReadAddress(input logic [2:0] Address, output logic [7:0] Data);
  @(posedge uin_hdlc.Clk);
  uin_hdlc.Address    = Address;
  uin_hdlc.ReadEnable = 1'b1;
  #100ns;
  Data                = uin_hdlc.DataOut;
  @(posedge uin_hdlc.Clk);
  uin_hdlc.ReadEnable = 1'b0;
endtask

task MakeTxStimulus(logic [127:0][7:0] Data, int Size);
  for (int i = 0; i < Size; i++)
    WriteAddress(TXBUFF, Data[i]);
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
  if (flag)
    uin_hdlc.Rx = 1'b0;
  else
    uin_hdlc.Rx = 1'b1;
endtask

task MakeRxStimulus(logic [127:0][7:0] Data, int Size);
  logic [4:0] PrevData;
  PrevData = '0;
  for (int i = 0; i < Size; i++) begin
    for (int j = 0; j < 8; j++) begin
      if (&PrevData) begin
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

// ---------------------------------------------------------------------------
// Shared CRC model
// ---------------------------------------------------------------------------

task GenerateFCSBytes(logic [127:0][7:0] data, int size, output logic [15:0] FCSBytes);
  logic [23:0] CheckReg;
  CheckReg[15:8] = data[1];
  CheckReg[7:0]  = data[0];
  for (int i = 2; i < size + 2; i++) begin
    CheckReg[23:16] = data[i];
    for (int j = 0; j < 8; j++) begin
      if (CheckReg[0]) begin
        CheckReg[0]    = CheckReg[0] ^ 1;
        CheckReg[1]    = CheckReg[1] ^ 1;
        CheckReg[13:2] = CheckReg[13:2];
        CheckReg[14]   = CheckReg[14] ^ 1;
        CheckReg[15]   = CheckReg[15];
        CheckReg[16]   = CheckReg[16] ^ 1;
      end
      CheckReg = CheckReg >> 1;
    end
  end
  FCSBytes = CheckReg;
endtask

// ---------------------------------------------------------------------------
// TX stimulus
// ---------------------------------------------------------------------------

task Transmit(int Size, int Abort, int Transparent);
  logic [127:0][7:0] TransmitData;
  bit tx_active_seen;
  bit tx_done_seen;
  bit abort_req_seen;
  bit abort_seen;
  string msg;

  if (Abort)
    msg = "- Abort";
  else if (Transparent)
    msg = "- Transparent";
  else
    msg = "- Normal";

  $display("*************************************************************");
  $display("%t - Starting task Transmit %s", $time, msg);
  $display("*************************************************************");

  assert ((Size > 0) && (Size <= 126)) else begin
    $error("Transmit invalid Size=%0d (expected 1..126).", Size);
    TbErrorCnt++;
    return;
  end

  for (int i = 0; i < Size; i++) begin
    if (Transparent)
      TransmitData[i] = 8'hFF;
    else
      TransmitData[i] = $urandom;
  end

  MakeTxStimulus(TransmitData, Size);
  WriteAddress(TXSC, 8'h02);

  if (!Abort)
    VerifyTxOutput(TransmitData, Size);

  if (Abort) begin
    tx_active_seen = 1'b0;
    for (int t = 0; t < WAIT_MEDIUM_CYCLES; t++) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Tx_ValidFrame) begin
        tx_active_seen = 1'b1;
        break;
      end
    end

    if (!tx_active_seen) begin
      $error("Transmit abort timeout waiting for Tx_ValidFrame.");
      TbErrorCnt++;
      return;
    end

    repeat (8)
      @(posedge uin_hdlc.Clk);

    abort_req_seen = 1'b0;
    fork
      begin
        repeat (4) begin
          @(posedge uin_hdlc.Clk);
          if (uin_hdlc.Tx_AbortFrame)
            abort_req_seen = 1'b1;
        end
      end
      begin
        WriteAddress(TXSC, 8'h04);
      end
    join

    assert (abort_req_seen) else begin
      $error("Transmit abort: Tx_AbortFrame pulse was not observed.");
      TbErrorCnt++;
    end

    abort_seen = 1'b0;
    for (int i = 0; i < 40; i++) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Tx_AbortedTrans) begin
        abort_seen = 1'b1;
        break;
      end
    end

    assert (abort_seen) else begin
      $error("Transmit abort: Tx_AbortedTrans did not assert.");
      TbErrorCnt++;
    end
  end

  tx_done_seen = 1'b0;
  for (int t = 0; t < WAIT_LONG_CYCLES; t++) begin
    @(posedge uin_hdlc.Clk);
    if (uin_hdlc.Tx_Done) begin
      tx_done_seen = 1'b1;
      break;
    end
  end

  if (!tx_done_seen) begin
    $error("Transmit timeout waiting for Tx_Done.");
    TbErrorCnt++;
    return;
  end

  $display("*************************************************************");
  $display("%t - Finishing task Transmit %s", $time, msg);
  $display("*************************************************************");
endtask

// ---------------------------------------------------------------------------
// RX stimulus
// ---------------------------------------------------------------------------

task ReceiveCore(
  int Size,
  int Abort,
  int FCSerr,
  int NonByteAligned,
  int Overflow,
  int Drop,
  int SkipRead,
  int Transparent
);
  logic [127:0][7:0] ReceiveData;
  logic [15:0] FCSBytes;
  logic [2:0][7:0] OverflowData;
  bit ready_seen;
  string msg;

  if (Abort)
    msg = "- Abort";
  else if (FCSerr)
    msg = "- FCS error";
  else if (NonByteAligned)
    msg = "- Non-byte aligned";
  else if (Overflow)
    msg = "- Overflow";
  else if (Drop)
    msg = "- Drop";
  else if (SkipRead)
    msg = "- Skip read";
  else if (Transparent)
    msg = "- Transparent";
  else
    msg = "- Normal";

  $display("*************************************************************");
  $display("%t - Starting task Receive %s", $time, msg);
  $display("*************************************************************");

  assert ((Size > 0) && (Size <= 126)) else begin
    $error("Receive invalid Size=%0d (expected 1..126).", Size);
    TbErrorCnt++;
    return;
  end

  for (int i = 0; i < Size; i++) begin
    if (Transparent)
      ReceiveData[i] = 8'hFF;
    else
      ReceiveData[i] = $urandom;
  end

  ReceiveData[Size]   = '0;
  ReceiveData[Size+1] = '0;

  GenerateFCSBytes(ReceiveData, Size, FCSBytes);
  ReceiveData[Size]   = FCSBytes[7:0];
  ReceiveData[Size+1] = FCSBytes[15:8];

  if (FCSerr)
    ReceiveData[Size][0] = ~ReceiveData[Size][0];

  if (!Overflow && !NonByteAligned)
    WriteAddress(RXSC, 8'h20);
  else
    WriteAddress(RXSC, 8'h00);

  InsertFlagOrAbort(1);
  MakeRxStimulus(ReceiveData, Size + 2);

  if (Overflow) begin
    OverflowData[0] = 8'h44;
    OverflowData[1] = 8'hBB;
    OverflowData[2] = 8'hCC;
    MakeRxStimulus(OverflowData, 3);
  end

  if (NonByteAligned) begin
    repeat (3) begin
      @(posedge uin_hdlc.Clk);
      uin_hdlc.Rx = $urandom_range(0, 1);
    end
  end

  if (Abort)
    InsertFlagOrAbort(0);
  else
    InsertFlagOrAbort(1);

  @(posedge uin_hdlc.Clk);
  uin_hdlc.Rx = 1'b1;

  if (!Abort) begin
    if (!Overflow && !NonByteAligned) begin
      fork
        VerifyRxCRCAtStopFCS(FCSerr);
        VerifyRxEoFGenerated();
      join
    end else begin
      VerifyRxEoFGenerated();
    end
  end

  repeat (8)
    @(posedge uin_hdlc.Clk);

  if (Drop) begin
    ready_seen = 1'b0;
    for (int t = 0; t < WAIT_MEDIUM_CYCLES; t++) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Rx_Ready) begin
        ready_seen = 1'b1;
        break;
      end
    end

    if (!ready_seen) begin
      $error("Receive drop timeout waiting for Rx_Ready.");
      TbErrorCnt++;
      return;
    end

    WriteAddress(RXSC, 8'h22);
  end

  VerifyRxStatusControl(Abort, FCSerr, NonByteAligned, Overflow, Drop);

  if (!(Abort || FCSerr || NonByteAligned || Drop)) begin
    if (Overflow)
      VerifyRxFrameSize(126, 1'b1);
    else
      VerifyRxFrameSize(Size, 1'b0);
  end

  if (Abort) begin
    VerifyAbortReceive();
    VerifyReadAfterError();
  end else if (FCSerr || Drop || NonByteAligned) begin
    VerifyReadAfterError();
  end else if (Overflow) begin
    VerifyOverflowReceive(ReceiveData, Size);
  end else if (!SkipRead) begin
    VerifyNormalReceive(ReceiveData, Size);
  end

  #5000ns;
endtask

task Receive(int Size, int Abort, int FCSerr, int NonByteAligned, int Overflow, int Drop, int SkipRead);
  ReceiveCore(Size, Abort, FCSerr, NonByteAligned, Overflow, Drop, SkipRead, 0);
endtask

task ReceiveTransparent(int Size);
  ReceiveCore(Size, 0, 0, 0, 0, 0, 0, 1);
endtask

// ---------------------------------------------------------------------------
// Simple run phases
// ---------------------------------------------------------------------------

task RunBasicStimulus();
  // Basic TX
  Transmit(16, 0, 0); // normal
  Transmit(16, 0, 1); // transparent
  Transmit(40, 1, 0); // abort

  // Basic RX
  Receive( 10, 0, 0, 0, 0, 0, 0); // normal
  Receive( 40, 1, 0, 0, 0, 0, 0); // abort
  Receive(126, 0, 0, 0, 1, 0, 0); // overflow
  Receive( 45, 0, 0, 0, 0, 0, 0); // normal
  Receive(126, 0, 0, 0, 0, 0, 0); // normal
  Receive(122, 1, 0, 0, 0, 0, 0); // abort
  Receive(126, 0, 0, 0, 1, 0, 0); // overflow
  Receive( 25, 0, 0, 0, 0, 0, 0); // normal
  Receive( 47, 0, 0, 0, 0, 0, 0); // normal
endtask

task RunTargetedStimulus();
  // Targeted TX edge cases
  Transmit(8,   0, 0);
  Transmit(126, 0, 0);
  Transmit(24,  0, 1);
  Transmit(24,  1, 0);

  // Targeted RX edge/error cases
  ReceiveTransparent(24);
  Receive(20, 0, 1, 0, 0, 0, 0); // FCS error
  Receive(20, 0, 0, 1, 0, 0, 0); // non-byte aligned
  Receive(20, 0, 0, 0, 0, 1, 0); // drop
  Receive(24, 0, 0, 0, 0, 0, 1); // skip read
  Receive(126, 0, 0, 0, 1, 0, 0); // overflow
  Receive(12, 0, 0, 0, 0, 0, 0); // recovery normal
endtask

task RunRandomStimulus(int Repeats);
  int size;
  int sel;

  $display("*************************************************************");
  $display("%t - Starting random stimulus (repeats=%0d)", $time, Repeats);
  $display("*************************************************************");

  for (int r = 0; r < Repeats; r++) begin
    size = $urandom_range(8, 48);
    Transmit(size, 0, 0);

    size = $urandom_range(8, 48);
    Receive(size, 0, 0, 0, 0, 0, 0);

    sel = $urandom_range(0, 3);
    case (sel)
      0: Receive($urandom_range(8, 40), 1, 0, 0, 0, 0, 0);
      1: Receive($urandom_range(8, 40), 0, 1, 0, 0, 0, 0);
      2: Receive($urandom_range(8, 40), 0, 0, 1, 0, 0, 0);
      default: Receive(126, 0, 0, 0, 1, 0, 0);
    endcase
  end

  $display("*************************************************************");
  $display("%t - Finished random stimulus", $time);
  $display("*************************************************************");
endtask
