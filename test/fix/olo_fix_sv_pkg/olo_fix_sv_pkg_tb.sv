`default_nettype none

module olo_fix_sv_pkg_tb();

  localparam FWD_SIGN = 1;
  localparam FWD_INT = 37;
  localparam FWD_FRAC = 14;
  localparam olo_fix_sv_pkg::FixFormat_t FWD_FMT = '{FWD_SIGN,
                                                     FWD_INT,
                                                     FWD_FRAC};
  localparam RVS_SIGN = 0;
  localparam RVS_INT = 65;
  localparam RVS_FRAC = 19;
  localparam string RVS_FMT = $sformatf("(%0d,%0d,%0d)",
                                        RVS_SIGN,
                                        RVS_INT,
                                        RVS_FRAC);

  bit failed;

  task automatic test();
    string fwd_test;
    olo_fix_sv_pkg::FixFormat_t rvs_test = olo_fix_sv_pkg::
                                             fixFmtFromString(RVS_FMT);

    failed = '0;

    // test the string-to-struct functions
    assert (RVS_SIGN == rvs_test.S &&
            RVS_SIGN == olo_fix_sv_pkg::fixFmtS(RVS_FMT)) else begin
      failed = '1;
      $error("problem in string to FixFormat_t.S");
    end

    assert (RVS_INT == rvs_test.I &&
            RVS_INT == olo_fix_sv_pkg::fixFmtI(RVS_FMT)) else begin
      failed = '1;
      $error("problem in string to FixFormat_t.I");
    end

    assert (RVS_FRAC == rvs_test.F &&
            RVS_FRAC == olo_fix_sv_pkg::fixFmtF(RVS_FMT)) else begin
      failed = '1;
      $error("problem in string to FixFormat_t.F");
    end

    // test the struct-to-string function
    fwd_test = olo_fix_sv_pkg::fixFmtToString(FWD_FMT);
    assert (fwd_test == $sformatf("(%0d,%0d,%0d)", FWD_SIGN, FWD_INT, FWD_FRAC)) else begin
      failed = '1;
      $error("problem in FixFormat_t to string");
    end

    assert (olo_fix_sv_pkg::fixFmtS(fwd_test) == FWD_SIGN) else begin
      failed = '1;
      $error("problem in FixFormat_t.S to string");
    end

    assert (olo_fix_sv_pkg::fixFmtI(fwd_test) == FWD_INT) else begin
      failed = '1;
      $error("problem in FixFormat_t.I to string");
    end

    assert (olo_fix_sv_pkg::fixFmtF(fwd_test) == FWD_FRAC) else begin
      failed = '1;
      $error("problem in FixFormat_t.F to string");
    end
  endtask // test

  initial begin
    test();
    assert (~failed)
      $info("test passed");
    else
      $error("test failed");

    $stop;
  end

endmodule

`default_nettype wire
