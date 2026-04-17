/****************************************************************************
 * Stimulus tasks
 ****************************************************************************/

// Basic TB tasks

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

// Shared CRC model

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

// Spec stimulus tasks

// [Task 4|5|6|7|8|9|11|17|18]
task Transmit(int Size, int Abort, int Transparent);
  logic [127:0][7:0] TransmitData;
  logic abortReqSeen;
  logic abortedSeen;
  bit tx_active_seen;
  bit tx_done_seen;
  logic [7:0] txsc_after;
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

    repeat(8)
      @(posedge uin_hdlc.Clk);

    abortReqSeen = 1'b0;
    fork
      begin
        repeat(4) begin
          @(posedge uin_hdlc.Clk);
          if (uin_hdlc.Tx_AbortFrame)
            abortReqSeen = 1'b1;
        end
      end
      begin
        WriteAddress(TXSC, 8'h04);
      end
    join

    assert (abortReqSeen) else begin
      $error("ABORT STIM: Tx_AbortFrame pulse was not observed.");
      TbErrorCnt++;
    end

    abortedSeen = 1'b0;
    for (int i = 0; i < 40; i++) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Tx_AbortedTrans) begin
        abortedSeen = 1'b1;
        break;
      end
    end

    assert (abortedSeen) else begin
      $error("ABORT STIM: Tx_AbortedTrans did not assert after abort request.");
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
  if (!tx_done_seen)
    begin
      $error("Transmit timeout waiting for Tx_Done.");
      TbErrorCnt++;
      return;
    end

  ReadAddress(TXSC, txsc_after);

  $display("*************************************************************");
  $display("%t - Finishing task Transmit %s", $time, msg);
  $display("*************************************************************");
endtask

// [Task 1|2|3|6|10|11|12|13|14|15|16]
task Receive(
  int Size,
  int Abort,
  int FCSerr,
  int NonByteAligned,
  int Overflow,
  int Drop,
  int SkipRead,
  int Transparent,
  int RelaxStatusChecks = 0
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

  repeat(8)
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
    if (!ready_seen)
      begin
        $error("Receive drop timeout waiting for Rx_Ready.");
        TbErrorCnt++;
        return;
      end
    WriteAddress(RXSC, 8'h22);
  end

  if (!RelaxStatusChecks)
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

// Baseline directed run

task RunDirectedConcurrentStimulus();
  // TX
  Transmit(16, 0, 0);   // [Task 5 | Spec 5], [Task 7 | Spec 7]
  Transmit(16, 0, 1);   // [Task 6 | Spec 6]
  Transmit(20, 0, 0);   // [Task 17 | Spec 17]
  Transmit(126, 0, 0);  // [Task 18 | Spec 18]
  Transmit(40, 1, 0);   // [Task 8 | Spec 8], [Task 9 | Spec 9]

  // RX
  Receive( 24, 0, 0, 0, 0, 0, 0, 1); // [Task 6 | Spec 6], [Task 12 | Spec 12]
  Receive( 10, 0, 0, 0, 0, 0, 0, 0); // [Task 12 | Spec 12], [Task 15 | Spec 15]
  Receive( 18, 0, 0, 0, 0, 0, 0, 0); // [Task 15 | Spec 15]
  Receive( 20, 0, 1, 0, 0, 0, 0, 0); // [Task 16 | Spec 16]
  Receive( 20, 0, 0, 1, 0, 0, 0, 0); // [Task 16 | Spec 16]
  Receive( 20, 0, 0, 0, 0, 1, 0, 0); // [Task 3 | Spec 3]
  Receive(126, 0, 0, 0, 0, 0, 0, 0); // [Task 14 | Spec 14]
  Receive( 40, 1, 0, 0, 0, 0, 0, 0); // [Task 10 | Spec 10]
  Receive(126, 0, 0, 0, 1, 0, 0, 0); // [Task 13 | Spec 13]

  RunLowCostCoverageBoosters();
endtask

// Optional coverage helpers

task RunLowCostCoverageBoosters();
  logic [127:0][7:0] tx_data;
  bit tx_active_seen;

  Receive(126, 0, 0, 1, 1, 0, 0, 0, 1);

  for (int i = 0; i < 12; i++)
    tx_data[i] = $urandom;
  MakeTxStimulus(tx_data, 12);
  repeat (3)
    WriteAddress(TXSC, 8'h06);

  WriteAddress(TXBUFF, $urandom);

  for (int i = 0; i < 40; i++)
    tx_data[i] = $urandom;
  MakeTxStimulus(tx_data, 40);
  WriteAddress(TXSC, 8'h02);

  tx_active_seen = 1'b0;
  for (int t = 0; t < WAIT_MEDIUM_CYCLES; t++) begin
    @(posedge uin_hdlc.Clk);
    if (uin_hdlc.Tx_ValidFrame) begin
      tx_active_seen = 1'b1;
      break;
    end
  end
  if (tx_active_seen) begin
    repeat (4)
      WriteAddress(TXBUFF, $urandom);
  end

  repeat(200)
    @(posedge uin_hdlc.Clk);
endtask

task RunExtendedStimulus();
  Receive(40, 0, 1, 0, 0, 0, 0, 0);
  Receive(40, 0, 0, 0, 0, 1, 0, 0);
  Receive(45, 0, 0, 0, 0, 0, 0, 0);
  Receive(126, 0, 0, 0, 0, 0, 0, 0);
  Receive(122, 1, 0, 0, 0, 0, 0, 0);
  Receive(25, 0, 0, 0, 0, 0, 0, 0);
  Receive(47, 0, 0, 0, 0, 0, 0, 0);
endtask

task PulseTxDisableDuringIdle();
  bit idle_seen;
  idle_seen = 1'b0;
  for (int t = 0; t < WAIT_LONG_CYCLES; t++) begin
    @(posedge uin_hdlc.Clk);
    if (!uin_hdlc.Tx_ValidFrame) begin
      idle_seen = 1'b1;
      break;
    end
  end
  if (!idle_seen)
    begin
      $error("PulseTxDisableDuringIdle timeout waiting for Tx_ValidFrame=0.");
      TbErrorCnt++;
      return;
    end

  uin_hdlc.TxEN = 1'b0;
  repeat(8)
    @(posedge uin_hdlc.Clk);
  uin_hdlc.TxEN = 1'b1;
endtask

task RunCoverageEdgeStimulus();
  PulseTxDisableDuringIdle();
  Transmit(8,   0, 0);
  Transmit(8,   0, 1);
  Transmit(125, 0, 0);
  Transmit(60,  1, 0);
  Transmit(100, 1, 0);

  Receive(8,   0, 0, 0, 0, 0, 0, 0);
  Receive(8,   0, 0, 0, 0, 0, 0, 1);
  Receive(20,  0, 0, 0, 0, 1, 0, 0);
  Receive(126, 0, 0, 0, 0, 0, 1, 0);
  Receive(12,  0, 0, 0, 0, 0, 0, 0);
  Receive(126, 0, 0, 1, 0, 0, 0, 0);
  Receive(126, 0, 0, 0, 1, 0, 0, 0);

  for (int d = 0; d <= 6; d += 2) begin
    logic [127:0][7:0] tx_data;
    for (int i = 0; i < 12; i++)
      tx_data[i] = $urandom;
    MakeTxStimulus(tx_data, 12);
    repeat(d)
      @(posedge uin_hdlc.Clk);
    WriteAddress(TXSC, 8'h06);
    repeat(200)
      @(posedge uin_hdlc.Clk);
  end

  for (int k = 0; k < 2; k++) begin
    logic [127:0][7:0] tx_data;
    bit tx_active_seen;
    int abort_delay;
    abort_delay = (k == 0) ? 16 : 48;
    for (int i = 0; i < 12; i++)
      tx_data[i] = $urandom;
    MakeTxStimulus(tx_data, 12);
    WriteAddress(TXSC, 8'h02);
    tx_active_seen = 1'b0;
    for (int t = 0; t < WAIT_MEDIUM_CYCLES; t++) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Tx_ValidFrame) begin
        tx_active_seen = 1'b1;
        break;
      end
    end
    if (tx_active_seen) begin
      repeat(abort_delay)
        @(posedge uin_hdlc.Clk);
      WriteAddress(TXSC, 8'h04);
      repeat(200)
        @(posedge uin_hdlc.Clk);
    end else begin
      $error("RunCoverageEdgeStimulus late-abort timeout waiting for Tx_ValidFrame.");
      TbErrorCnt++;
    end
  end

  begin
    bit tx_done_seen;
    for (int i = 0; i < 130; i++)
      WriteAddress(TXBUFF, $urandom);
    WriteAddress(TXSC, 8'h02);
    tx_done_seen = 1'b0;
    for (int t = 0; t < WAIT_LONG_CYCLES; t++) begin
      @(posedge uin_hdlc.Clk);
      if (uin_hdlc.Tx_Done) begin
        tx_done_seen = 1'b1;
        break;
      end
    end
    if (!tx_done_seen) begin
      $error("RunCoverageEdgeStimulus TX full stress timeout waiting for Tx_Done.");
      TbErrorCnt++;
    end
  end
endtask

task RunHighVolumeStimulus(int Repeats);
  int tx_ops;
  int rx_ops;
  int sel;
  int size;

  $display("*************************************************************");
  $display("%t - Starting high-volume stimulus (repeats=%0d)", $time, Repeats);
  $display("*************************************************************");

  for (int r = 0; r < Repeats; r++) begin
    tx_ops = $urandom_range(2, 3);
    for (int t = 0; t < tx_ops; t++) begin
      sel = $urandom_range(0, 9);
      case (sel)
        0, 1, 2, 3, 4: begin
          size = $urandom_range(8, 48);
          Transmit(size, 0, 0);
        end
        5: begin
          size = $urandom_range(8, 32);
          Transmit(size, 0, 1);
        end
        6: begin
          size = $urandom_range(16, 48);
          Transmit(size, 1, 0);
        end
        7: begin
          Transmit(126, 0, 0);
        end
        default: begin
          size = $urandom_range(64, 96);
          Transmit(size, 0, 0);
        end
      endcase
      repeat($urandom_range(1, 3))
        @(posedge uin_hdlc.Clk);
    end

    if (r == (Repeats - 1)) begin
      Transmit($urandom_range(20, 48), 1, 0);
      Transmit(126, 0, 0);
    end

    rx_ops = $urandom_range(2, 4);
    for (int x = 0; x < rx_ops; x++) begin
      sel = $urandom_range(0, 9);
      case (sel)
        0, 1, 2, 3, 4: begin
          size = $urandom_range(8, 64);
          Receive(size, 0, 0, 0, 0, 0, 0, 0);
        end
        5: begin
          size = $urandom_range(8, 32);
          Receive(size, 0, 0, 0, 0, 0, 0, 1);
        end
        6: begin
          size = $urandom_range(16, 64);
          Receive(size, 1, 0, 0, 0, 0, 0, 0);
        end
        7: begin
          size = $urandom_range(12, 64);
          Receive(size, 0, 1, 0, 0, 0, 0, 0);
        end
        8: begin
          size = $urandom_range(12, 64);
          Receive(size, 0, 0, 1, 0, 0, 0, 0);
        end
        default: begin
          Receive(126, 0, 0, 0, 1, 0, 0, 0);
        end
      endcase
      repeat($urandom_range(1, 3))
        @(posedge uin_hdlc.Clk);
    end

    if (r == (Repeats - 1)) begin
      Receive($urandom_range(20, 64), 1, 0, 0, 0, 0, 0, 0);
      Receive(126, 0, 0, 0, 1, 0, 0, 0);
      Receive($urandom_range(12, 64), 0, 1, 0, 0, 0, 0, 0);
      Receive($urandom_range(12, 64), 0, 0, 1, 0, 0, 0, 0);
    end
  end

  $display("*************************************************************");
  $display("%t - Finished high-volume stimulus", $time);
  $display("*************************************************************");
endtask
