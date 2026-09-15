---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bruendler, Switzerland
-- Authors: Rene Brglez
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_crc.all;

---------------------------------------------------------------------------------------------------
-- Entity
---------------------------------------------------------------------------------------------------
-- vunit: run_all_in_same_sim
entity olo_base_pkg_crc_tb is
    generic (
        runner_cfg : string;
        CrcName_g  : string
    );
end entity;

architecture sim of olo_base_pkg_crc_tb is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant DataWidth_c : natural := 8;

    -----------------------------------------------------------------------------------------------
    -- Functions
    -----------------------------------------------------------------------------------------------
    -- Get crc algorithms from https://crccalc.com
    function getCrcSettings (crcName : in string) return CrcSettings_r is
    begin
        if crcName = "Crc8_Autosar_c" then
            return Crc8_Autosar_c;
        elsif crcName = "Crc8_Bluetooth_c" then
            return Crc8_Bluetooth_c;
        elsif crcName = "Crc8_Cdma2000_c" then
            return Crc8_Cdma2000_c;
        elsif crcName = "Crc8_Darc_c" then
            return Crc8_Darc_c;
        elsif crcName = "Crc8_DvbS2_c" then
            return Crc8_DvbS2_c;
        elsif crcName = "Crc8_GsmA_c" then
            return Crc8_GsmA_c;
        elsif crcName = "Crc8_GsmB_c" then
            return Crc8_GsmB_c;
        elsif crcName = "Crc8_Hitag_c" then
            return Crc8_Hitag_c;
        elsif crcName = "Crc8_I4321_c" then
            return Crc8_I4321_c;
        elsif crcName = "Crc8_ICode_c" then
            return Crc8_ICode_c;
        elsif crcName = "Crc8_Lte_c" then
            return Crc8_Lte_c;
        elsif crcName = "Crc8_MaximDow_c" then
            return Crc8_MaximDow_c;
        elsif crcName = "Crc8_MifareMad_c" then
            return Crc8_MifareMad_c;
        elsif crcName = "Crc8_Nrsc5_c" then
            return Crc8_Nrsc5_c;
        elsif crcName = "Crc8_Opensafety_c" then
            return Crc8_Opensafety_c;
        elsif crcName = "Crc8_Rohc_c" then
            return Crc8_Rohc_c;
        elsif crcName = "Crc8_SaeJ1850_c" then
            return Crc8_SaeJ1850_c;
        elsif crcName = "Crc8_Smbus_c" then
            return Crc8_Smbus_c;
        elsif crcName = "Crc8_Tech3250_c" then
            return Crc8_Tech3250_c;
        elsif crcName = "Crc8_Wcdma_c" then
            return Crc8_Wcdma_c;
        elsif crcName = "Crc16_Arc_c" then
            return Crc16_Arc_c;
        elsif crcName = "Crc16_Cdma2000_c" then
            return Crc16_Cdma2000_c;
        elsif crcName = "Crc16_Cms_c" then
            return Crc16_Cms_c;
        elsif crcName = "Crc16_Dds110_c" then
            return Crc16_Dds110_c;
        elsif crcName = "Crc16_DectR_c" then
            return Crc16_DectR_c;
        elsif crcName = "Crc16_DectX_c" then
            return Crc16_DectX_c;
        elsif crcName = "Crc16_Dnp_c" then
            return Crc16_Dnp_c;
        elsif crcName = "Crc16_En13757_c" then
            return Crc16_En13757_c;
        elsif crcName = "Crc16_Genibus_c" then
            return Crc16_Genibus_c;
        elsif crcName = "Crc16_Gsm_c" then
            return Crc16_Gsm_c;
        elsif crcName = "Crc16_Ibm3740_c" then
            return Crc16_Ibm3740_c;
        elsif crcName = "Crc16_IbmSdlc_c" then
            return Crc16_IbmSdlc_c;
        elsif crcName = "Crc16_IsoIec144433A_c" then
            return Crc16_IsoIec144433A_c;
        elsif crcName = "Crc16_Kermit_c" then
            return Crc16_Kermit_c;
        elsif crcName = "Crc16_Lj1200_c" then
            return Crc16_Lj1200_c;
        elsif crcName = "Crc16_M17_c" then
            return Crc16_M17_c;
        elsif crcName = "Crc16_MaximDow_c" then
            return Crc16_MaximDow_c;
        elsif crcName = "Crc16_Mcrf4xx_c" then
            return Crc16_Mcrf4xx_c;
        elsif crcName = "Crc16_Modbus_c" then
            return Crc16_Modbus_c;
        elsif crcName = "Crc16_Nrsc5_c" then
            return Crc16_Nrsc5_c;
        elsif crcName = "Crc16_OpensafetyA_c" then
            return Crc16_OpensafetyA_c;
        elsif crcName = "Crc16_OpensafetyB_c" then
            return Crc16_OpensafetyB_c;
        elsif crcName = "Crc16_Profibus_c" then
            return Crc16_Profibus_c;
        elsif crcName = "Crc16_Riello_c" then
            return Crc16_Riello_c;
        elsif crcName = "Crc16_SpiFujitsu_c" then
            return Crc16_SpiFujitsu_c;
        elsif crcName = "Crc16_T10Dif_c" then
            return Crc16_T10Dif_c;
        elsif crcName = "Crc16_Teledisk_c" then
            return Crc16_Teledisk_c;
        elsif crcName = "Crc16_Tms37157_c" then
            return Crc16_Tms37157_c;
        elsif crcName = "Crc16_Umts_c" then
            return Crc16_Umts_c;
        elsif crcName = "Crc16_Usb_c" then
            return Crc16_Usb_c;
        elsif crcName = "Crc16_Xmodem_c" then
            return Crc16_Xmodem_c;
        elsif crcName = "Crc32_Aixm_c" then
            return Crc32_Aixm_c;
        elsif crcName = "Crc32_Autosar_c" then
            return Crc32_Autosar_c;
        elsif crcName = "Crc32_Base91D_c" then
            return Crc32_Base91D_c;
        elsif crcName = "Crc32_Bzip2_c" then
            return Crc32_Bzip2_c;
        elsif crcName = "Crc32_CdRomEdc_c" then
            return Crc32_CdRomEdc_c;
        elsif crcName = "Crc32_Cksum_c" then
            return Crc32_Cksum_c;
        elsif crcName = "Crc32_Iscsi_c" then
            return Crc32_Iscsi_c;
        elsif crcName = "Crc32_IsoHdlc_c" then
            return Crc32_IsoHdlc_c;
        elsif crcName = "Crc32_Jamcrc_c" then
            return Crc32_Jamcrc_c;
        elsif crcName = "Crc32_Mef_c" then
            return Crc32_Mef_c;
        elsif crcName = "Crc32_Mpeg2_c" then
            return Crc32_Mpeg2_c;
        elsif crcName = "Crc32_Xfer_c" then
            return Crc32_Xfer_c;
        else
            assert false
                report "Error: Unsupported crcName"
                severity error;
        end if;
    end function;

    -- Get expected crc from https://crccalc.com
    function getExpectedCrc (
        input   : in string;
        crcName : in string) return std_logic_vector is
    begin
        if (input = "02") then

            if crcName = "Crc8_Autosar_c" then
                return x"E3";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"D6";
            elsif crcName = "Crc8_Cdma2000_c" then
                return x"D6";
            elsif crcName = "Crc8_Darc_c" then
                return x"E4";
            elsif crcName = "Crc8_DvbS2_c" then
                return x"7F";
            elsif crcName = "Crc8_GsmA_c" then
                return x"3A";
            elsif crcName = "Crc8_GsmB_c" then
                return x"6D";
            elsif crcName = "Crc8_Hitag_c" then
                return x"FE";
            elsif crcName = "Crc8_I4321_c" then
                return x"5B";
            elsif crcName = "Crc8_ICode_c" then
                return x"C4";
            elsif crcName = "Crc8_Lte_c" then
                return x"AD";
            elsif crcName = "Crc8_MaximDow_c" then
                return x"BC";
            elsif crcName = "Crc8_MifareMad_c" then
                return x"5C";
            elsif crcName = "Crc8_Nrsc5_c" then
                return x"CE";
            elsif crcName = "Crc8_Opensafety_c" then
                return x"5E";
            elsif crcName = "Crc8_Rohc_c" then
                return x"2C";
            elsif crcName = "Crc8_SaeJ1850_c" then
                return x"01";
            elsif crcName = "Crc8_Smbus_c" then
                return x"0E";
            elsif crcName = "Crc8_Tech3250_c" then
                return x"EB";
            elsif crcName = "Crc8_Wcdma_c" then
                return x"13";
            elsif crcName = "Crc16_Arc_c" then
                return x"C181";
            elsif crcName = "Crc16_Cdma2000_c" then
                return x"33C5";
            elsif crcName = "Crc16_Cms_c" then
                return x"7D0D";
            elsif crcName = "Crc16_Dds110_c" then
                return x"0E0C";
            elsif crcName = "Crc16_DectR_c" then
                return x"0B13";
            elsif crcName = "Crc16_DectX_c" then
                return x"0B12";
            elsif crcName = "Crc16_Dnp_c" then
                return x"9343";
            elsif crcName = "Crc16_En13757_c" then
                return x"8535";
            elsif crcName = "Crc16_Genibus_c" then
                return x"3E4D";
            elsif crcName = "Crc16_Gsm_c" then
                return x"DFBD";
            elsif crcName = "Crc16_Ibm3740_c" then
                return x"C1B2";
            elsif crcName = "Crc16_IbmSdlc_c" then
                return x"D36A";
            elsif crcName = "Crc16_IsoIec144433A_c" then
                return x"72EC";
            elsif crcName = "Crc16_Kermit_c" then
                return x"2312";
            elsif crcName = "Crc16_Lj1200_c" then
                return x"DEC6";
            elsif crcName = "Crc16_M17_c" then
                return x"FE7E";
            elsif crcName = "Crc16_MaximDow_c" then
                return x"3E7E";
            elsif crcName = "Crc16_Mcrf4xx_c" then
                return x"2C95";
            elsif crcName = "Crc16_Modbus_c" then
                return x"813E";
            elsif crcName = "Crc16_Nrsc5_c" then
                return x"78D4";
            elsif crcName = "Crc16_OpensafetyA_c" then
                return x"B26A";
            elsif crcName = "Crc16_OpensafetyB_c" then
                return x"EAB6";
            elsif crcName = "Crc16_Profibus_c" then
                return x"BD0D";
            elsif crcName = "Crc16_Riello_c" then
                return x"BAA6";
            elsif crcName = "Crc16_SpiFujitsu_c" then
                return x"ECDE";
            elsif crcName = "Crc16_T10Dif_c" then
                return x"9CD9";
            elsif crcName = "Crc16_Teledisk_c" then
                return x"E1B9";
            elsif crcName = "Crc16_Tms37157_c" then
                return x"A625";
            elsif crcName = "Crc16_Umts_c" then
                return x"800F";
            elsif crcName = "Crc16_Usb_c" then
                return x"7EC1";
            elsif crcName = "Crc16_Xmodem_c" then
                return x"2042";
            elsif crcName = "Crc32_Aixm_c" then
                return x"83C3C2FD";
            elsif crcName = "Crc32_Autosar_c" then
                return x"011CC373";
            elsif crcName = "Crc32_Base91D_c" then
                return x"29E198BD";
            elsif crcName = "Crc32_Bzip2_c" then
                return x"B8757B25";
            elsif crcName = "Crc32_CdRomEdc_c" then
                return x"91210201";
            elsif crcName = "Crc32_Cksum_c" then
                return x"F67DC491";
            elsif crcName = "Crc32_Iscsi_c" then
                return x"B34623A6";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"3C0C8EA1";
            elsif crcName = "Crc32_Jamcrc_c" then
                return x"C3F3715E";
            elsif crcName = "Crc32_Mef_c" then
                return x"3BE5EA44";
            elsif crcName = "Crc32_Mpeg2_c" then
                return x"478A84DA";
            elsif crcName = "Crc32_Xfer_c" then
                return x"0000015E";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        elsif (input = "53AF") then

            if crcName = "Crc8_Autosar_c" then
                return x"E8";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"F3";
            elsif crcName = "Crc8_Cdma2000_c" then
                return x"2B";
            elsif crcName = "Crc8_Darc_c" then
                return x"A1";
            elsif crcName = "Crc8_DvbS2_c" then
                return x"24";
            elsif crcName = "Crc8_GsmA_c" then
                return x"90";
            elsif crcName = "Crc8_GsmB_c" then
                return x"ED";
            elsif crcName = "Crc8_Hitag_c" then
                return x"D1";
            elsif crcName = "Crc8_I4321_c" then
                return x"22";
            elsif crcName = "Crc8_ICode_c" then
                return x"49";
            elsif crcName = "Crc8_Lte_c" then
                return x"9A";
            elsif crcName = "Crc8_MaximDow_c" then
                return x"CC";
            elsif crcName = "Crc8_MifareMad_c" then
                return x"4A";
            elsif crcName = "Crc8_Nrsc5_c" then
                return x"99";
            elsif crcName = "Crc8_Opensafety_c" then
                return x"AF";
            elsif crcName = "Crc8_Rohc_c" then
                return x"BE";
            elsif crcName = "Crc8_SaeJ1850_c" then
                return x"2E";
            elsif crcName = "Crc8_Smbus_c" then
                return x"77";
            elsif crcName = "Crc8_Tech3250_c" then
                return x"6D";
            elsif crcName = "Crc8_Wcdma_c" then
                return x"65";
            elsif crcName = "Crc16_Arc_c" then
                return x"8C7C";
            elsif crcName = "Crc16_Cdma2000_c" then
                return x"0529";
            elsif crcName = "Crc16_Cms_c" then
                return x"E9EA";
            elsif crcName = "Crc16_Dds110_c" then
                return x"69C3";
            elsif crcName = "Crc16_DectR_c" then
                return x"647D";
            elsif crcName = "Crc16_DectX_c" then
                return x"647C";
            elsif crcName = "Crc16_Dnp_c" then
                return x"C857";
            elsif crcName = "Crc16_En13757_c" then
                return x"515D";
            elsif crcName = "Crc16_Genibus_c" then
                return x"FD19";
            elsif crcName = "Crc16_Gsm_c" then
                return x"E016";
            elsif crcName = "Crc16_Ibm3740_c" then
                return x"02E6";
            elsif crcName = "Crc16_IbmSdlc_c" then
                return x"AB25";
            elsif crcName = "Crc16_IsoIec144433A_c" then
                return x"BAC2";
            elsif crcName = "Crc16_Kermit_c" then
                return x"A462";
            elsif crcName = "Crc16_Lj1200_c" then
                return x"D8FB";
            elsif crcName = "Crc16_M17_c" then
                return x"1679";
            elsif crcName = "Crc16_MaximDow_c" then
                return x"7383";
            elsif crcName = "Crc16_Mcrf4xx_c" then
                return x"54DA";
            elsif crcName = "Crc16_Modbus_c" then
                return x"3C7D";
            elsif crcName = "Crc16_Nrsc5_c" then
                return x"4111";
            elsif crcName = "Crc16_OpensafetyA_c" then
                return x"7115";
            elsif crcName = "Crc16_OpensafetyB_c" then
                return x"F23C";
            elsif crcName = "Crc16_Profibus_c" then
                return x"B791";
            elsif crcName = "Crc16_Riello_c" then
                return x"5754";
            elsif crcName = "Crc16_SpiFujitsu_c" then
                return x"9B29";
            elsif crcName = "Crc16_T10Dif_c" then
                return x"6F52";
            elsif crcName = "Crc16_Teledisk_c" then
                return x"E8B1";
            elsif crcName = "Crc16_Tms37157_c" then
                return x"E1DB";
            elsif crcName = "Crc16_Umts_c" then
                return x"69E7";
            elsif crcName = "Crc16_Usb_c" then
                return x"C382";
            elsif crcName = "Crc16_Xmodem_c" then
                return x"1FE9";
            elsif crcName = "Crc32_Aixm_c" then
                return x"C52375C3";
            elsif crcName = "Crc32_Autosar_c" then
                return x"37693067";
            elsif crcName = "Crc32_Base91D_c" then
                return x"31635559";
            elsif crcName = "Crc32_Bzip2_c" then
                return x"15D4D8BD";
            elsif crcName = "Crc32_CdRomEdc_c" then
                return x"5D5C1F53";
            elsif crcName = "Crc32_Cksum_c" then
                return x"1563BCC0";
            elsif crcName = "Crc32_Iscsi_c" then
                return x"F90C614C";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"9626A211";
            elsif crcName = "Crc32_Jamcrc_c" then
                return x"69D95DEE";
            elsif crcName = "Crc32_Mef_c" then
                return x"BAF4999A";
            elsif crcName = "Crc32_Mpeg2_c" then
                return x"EA2B2742";
            elsif crcName = "Crc32_Xfer_c" then
                return x"00208555";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        elsif (input = "3B7EC8") then

            if crcName = "Crc8_Autosar_c" then
                return x"FF";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"C9";
            elsif crcName = "Crc8_Cdma2000_c" then
                return x"7E";
            elsif crcName = "Crc8_Darc_c" then
                return x"06";
            elsif crcName = "Crc8_DvbS2_c" then
                return x"1E";
            elsif crcName = "Crc8_GsmA_c" then
                return x"B1";
            elsif crcName = "Crc8_GsmB_c" then
                return x"E2";
            elsif crcName = "Crc8_Hitag_c" then
                return x"BF";
            elsif crcName = "Crc8_I4321_c" then
                return x"5A";
            elsif crcName = "Crc8_ICode_c" then
                return x"BC";
            elsif crcName = "Crc8_Lte_c" then
                return x"B8";
            elsif crcName = "Crc8_MaximDow_c" then
                return x"7D";
            elsif crcName = "Crc8_MifareMad_c" then
                return x"9B";
            elsif crcName = "Crc8_Nrsc5_c" then
                return x"A6";
            elsif crcName = "Crc8_Opensafety_c" then
                return x"69";
            elsif crcName = "Crc8_Rohc_c" then
                return x"CF";
            elsif crcName = "Crc8_SaeJ1850_c" then
                return x"40";
            elsif crcName = "Crc8_Smbus_c" then
                return x"0F";
            elsif crcName = "Crc8_Tech3250_c" then
                return x"49";
            elsif crcName = "Crc8_Wcdma_c" then
                return x"E2";
            elsif crcName = "Crc16_Arc_c" then
                return x"FB51";
            elsif crcName = "Crc16_Cdma2000_c" then
                return x"B86A";
            elsif crcName = "Crc16_Cms_c" then
                return x"0BEA";
            elsif crcName = "Crc16_Dds110_c" then
                return x"A1E9";
            elsif crcName = "Crc16_DectR_c" then
                return x"297D";
            elsif crcName = "Crc16_DectX_c" then
                return x"297C";
            elsif crcName = "Crc16_Dnp_c" then
                return x"E07F";
            elsif crcName = "Crc16_En13757_c" then
                return x"6FEE";
            elsif crcName = "Crc16_Genibus_c" then
                return x"7525";
            elsif crcName = "Crc16_Gsm_c" then
                return x"B9B9";
            elsif crcName = "Crc16_Ibm3740_c" then
                return x"8ADA";
            elsif crcName = "Crc16_IbmSdlc_c" then
                return x"4954";
            elsif crcName = "Crc16_IsoIec144433A_c" then
                return x"2A8C";
            elsif crcName = "Crc16_Kermit_c" then
                return x"8F98";
            elsif crcName = "Crc16_Lj1200_c" then
                return x"063F";
            elsif crcName = "Crc16_M17_c" then
                return x"64C0";
            elsif crcName = "Crc16_MaximDow_c" then
                return x"04AE";
            elsif crcName = "Crc16_Mcrf4xx_c" then
                return x"B6AB";
            elsif crcName = "Crc16_Modbus_c" then
                return x"3B20";
            elsif crcName = "Crc16_Nrsc5_c" then
                return x"5ED4";
            elsif crcName = "Crc16_OpensafetyA_c" then
                return x"5D0C";
            elsif crcName = "Crc16_OpensafetyB_c" then
                return x"8623";
            elsif crcName = "Crc16_Profibus_c" then
                return x"047C";
            elsif crcName = "Crc16_Riello_c" then
                return x"DBDE";
            elsif crcName = "Crc16_SpiFujitsu_c" then
                return x"574A";
            elsif crcName = "Crc16_T10Dif_c" then
                return x"E2CB";
            elsif crcName = "Crc16_Teledisk_c" then
                return x"A7D0";
            elsif crcName = "Crc16_Tms37157_c" then
                return x"A797";
            elsif crcName = "Crc16_Umts_c" then
                return x"85E9";
            elsif crcName = "Crc16_Usb_c" then
                return x"C4DF";
            elsif crcName = "Crc16_Xmodem_c" then
                return x"4646";
            elsif crcName = "Crc32_Aixm_c" then
                return x"5C27E84D";
            elsif crcName = "Crc32_Autosar_c" then
                return x"4BC0CB89";
            elsif crcName = "Crc32_Base91D_c" then
                return x"7E6C9050";
            elsif crcName = "Crc32_Bzip2_c" then
                return x"07000B72";
            elsif crcName = "Crc32_CdRomEdc_c" then
                return x"E6890D4F";
            elsif crcName = "Crc32_Cksum_c" then
                return x"B0647672";
            elsif crcName = "Crc32_Iscsi_c" then
                return x"212BE354";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"F37CCD99";
            elsif crcName = "Crc32_Jamcrc_c" then
                return x"0C833266";
            elsif crcName = "Crc32_Mef_c" then
                return x"FB22031F";
            elsif crcName = "Crc32_Mpeg2_c" then
                return x"F8FFF48D";
            elsif crcName = "Crc32_Xfer_c" then
                return x"1BAB3338";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        elsif (input = "924CA7F1") then

            if crcName = "Crc8_Autosar_c" then
                return x"22";
            elsif crcName = "Crc8_Bluetooth_c" then
                return x"65";
            elsif crcName = "Crc8_Cdma2000_c" then
                return x"A9";
            elsif crcName = "Crc8_Darc_c" then
                return x"8D";
            elsif crcName = "Crc8_DvbS2_c" then
                return x"F0";
            elsif crcName = "Crc8_GsmA_c" then
                return x"7A";
            elsif crcName = "Crc8_GsmB_c" then
                return x"47";
            elsif crcName = "Crc8_Hitag_c" then
                return x"DC";
            elsif crcName = "Crc8_I4321_c" then
                return x"F9";
            elsif crcName = "Crc8_ICode_c" then
                return x"FB";
            elsif crcName = "Crc8_Lte_c" then
                return x"06";
            elsif crcName = "Crc8_MaximDow_c" then
                return x"C6";
            elsif crcName = "Crc8_MifareMad_c" then
                return x"2F";
            elsif crcName = "Crc8_Nrsc5_c" then
                return x"72";
            elsif crcName = "Crc8_Opensafety_c" then
                return x"30";
            elsif crcName = "Crc8_Rohc_c" then
                return x"BE";
            elsif crcName = "Crc8_SaeJ1850_c" then
                return x"23";
            elsif crcName = "Crc8_Smbus_c" then
                return x"AC";
            elsif crcName = "Crc8_Tech3250_c" then
                return x"4D";
            elsif crcName = "Crc8_Wcdma_c" then
                return x"7E";
            elsif crcName = "Crc16_Arc_c" then
                return x"DB56";
            elsif crcName = "Crc16_Cdma2000_c" then
                return x"96E0";
            elsif crcName = "Crc16_Cms_c" then
                return x"3DC1";
            elsif crcName = "Crc16_Dds110_c" then
                return x"3D3D";
            elsif crcName = "Crc16_DectR_c" then
                return x"0265";
            elsif crcName = "Crc16_DectX_c" then
                return x"0264";
            elsif crcName = "Crc16_Dnp_c" then
                return x"8CFD";
            elsif crcName = "Crc16_En13757_c" then
                return x"4A73";
            elsif crcName = "Crc16_Genibus_c" then
                return x"43D3";
            elsif crcName = "Crc16_Gsm_c" then
                return x"C713";
            elsif crcName = "Crc16_Ibm3740_c" then
                return x"BC2C";
            elsif crcName = "Crc16_IbmSdlc_c" then
                return x"8C43";
            elsif crcName = "Crc16_IsoIec144433A_c" then
                return x"269D";
            elsif crcName = "Crc16_Kermit_c" then
                return x"709D";
            elsif crcName = "Crc16_Lj1200_c" then
                return x"0C17";
            elsif crcName = "Crc16_M17_c" then
                return x"FF2D";
            elsif crcName = "Crc16_MaximDow_c" then
                return x"24A9";
            elsif crcName = "Crc16_Mcrf4xx_c" then
                return x"73BC";
            elsif crcName = "Crc16_Modbus_c" then
                return x"FF56";
            elsif crcName = "Crc16_Nrsc5_c" then
                return x"1270";
            elsif crcName = "Crc16_OpensafetyA_c" then
                return x"5063";
            elsif crcName = "Crc16_OpensafetyB_c" then
                return x"7DB1";
            elsif crcName = "Crc16_Profibus_c" then
                return x"C1F7";
            elsif crcName = "Crc16_Riello_c" then
                return x"57FB";
            elsif crcName = "Crc16_SpiFujitsu_c" then
                return x"36FC";
            elsif crcName = "Crc16_T10Dif_c" then
                return x"5537";
            elsif crcName = "Crc16_Teledisk_c" then
                return x"7811";
            elsif crcName = "Crc16_Tms37157_c" then
                return x"8842";
            elsif crcName = "Crc16_Umts_c" then
                return x"3DE5";
            elsif crcName = "Crc16_Usb_c" then
                return x"00A9";
            elsif crcName = "Crc16_Xmodem_c" then
                return x"38EC";
            elsif crcName = "Crc32_Aixm_c" then
                return x"86FEC3C3";
            elsif crcName = "Crc32_Autosar_c" then
                return x"C7D2CC04";
            elsif crcName = "Crc32_Base91D_c" then
                return x"2A7E9FB3";
            elsif crcName = "Crc32_Bzip2_c" then
                return x"B2069D7D";
            elsif crcName = "Crc32_CdRomEdc_c" then
                return x"D7486FB4";
            elsif crcName = "Crc32_Cksum_c" then
                return x"75024006";
            elsif crcName = "Crc32_Iscsi_c" then
                return x"D20E368A";
            elsif crcName = "Crc32_IsoHdlc_c" then
                return x"64716A33";
            elsif crcName = "Crc32_Jamcrc_c" then
                return x"9B8E95CC";
            elsif crcName = "Crc32_Mef_c" then
                return x"2FCC8A9F";
            elsif crcName = "Crc32_Mpeg2_c" then
                return x"4DF96282";
            elsif crcName = "Crc32_Xfer_c" then
                return x"0245680B";
            else
                assert false
                    report "getExpectedCrc(): Unknown CRC name"
                    severity error;
            end if;

        else
            assert false
                report "getExpectedCrc(): Unsupported input = " & input
                severity error;
        end if;
    end function;

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant ClkPeriod_c : time := 10 ns;

    constant CrcSettings_c : CrcSettings_r := getCrcSettings(CrcName_g);

    -- *** Verification Components ***
    constant AxisMaster_c : axi_stream_master_t := new_axi_stream_master (
            data_length  => DataWidth_c,
            stall_config => new_stall_config(0.0, 5, 10)
        );

    constant AxisSlave_c : axi_stream_slave_t := new_axi_stream_slave (
            data_length  => CrcSettings_c.polynomial'length,
            stall_config => new_stall_config(0.0, 5, 10)
        );

    -----------------------------------------------------------------------------------------------
    -- Interface Signals
    -----------------------------------------------------------------------------------------------
    signal Clk : std_logic := '0';
    signal Rst : std_logic := '1';

    signal In_Valid : std_logic;
    signal In_Ready : std_logic;
    signal In_Data  : std_logic_vector(DataWidth_c - 1 downto 0);
    signal In_Last  : std_logic;

    signal Out_Ready : std_logic;
    signal Out_Valid : std_logic;
    signal Out_Crc   : std_logic_vector(CrcSettings_c.polynomial'length - 1 downto 0);

begin

    -----------------------------------------------------------------------------------------------
    -- TB Control
    -----------------------------------------------------------------------------------------------
    test_runner_watchdog(runner, 1 ms);

    p_control : process is
        variable ExpectedCrc_v : std_logic_vector(CrcSettings_c.polynomial'length - 1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            -- Reset
            wait until rising_edge(Clk);
            Rst <= '1';
            wait for 1 us;
            wait until rising_edge(Clk);
            Rst <= '0';
            wait until rising_edge(Clk);

            if run("Test-OneByte") then
                ----------------------------------------------------------------
                -- 02
                push_axi_stream(net, AxisMaster_c, x"02", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("02", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(02)");

            elsif run("Test-TwoBytes") then
                ----------------------------------------------------------------
                -- 53AF
                push_axi_stream(net, AxisMaster_c, x"53", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"AF", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("53AF", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(53AF)");

            elsif run("Test-ThreeBytes") then
                ----------------------------------------------------------------
                -- 3B7EC8
                push_axi_stream(net, AxisMaster_c, x"3B", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"7E", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"C8", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("3B7EC8", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(3B7EC8)");

            elsif run("Test-FourBytes") then
                ----------------------------------------------------------------
                -- 924CA7F1
                push_axi_stream(net, AxisMaster_c, x"92", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"4C", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"A7", tlast => '0');
                push_axi_stream(net, AxisMaster_c, x"F1", tlast => '1');

                ExpectedCrc_v := getExpectedCrc("924CA7F1", CrcName_g);
                check_axi_stream(net, AxisSlave_c, ExpectedCrc_v, msg => "CRC(924CA7F1)");

            end if;

            wait for 1 us;
            wait_until_idle(net, as_sync(AxisMaster_c));
            wait_until_idle(net, as_sync(AxisSlave_c));

        end loop;

        -- TB done
        test_runner_cleanup(runner);
    end process;

    -----------------------------------------------------------------------------------------------
    -- Clock
    -----------------------------------------------------------------------------------------------
    Clk <= not Clk after 0.5 * ClkPeriod_c;

    -----------------------------------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------------------------------
    i_dut : entity olo.olo_base_crc
        generic map (
            DataWidth_g     => DataWidth_c,
            Polynomial_g    => CrcSettings_c.polynomial,
            InitialValue_g  => CrcSettings_c.initialValue,
            BitOrder_g      => CrcSettings_c.bitOrder,
            BitflipOutput_g => CrcSettings_c.bitFlipOutput,
            XorOutput_g     => CrcSettings_c.xorOutput
        )
        port map (
            Clk => Clk,
            Rst => Rst,

            In_Data  => In_Data,
            In_Valid => In_Valid,
            In_Ready => In_Ready,
            In_Last  => In_Last,

            Out_Crc   => Out_Crc,
            Out_Valid => Out_Valid,
            Out_Ready => Out_Ready
        );

    -----------------------------------------------------------------------------------------------
    -- Verification Components
    -----------------------------------------------------------------------------------------------
    vc_stimuli : entity vunit_lib.axi_stream_master
        generic map (
            Master => AxisMaster_c
        )
        port map (
            AClk   => Clk,
            TValid => In_Valid,
            TReady => In_Ready,
            TData  => In_Data,
            TLast  => In_Last
        );

    vc_response : entity vunit_lib.axi_stream_slave
        generic map (
            Slave => AxisSlave_c
        )
        port map (
            AClk   => Clk,
            TReady => Out_Ready,
            TValid => Out_Valid,
            TData  => Out_Crc
        );

end architecture;
