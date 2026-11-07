`default_nettype none

package olo_fix_sv_pkg;

  typedef struct packed
  {
    bit S;
    int I;
    int F;
  } FixFormat_t;

  localparam string FixRound_Trunc_c = "Trunc_s";
  localparam string FixRound_NonSymPos_c = "NonSymPos_s";
  localparam string FixRound_NonSymNeg_c = "NonSymNeg_s";
  localparam string FixRound_SymInf_c = "SymInf_s";
  localparam string FixRound_SymZero_c = "SymZero_s";
  localparam string FixRound_ConvEven_c = "ConvEven_s";
  localparam string FixRound_ConvOdd_c = "ConvOdd_s";

  localparam string FixSaturate_None_c = "None_s";
  localparam string FixSaturate_Warn_c = "Warn_s";
  localparam string FixSaturate_Sat_c = "Sat_s";
  localparam string FixSaturate_SatWarn_c = "SatWarn_s";

/*
  typedef enum int
  {
    Trunc_s,
    NonSymPos_s,
    NonSymNeg_s,
    SymInf_s,
    SymZero_s,
    ConvEven_s,
    ConvOdd_s
  } FixRound_t;
*/

  function automatic int stringFindNextMatch(input string inp, input string chr, input int start);
    int indx = -1;
    assert (chr.len() == 1) else
      $fatal(1, "expecting a single character for second input");
    for (int i = start; i < inp.len(); i++) begin
      // the following cast is required for Vivado synthesis...
      string s = string'(inp[i]);
      if (s == chr) begin
        indx = i;
        break;
      end
    end
    return indx;
  endfunction // stringFindNextMatch

  function automatic FixFormat_t fixFmtFromString(input string inp);
    FixFormat_t result;
    int next, indx = 0;

    // get the sign string
    indx = stringFindNextMatch(inp, "(", indx);
    assert (indx > -1) else
      $fatal(1, "fixFmtFromString: Format string is missing '('");
    indx++;
    if (inp[indx] == "1") begin
      result.S = '1;
    end
    else if (inp[indx] == "0") begin
      result.S = '0;
    end
    else begin
      $fatal(1, "fixFmtFromString: Unsupported sign string %s", inp[indx]);
    end

    // get the integer size
    indx = stringFindNextMatch(inp, ",", indx);
    assert (indx > 0) else
      $fatal(1, "fixFmtFromString: Format string is missing ',' between S and I");
    indx++;
    next = stringFindNextMatch(inp, ",", indx);
    assert (next > 0) else
      $fatal(1, "fixFmtFromString: Format string is missing ',' between I and F");
    result.I = inp.substr(indx, next-1).atoi();

    // get the fraction size
    indx = next + 1;
    next = stringFindNextMatch(inp, ")", indx);
    assert (next > 0) else
      $fatal(1, "fixFmtFromString: Format string is missing ')'");
    result.F = inp.substr(indx, next-1).atoi();
    return result;
  endfunction // fixFmtFromString

  function automatic int fixFmtWidth(input FixFormat_t fmt);
    return fmt.S + fmt.I + fmt.F;
  endfunction // fixFmtWidth

  function automatic int fixFmtWidthFromString(input string inp);
    FixFormat_t fmt = fixFmtFromString(inp);
    return fixFmtWidth(fmt);
  endfunction // fixFmtWidthFromString

  function automatic string fixFmtToString(input FixFormat_t fmt);
    string s, i, f;
    s.itoa(fmt.S);
    i.itoa(fmt.I);
    f.itoa(fmt.F);
    return {"(", s, ",", i, ",", f, ")"};
  endfunction // fixFmtToString

  function automatic int fixFmtI(input string inp);
    FixFormat_t fmt = fixFmtFromString(inp);
    return fmt.I;
  endfunction // fixFmtI

  function automatic int fixFmtS(input string inp);
    FixFormat_t fmt = fixFmtFromString(inp);
    return fmt.S;
  endfunction // fixFmtS

  function automatic int fixFmtF(input string inp);
    FixFormat_t fmt = fixFmtFromString(inp);
    return fmt.F;
  endfunction // fixFmtF


endpackage

`default_nettype wire
