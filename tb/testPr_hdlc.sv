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

  

  /****************************************************************************
   *                                                                          *
   *                               Student code                               *
   *                                                                          *
   ****************************************************************************/

  // Register address definitions (Fixes the simulation error)
  localparam logic [2:0] RXSC   = 3'b010;  // RX Status/Control
  localparam logic [2:0] RXBUFF = 3'b011;  // RX Data Buffer

  // VerifyAbortReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer is zero after abort.
  task VerifyAbortReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadDataRXSC;
    logic [7:0] ReadDataBUFF;

    ReadAddress(RXSC, ReadDataRXSC);
    ReadAddress(RXBUFF, ReadDataBUFF);

    // Verify that Rx_AbortedFrame bit = 1 and RxReady = 0
    assert (ReadDataRXSC[3] == 1'b1)begin
      $display("PASS: Rx_AbortedFrame bit = 1");
    end else begin
      $error("ABORT: Rx_AbortedFrame bit not set. Expected ReadData[3]=1, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    assert (ReadDataRXSC[0] == 1'b0) else begin
      $error("ABORT: RxReady bit should not be set after abort. Expected ReadData[0]=0, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    
    // Verify that the RX data = 0x00
    assert (ReadDataBUFF == 8'h00) else begin
      $error("ABORT: RX data buffer not cleared. Expected 0x00, got 0x%0h", ReadDataBUFF);
      TbErrorCnt++;
    end

  endtask

  // VerifyNormalReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer contains correct data.
  task VerifyNormalReceive(logic [127:0][7:0] data, int Size);
    logic [7:0] ReadDataRXSC;
    logic [7:0] ReadDataRXBUFF;
    wait(uin_hdlc.Rx_Ready);
    ReadAddress(RXSC, ReadDataRXSC);
    
    // Verify that RxReady =1
    assert (ReadDataRXSC[0] == 1'b1) else begin
      $error("NORMAL: RxReady bit not set. Expected ReadData[0]=1, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    
    // Verify that Rx_FrameError = Rx_AbortSignal = Rx_Overflow = 0
    assert (ReadDataRXSC[2] == 1'b0) else begin
      $error("NORMAL: Rx_FrameError bit set. Expected ReadData[2]=0, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    assert (ReadDataRXSC[3] == 1'b0) else begin
      $error("NORMAL: Rx_AbortedFrame bit set. Expected ReadData[3]=0, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    assert (ReadDataRXSC[4] == 1'b0) else begin
      $error("NORMAL: Rx_Overflow bit set. Expected ReadData[4]=0, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    
    // Verify the received data matches expected data
    // ReadAddress(RXBUFF, ...) auto-increments the internal buffer pointer
    for (int i = 0; i < Size; i++) begin
      ReadAddress(RXBUFF, ReadDataRXBUFF);
      assert (ReadDataRXBUFF == data[i]) else begin
        $error("NORMAL: Data mismatch at byte %0d. Expected 0x%0h, got 0x%0h", i, data[i], ReadDataRXBUFF);
        TbErrorCnt++;
      end
    end
  
  endtask

  // VerifyOverflowReceive should verify correct value in the Rx status/control
  // register, and that the Rx data buffer contains correct data.
  task VerifyOverflowReceive(logic [127:0][7:0] data, int Size);
    
    logic [7:0] ReadDataRXSC;
    logic [7:0] ReadDataRXBUFF;
    wait(uin_hdlc.Rx_Ready);

    // Read RX Status/Control register
    ReadAddress(RXSC, ReadDataRXSC);

    // Verify that RxReady bit = 1 and Rx_overflow = 1
    assert (ReadDataRXSC[0] == 1'b1) else begin
      $error("OVERFLOW: RxReady bit not set. Expected ReadData[0]=1, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    assert (ReadDataRXSC[4] == 1'b1) else begin
      $error("OVERFLOW: Rx_Overflow bit not set. Expected ReadData[4]=1, got ReadData=0x%0h", ReadDataRXSC);
      TbErrorCnt++;
    end
    
    /*
    // Verify that the RX data buffer contains valid data (not all zeros)
    assert (ReadDataRXBUFF != 8'h00) else begin
      $error("OVERFLOW: RX data buffer is zero. Expected valid data, got 0x%0h", ReadDataRXBUFF);
      TbErrorCnt++;
    end
    */
    
    // Verify the received data matches expected data
    // ReadAddress(RXBUFF, ...) auto-increments the internal buffer pointer
    for (int i = 0; i < Size; i++) begin
      ReadAddress(RXBUFF, ReadDataRXBUFF);
      assert (ReadDataRXBUFF == data[i]) else begin
        $error("OVERFLOW: Data mismatch at byte %0d. Expected 0x%0h, got 0x%0h", i, data[i], ReadDataRXBUFF);
        TbErrorCnt++;
      end
    end
endtask

//Part B
//1 Correct data in RX buffer according to RX input. The buffer should contain up to 128 bytes
//(this includes the 2 FCS bytes, but not the flags).

task VerifyBufferData(logic [127:0][7:0] data, int Size);
  logic [7:0] ReadDataRXSC;
  logic [7:0] ReadDataBUFF;
  wait(uin_hdlc.Rx_Ready);


  ReadAddress(RXSC, ReadDataRXSC);

  assert (ReadDataRXSC[0] == 1'b1) else begin
    $error("BUFFER: RxReady bit not set. Expected ReadData[0]=1, got ReadData=0x%0h", ReadDataRXSC);
    TbErrorCnt++;
  end
  assert (Size <= 126) else begin
    $error("BUFFER: Payload size is more than 126 bytes (128 including FCS). Got %0d", Size);
    TbErrorCnt++;
  end

  for (int i = 0; i < Size; i++) begin
    ReadAddress(RXBUFF, ReadDataBUFF);
    assert (ReadDataBUFF == data[i]) else begin
      $error("BUFFER: Data mismatch at byte %0d. Expected 0x%0h, got 0x%0h", 
             i, data[i], ReadDataBUFF);
      TbErrorCnt++;
    end
  end

endtask

  // 2 Attempting to read RX buffer after aborted frame, frame error or dropped frame should result
  //in zeros.
  task VerifyReadAfterError();
    logic [7:0] ReadDataBUFF;
    wait(uin_hdlc.Rx_Ready == 1'b0);

    ReadAddress(RXBUFF, ReadDataBUFF);
    assert (ReadDataBUFF == 8'h00) else begin
      $error("READ AFTER ERROR: RX data buffer not zero after error. Expected 0x00, got 0x%0h", ReadDataBUFF);
      TbErrorCnt++;
    end
    
  endtask

// 3 Correct bits set in RX status/control register after receiving frame. Remember to check all bits.
//I.e. after an abort the Rx Overflow bit should be 0, unless an overflow also occurred.

//4. Correct TX output according to written TX buffer.

//5. Start and end of frame pattern generation (Start and end flag: 0111 1110).

//6. Zero insertion and removal for transparent transmission.

//7. Idle pattern generation and checking (1111 1111 when not operating).

//8. Abort pattern generation and checking (1111 1110). Remember that the 0 must be sent first.

//9. When aborting frame during transmission, Tx AbortedTrans should be asserted.

//10. Abort pattern detected during valid frame should generate Rx AbortSignal.

//11. CRC generation and Checking.

//12. When a whole RX frame has been received, check if end of frame is generated.

//13. When receiving more than 128 bytes, Rx Overflow should be asserted.

//14. Rx FrameSize should equal the number of bytes received in a frame (max. 126 bytes =128 bytes
//in buffer – 2 FCS bytes).

//15. Rx Ready should indicate byte(s) in RX buffer is ready to be read.

//16. Non-byte aligned data or error in FCS checking should result in frame error.

//17. Tx Done should be asserted when the entire TX buffer has been read for transmission.

//18. Tx Full should be asserted after writing 126 or more bytes to the TX buffer (overflow)
  
  



  /****************************************************************************
   *                                                                          *
   *                             Simulation code                              *
   *                                                                          *
   ****************************************************************************/

  initial begin
    $display("*************************************************************");
    $display("%t - Starting Test Program", $time);
    $display("*************************************************************");

    Init();

    //Receive: Size, Abort, FCSerr, NonByteAligned, Overflow, Drop, SkipRead
    Receive( 10, 0, 0, 0, 0, 0, 0); //Normal
    Receive( 40, 1, 0, 0, 0, 0, 0); //Abort
    Receive( 40, 0, 1, 0, 0, 0, 0); //FCS error   added for task 2, part b
    Receive( 40, 0, 0, 0, 0, 1, 0); //Drop        added for task 2, part b
    Receive(126, 0, 0, 0, 1, 0, 0); //Overflow
    Receive( 45, 0, 0, 0, 0, 0, 0); //Normal
    Receive(126, 0, 0, 0, 0, 0, 0); //Normal
    Receive(122, 1, 0, 0, 0, 0, 0); //Abort
    Receive(126, 0, 0, 0, 1, 0, 0); //Overflow
    Receive( 25, 0, 0, 0, 0, 0, 0); //Normal
    Receive( 47, 0, 0, 0, 0, 0, 0); //Normal

    $display("*************************************************************");
    $display("%t - Finishing Test Program", $time);
    $display("*************************************************************");
    $stop;
  end

  final begin

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

  task Receive(int Size, int Abort, int FCSerr, int NonByteAligned, int Overflow, int Drop, int SkipRead);
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
    else
      msg = "- Normal";
    $display("*************************************************************");
    $display("%t - Starting task Receive %s", $time, msg);
    $display("*************************************************************");

    for (int i = 0; i < Size; i++) begin
      ReceiveData[i] = $urandom;
    end
    ReceiveData[Size]   = '0;
    ReceiveData[Size+1] = '0;

    //Calculate FCS bits;
    GenerateFCSBytes(ReceiveData, Size, FCSBytes);
    ReceiveData[Size]   = FCSBytes[7:0];
    ReceiveData[Size+1] = FCSBytes[15:8];

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

    if(Abort) begin
      InsertFlagOrAbort(0);
    end else begin
      InsertFlagOrAbort(1);
    end

    @(posedge uin_hdlc.Clk);
    uin_hdlc.Rx = 1'b1;

    repeat(8)
      @(posedge uin_hdlc.Clk);

    if(Abort)
      VerifyAbortReceive(ReceiveData, Size);
    else if(Overflow)
      VerifyOverflowReceive(ReceiveData, Size);
    else if(!SkipRead) begin
      VerifyNormalReceive(ReceiveData, Size);
     // VerifyBufferData(ReceiveData, Size);
    end
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
