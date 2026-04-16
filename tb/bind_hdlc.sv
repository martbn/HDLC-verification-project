//////////////////////////////////////////////////
// Title:   bind_hdlc
// Author:  Karianne Krokan Kragseth
// Date:    20.10.2017
//////////////////////////////////////////////////

module bind_hdlc ();

  bind test_hdlc assertions_hdlc u_assertion_bind(
    .ErrCntAssertions (uin_hdlc.ErrCntAssertions),
    .Clk              (uin_hdlc.Clk),
    .Rst              (uin_hdlc.Rst),
    .Tx               (uin_hdlc.Tx),
    .TxD              (uin_hdlc.TxD),
    .Tx_Done          (uin_hdlc.Tx_Done),
    .Tx_Full          (uin_hdlc.Tx_Full),
    .Tx_WrBuff        (uin_hdlc.Tx_WrBuff),
    .Tx_AbortFrame    (uin_hdlc.Tx_AbortFrame),
    .Tx_ValidFrame    (uin_hdlc.Tx_ValidFrame),
    .Tx_AbortedTrans  (uin_hdlc.Tx_AbortedTrans),
    .Rx               (uin_hdlc.Rx),
    .Rx_FlagDetect    (uin_hdlc.Rx_FlagDetect),
    .Rx_ValidFrame    (uin_hdlc.Rx_ValidFrame),
    .Rx_StartZeroDetect (uin_hdlc.Rx_StartZeroDetect),
    .Rx_AbortDetect   (uin_hdlc.Rx_AbortDetect),
    .Rx_AbortSignal   (uin_hdlc.Rx_AbortSignal),
    .Rx_NewByte       (uin_hdlc.Rx_NewByte),
    .RxD              (uin_hdlc.RxD),
    .ZeroDetect       (uin_hdlc.ZeroDetect),
    .Rx_EoF           (uin_hdlc.Rx_EoF),
    .Rx_Ready         (uin_hdlc.Rx_Ready),
    .Rx_RdBuff        (uin_hdlc.Rx_RdBuff),
    .Rx_FrameError    (uin_hdlc.Rx_FrameError),
    .Rx_FCSerr        (uin_hdlc.Rx_FCSerr),
    .Rx_Drop          (uin_hdlc.Rx_Drop),
    .Rx_FrameSize     (uin_hdlc.Rx_FrameSize),
    .Rx_Overflow      (uin_hdlc.Rx_Overflow),
    .Rx_WrBuff        (uin_hdlc.Rx_WrBuff)
  );

endmodule