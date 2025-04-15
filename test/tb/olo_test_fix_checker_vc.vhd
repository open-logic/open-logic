---------------------------------------------------------------------------------------------------
-- Copyright (c) 2025 by Oliver Bründler
-- All rights reserved.
-- Authors: Oliver Bruendler
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- VC Package
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.sync_pkg.all;

package olo_test_fix_checker_pkg is

    -- *** VUnit instance type ***
    type olo_test_fix_checker_t is record
        p_actor : actor_t;
    end record;

    -- *** Master Operations ***

    -- Transaction
    procedure fix_checker_check_file (
        signal net        : inout network_t;
        checker           : olo_test_fix_checker_t;
        file_path         : string;
        stall_probability : real     := 0.0;
        stall_max_cycles  : positive := 1;
        stall_min_cycles  : positive := 1;
        msg               : string   := "");

    -- *** VUnit Operations ***
    -- Message Types
    constant fix_checker_check_file_msg : msg_type_t := new_msg_type("fix_checker_check_file_msg");

    -- Constructor
    impure function new_olo_test_fix_checker return olo_test_fix_checker_t;

    -- Casts
    impure function as_sync (instance : olo_test_fix_checker_t) return sync_handle_t;

end package;

package body olo_test_fix_checker_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure fix_checker_check_file (
        signal net        : inout network_t;
        checker           : olo_test_fix_checker_t;
        file_path         : string;
        stall_probability : real     := 0.0;
        stall_max_cycles  : positive := 1;
        stall_min_cycles  : positive := 1;
        msg               : string   := "") is
        -- Declarations
        variable msg_v  : msg_t := new_msg(fix_checker_check_file_msg);
    begin
        -- checks
        check(stall_probability >= 0.0 and stall_probability <= 1.0, "stall_probability must be between 0.0 and 1.0");
        check(stall_max_cycles >= stall_min_cycles, "stall_max_cycles must be greater than stall_min_cycles");

        -- Create message
        push_string(msg_v, file_path);
        push(msg_v, stall_probability);
        push(msg_v, stall_max_cycles);
        push(msg_v, stall_min_cycles);
        push_string(msg_v, msg);

        -- Send message
        send(net, checker.p_actor, msg_v);
    end procedure;

    -- Constructor
    impure function new_olo_test_fix_checker return olo_test_fix_checker_t is
    begin
        return (p_actor => new_actor);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_fix_checker_t) return sync_handle_t is
    begin
        return instance.p_actor;
    end function;

end package body;

---------------------------------------------------------------------------------------------------
-- Component Implementation
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use std.textio.all;
    use ieee.std_logic_textio.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    use vunit_lib.stream_master_pkg.all;
    use vunit_lib.sync_pkg.all;

library osvvm;
    use osvvm.randompkg.all;

library work;
    use work.olo_test_fix_checker_pkg.all;

library olo;
    use olo.en_cl_fix_pkg.all;

entity olo_test_fix_checker_vc is
    generic (
        instance                 : olo_test_fix_checker_t;
        is_timing_master         : boolean := true;
        fmt                      : FixFormat_t
    );
    port (
        clk      : in    std_logic;
        rst      : in    std_logic;
        ready    : inout std_logic; -- input for slave, output for master
        valid    : in    std_logic;
        data     : in    std_logic_vector(cl_fix_width(fmt)-1 downto 0)
    );
end entity;

architecture a of olo_test_fix_checker_vc is

    -- Declarations
    shared variable random_v : RandomPType;

begin

    -- Main Process
    main : process is
        -- Messaging
        variable request_msg       : msg_t;
        variable msg_type          : msg_type_t;
        variable msg_p             : string_ptr_t;
        variable file_path_p       : string_ptr_t;
        variable stall_probability : real;
        variable stall_max_cycles  : positive;
        variable stall_min_cycles  : positive;

        -- File
        file data_file : text;

        variable line_v   : line;
        variable fmt_v    : FixFormat_t;
        variable data_slv : std_logic_vector(cl_fix_width(fmt)-1 downto 0);
        variable good     : boolean;

        -- Others
        variable stall_random : real;
        variable stall_cycles : positive;
        variable line_number  : positive;
    begin

        -- Initialize
        if is_timing_master then
            ready <= '0';
        else
            ready <= 'Z';
        end if;
        random_v.InitSeed(random_v'instance_name);

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Messages ***
            if msg_type = fix_checker_check_file_msg then
                -- Pop Transaction
                file_path_p       := new_string_ptr(pop_string(request_msg));
                stall_probability := pop(request_msg);
                stall_max_cycles  := pop(request_msg);
                stall_min_cycles  := pop(request_msg);
                msg_p             := new_string_ptr(pop_string(request_msg));

                -- Open file and check format
                file_open(data_file, to_string(file_path_p), read_mode);
                line_number := 1;

                -- Check format (first line)
                readline(data_file, line_v);
                fmt_v       := cl_fix_format_from_string(line_v.all);
                assert fmt_v = fmt
                    report to_string(msg_p) & "Format mismatch: expected " & to_string(fmt) &
                           ", got " & to_string(fmt_v) & " in file " & to_string(file_path_p)
                    severity error;
                line_number := line_number + 1;

                -- Iterate through lines in file
                while not endfile(data_file) loop

                    -- Wait for ready signal if timing master
                    if is_timing_master then
                        -- Stall
                        stall_random := random_v.RandReal(0.0, 1.0);
                        if stall_random < stall_probability then
                            ready <= '0';

                            -- Wait for stall
                            stall_cycles := random_v.RandInt(stall_min_cycles, stall_max_cycles);

                            for i in 0 to stall_cycles - 1 loop
                                wait until rising_edge(clk) and valid = '1';
                            end loop;

                            wait until falling_edge(clk);
                        end if;
                        ready <= '1';
                        wait until rising_edge(clk) and valid = '1';
                    else
                        wait until rising_edge(clk) and ready = '1' and valid = '1';
                    end if;

                    -- Read line
                    readline(data_file, line_v);
                    hread(line_v, data_slv, good);
                    assert good
                        report to_string(msg_p) & "- Failed to read from file" & to_string(file_path_p)
                        severity error;

                    -- Apply Data
                    check_equal(data, data_slv, "olo_test_fix - " & to_string(msg_p) &
                                                " - file " & to_string(file_path_p) &
                                                " - line " & to_string(line_number));
                    line_number := line_number + 1;

                end loop;

                -- Close the file
                file_close(data_file);

                -- Idle output
                if is_timing_master then
                    ready <= '0';
                end if;

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;

    end process;

end architecture;
