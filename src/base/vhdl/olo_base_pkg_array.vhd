------------------------------------------------------------------------------
--  Copyright (c) 2018 by Paul Scherrer Institute, Switzerland
--  Copyright (c) 2024 by Oliver Bründler
--  All rights reserved.
--  Authors: Waldemar Koprek, Oliver Bruendler
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- Package containing commonly used array types

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee ;
	use ieee.std_logic_1164.all;

------------------------------------------------------------------------------
-- Package Header
------------------------------------------------------------------------------
package olo_base_pkg_array is
    type t_aslv2    is array (natural range <>) of std_logic_vector( 1 downto 0);
    type t_aslv3    is array (natural range <>) of std_logic_vector( 2 downto 0);
    type t_aslv4    is array (natural range <>) of std_logic_vector( 3 downto 0);
    type t_aslv5    is array (natural range <>) of std_logic_vector( 4 downto 0);
    type t_aslv6    is array (natural range <>) of std_logic_vector( 5 downto 0);
    type t_aslv7    is array (natural range <>) of std_logic_vector( 6 downto 0);
    type t_aslv8    is array (natural range <>) of std_logic_vector( 7 downto 0);
    type t_aslv9    is array (natural range <>) of std_logic_vector( 8 downto 0);
    type t_aslv10   is array (natural range <>) of std_logic_vector( 9 downto 0);
    type t_aslv11   is array (natural range <>) of std_logic_vector(10 downto 0);
    type t_aslv12   is array (natural range <>) of std_logic_vector(11 downto 0);
    type t_aslv13   is array (natural range <>) of std_logic_vector(12 downto 0);
    type t_aslv14   is array (natural range <>) of std_logic_vector(13 downto 0);
    type t_aslv15   is array (natural range <>) of std_logic_vector(14 downto 0);
    type t_aslv16   is array (natural range <>) of std_logic_vector(15 downto 0);
    type t_aslv17   is array (natural range <>) of std_logic_vector(16 downto 0);
    type t_aslv18   is array (natural range <>) of std_logic_vector(17 downto 0);
    type t_aslv19   is array (natural range <>) of std_logic_vector(18 downto 0);
    type t_aslv20   is array (natural range <>) of std_logic_vector(19 downto 0);
    type t_aslv21   is array (natural range <>) of std_logic_vector(20 downto 0);
    type t_aslv22   is array (natural range <>) of std_logic_vector(21 downto 0);
    type t_aslv23   is array (natural range <>) of std_logic_vector(22 downto 0);
    type t_aslv24   is array (natural range <>) of std_logic_vector(23 downto 0);
    type t_aslv25   is array (natural range <>) of std_logic_vector(24 downto 0);
    type t_aslv26   is array (natural range <>) of std_logic_vector(25 downto 0);
    type t_aslv27   is array (natural range <>) of std_logic_vector(26 downto 0);
    type t_aslv28   is array (natural range <>) of std_logic_vector(27 downto 0);
    type t_aslv29   is array (natural range <>) of std_logic_vector(28 downto 0);
    type t_aslv30   is array (natural range <>) of std_logic_vector(29 downto 0);
    type t_aslv32   is array (natural range <>) of std_logic_vector(31 downto 0);
    type t_aslv36   is array (natural range <>) of std_logic_vector(35 downto 0);
    type t_aslv48   is array (natural range <>) of std_logic_vector(47 downto 0);
    type t_aslv64   is array (natural range <>) of std_logic_vector(63 downto 0);
    type t_aslv512  is array (natural range <>) of std_logic_vector(511 downto 0);
    
    type t_ainteger is array (natural range <>) of integer;
    type t_areal is array (natural range <>) of real;
    type t_abool is array (natural range <>) of boolean;

    function aInteger2aReal(a : in t_ainteger) return t_areal;
    function stdlv2aBool(a : in std_logic_vector) return t_abool;
    function aBool2stdlv(a : in t_abool) return std_logic_vector;

end package;

------------------------------------------------------------------------------
-- Package Body
------------------------------------------------------------------------------
package body olo_base_pkg_array is

    function aInteger2aReal(a : in t_ainteger) return t_areal is
        variable x : t_areal(a'range);
    begin
        for i in a'low to a'high loop
            x(i) := real(a(i));
        end loop;
        return x;
    end function;

    function stdlv2aBool(a : in std_logic_vector) return t_abool is
        variable x : t_abool(a'range);
    begin
        for i in a'low to a'high loop
            x(i) := (a(i) = '1');
        end loop;
        return x;
    end function;

    function aBool2stdlv(a : in t_abool) return std_logic_vector is
        variable x : std_logic_vector(a'range);
    begin
        for i in a'low to a'high loop
            if a(i) then
                x(i) := '1';
            else
                x(i) := '0';
            end if;
        end loop;
        return x;
    end function;
end olo_base_pkg_array;