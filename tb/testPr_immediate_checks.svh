/****************************************************************************
 * Immediate checks
 ****************************************************************************/

// Common check helpers

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

// [Task 1 | Spec 1] + [Task 3 | Spec 3]
task VerifyNormalReceive(logic [127:0][7:0] data, int Size);
  logic [7:0] rxsc;
  logic [7:0] rxbuff;
  bit ready_seen;

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
      $error("VerifyNormalReceive timeout waiting for Rx_Ready.");
      TbErrorCnt++;
      return;
    end

  ReadAddress(RXSC, rxsc);

  CheckBitEq("NORMAL RXSC[0] mismatch.", rxsc[0], 1'b1, rxsc);
  CheckBitEq("NORMAL RXSC[2] mismatch.", rxsc[2], 1'b0, rxsc);
  CheckBitEq("NORMAL RXSC[3] mismatch.", rxsc[3], 1'b0, rxsc);
  CheckBitEq("NORMAL RXSC[4] mismatch.", rxsc[4], 1'b0, rxsc);

  CheckIntLe("NORMAL payload size exceeds 126 bytes.", Size, 126);

  for (int i = 0; i < Size; i++) begin
    ReadAddress(RXBUFF, rxbuff);
    assert (rxbuff == data[i]) else begin
      $error("NORMAL data mismatch at byte %0d. Exp=0x%0h Got=0x%0h", i, data[i], rxbuff);
      TbErrorCnt++;
    end
  end
endtask

// [Task 1 | Spec 1] + [Task 3 | Spec 3] + [Task 13 | Spec 13]
task VerifyOverflowReceive(logic [127:0][7:0] data, int Size);
  logic [7:0] rxsc;
  logic [7:0] rxbuff;
  bit ready_seen;

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
      $error("VerifyOverflowReceive timeout waiting for Rx_Ready.");
      TbErrorCnt++;
      return;
    end

  ReadAddress(RXSC, rxsc);

  CheckBitEq("OVERFLOW RXSC[0] mismatch.", rxsc[0], 1'b1, rxsc);
  CheckBitEq("OVERFLOW RXSC[4] mismatch.", rxsc[4], 1'b1, rxsc);
  CheckIntLe("OVERFLOW payload size exceeds 126 bytes.", Size, 126);

  for (int i = 0; i < Size; i++) begin
    ReadAddress(RXBUFF, rxbuff);
    assert (rxbuff == data[i]) else begin
      $error("OVERFLOW data mismatch at byte %0d. Exp=0x%0h Got=0x%0h", i, data[i], rxbuff);
      TbErrorCnt++;
    end
  end
endtask

// [Task 2 | Spec 2]
task VerifyReadAfterError();
  logic [7:0] rxbuff;
  bit not_ready_seen;

  not_ready_seen = 1'b0;
  for (int t = 0; t < WAIT_MEDIUM_CYCLES; t++) begin
    @(posedge uin_hdlc.Clk);
    if (!uin_hdlc.Rx_Ready) begin
      not_ready_seen = 1'b1;
      break;
    end
  end
  if (!not_ready_seen)
    begin
      $error("VerifyReadAfterError timeout waiting for Rx_Ready to deassert.");
      TbErrorCnt++;
      return;
    end

  ReadAddress(RXBUFF, rxbuff);
  CheckByteEq("READ AFTER ERROR RXBUFF mismatch.", rxbuff, 8'h00);
endtask

// [Task 2 | Spec 2] + [Task 3 | Spec 3]
task VerifyAbortReceive();
  logic [7:0] rxsc;
  logic [7:0] rxbuff;

  ReadAddress(RXSC, rxsc);
  ReadAddress(RXBUFF, rxbuff);

  CheckBitEq("ABORT RXSC[3] mismatch.", rxsc[3], 1'b1, rxsc);
  CheckBitEq("ABORT RXSC[0] mismatch.", rxsc[0], 1'b0, rxsc);
  CheckByteEq("ABORT RXBUFF mismatch.", rxbuff, 8'h00);
endtask

// [Task 3 | Spec 3]
task VerifyRxStatusControl(int Abort, int FCSerr, int NonByteAligned, int Overflow, int Drop);
  logic [7:0] rxsc;
  logic [7:0] exp;

  exp[0] = !(Abort || FCSerr || NonByteAligned || Drop);
  exp[1] = 1'b0;
  exp[2] = (FCSerr || NonByteAligned);
  exp[3] = Abort;
  exp[4] = Overflow;
  exp[5] = (!Overflow && !NonByteAligned);
  exp[7:6] = 2'b00;

  ReadAddress(RXSC, rxsc);

  CheckBitEq("RXSC[0] mismatch.", rxsc[0], exp[0], rxsc);
  CheckBitEq("RXSC[1] mismatch.", rxsc[1], exp[1], rxsc);
  CheckBitEq("RXSC[2] mismatch.", rxsc[2], exp[2], rxsc);
  CheckBitEq("RXSC[3] mismatch.", rxsc[3], exp[3], rxsc);
  CheckBitEq("RXSC[4] mismatch.", rxsc[4], exp[4], rxsc);
  CheckBitEq("RXSC[5] mismatch.", rxsc[5], exp[5], rxsc);

  assert (rxsc[7:6] == 2'b00) else begin
    $error("RXSC[7:6] mismatch. Exp=00 Got=%0b RXSC=0x%0h", rxsc[7:6], rxsc);
    TbErrorCnt++;
  end
endtask

// TX helpers/checks

task ReadTxByteNoStuff(output logic [7:0] TxByte, inout int OnesCnt);
  int BitIdx;
  int Cycles;
  TxByte = '0;
  BitIdx = 0;
  Cycles = 0;

  while (BitIdx < 8) begin
    Cycles++;
    if (Cycles > WAIT_MEDIUM_CYCLES) begin
      $error("ReadTxByteNoStuff timeout: could not collect 8 TX bits (BitIdx=%0d).", BitIdx);
      TbErrorCnt++;
      break;
    end

    @(posedge uin_hdlc.Clk);

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

// [Task 4 | Spec 4] + [Task 11 | Spec 11]
task VerifyTxOutput(logic [127:0][7:0] data, int Size);
  logic [127:0][7:0] CRCInputData;
  logic [7:0] ShiftReg;
  logic [7:0] TxByte;
  logic [7:0] TxFCSByte0;
  logic [7:0] TxFCSByte1;
  logic [15:0] ExpFCSBytes;
  int ByteIdx;
  int OnesCnt;
  bit start_flag_seen;

  ShiftReg = '0;
  OnesCnt = 0;
  start_flag_seen = 1'b0;
  CRCInputData = '0;
  for (int i = 0; i < Size; i++)
    CRCInputData[i] = data[i];
  CRCInputData[Size]   = 8'h00;
  CRCInputData[Size+1] = 8'h00;

  for (int c = 0; c < WAIT_LONG_CYCLES; c++) begin
    @(posedge uin_hdlc.Clk);
    ShiftReg = {uin_hdlc.Tx, ShiftReg[7:1]};
    if (ShiftReg == 8'b0111_1110) begin
      start_flag_seen = 1'b1;
      break;
    end
  end

  assert (start_flag_seen) else begin
    $error("VerifyTxOutput timeout: start flag 0x7E not detected.");
    TbErrorCnt++;
    return;
  end

  for (ByteIdx = 0; ByteIdx < Size; ByteIdx++) begin
    ReadTxByteNoStuff(TxByte, OnesCnt);
    assert (TxByte == data[ByteIdx]) else begin
      $error("TX OUTPUT mismatch at byte %0d. Exp=0x%0h Got=0x%0h", ByteIdx, data[ByteIdx], TxByte);
      TbErrorCnt++;
    end
  end

  GenerateFCSBytes(CRCInputData, Size, ExpFCSBytes);

  ReadTxByteNoStuff(TxFCSByte0, OnesCnt);
  assert (TxFCSByte0 == ExpFCSBytes[7:0]) else begin
    $error("CRC TX byte0 mismatch. Expected 0x%0h, got 0x%0h", ExpFCSBytes[7:0], TxFCSByte0);
    TbErrorCnt++;
  end

  ReadTxByteNoStuff(TxFCSByte1, OnesCnt);
  assert (TxFCSByte1 == ExpFCSBytes[15:8]) else begin
    $error("CRC TX byte1 mismatch. Expected 0x%0h, got 0x%0h", ExpFCSBytes[15:8], TxFCSByte1);
    TbErrorCnt++;
  end
endtask

// [Task 11 | Spec 11]
task VerifyRxCRCAtStopFCS(int ExpectFCSerr);
  logic StopFCSSeen;
  logic FCSerrAtStopFCS;

  StopFCSSeen = 1'b0;
  FCSerrAtStopFCS = 1'b0;

  repeat(24) begin
    @(posedge uin_hdlc.Clk);
    if (uin_hdlc.Rx_StopFCS && !StopFCSSeen) begin
      StopFCSSeen = 1'b1;
      @(posedge uin_hdlc.Clk);
      FCSerrAtStopFCS = uin_hdlc.Rx_FCSerr;
    end
  end

  assert (StopFCSSeen) else begin
    $error("CRC RX check failed: Rx_StopFCS was not observed.");
    TbErrorCnt++;
  end

  if (StopFCSSeen) begin
    assert (FCSerrAtStopFCS == ExpectFCSerr) else begin
      $error("CRC RX check failed: expected Rx_FCSerr=%0b at StopFCS, got %0b",
             ExpectFCSerr, FCSerrAtStopFCS);
      TbErrorCnt++;
    end
  end
endtask

// [Task 12 | Spec 12]
task VerifyRxEoFGenerated();
  logic EoFSeen;

  EoFSeen = uin_hdlc.Rx_EoF;
  repeat(24) begin
    @(posedge uin_hdlc.Clk);
    if (uin_hdlc.Rx_EoF)
      EoFSeen = 1'b1;
  end

  assert (EoFSeen) else begin
    $error("RX EoF check failed: Rx_EoF was not observed after completed frame.");
    TbErrorCnt++;
  end
endtask

// [Task 14 | Spec 14]
task VerifyRxFrameSize(int exp_size, bit is_overflow_case);
  logic [7:0] rxlen;

  if (is_overflow_case)
    framesize_checked_overflow_seen = 1'b1;
  else
    framesize_checked_normal_seen = 1'b1;

  ReadAddress(RXLEN, rxlen);
  CheckByteEq("RXLEN mismatch.", rxlen, exp_size[7:0]);
endtask
