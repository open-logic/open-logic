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

package olo_test_fix_stimuli_pkg is

    -- *** VUnit instance type ***
    type olo_test_fix_stimuli_t is record
        p_actor : actor_t;
    end record;

    type olo_fix_stimuli_mode_t is (
        stimuli_mode_stream,
        stimuli_mode_packet,
        stimuli_mode_tdm
    );

    -- *** Master Operations ***

    -- Transaction
    procedure fix_stimuli_play_file (
        signal net        : inout network_t;
        stimuli           : olo_test_fix_stimuli_t;
        file_path         : string;
        mode              : olo_fix_stimuli_mode_t := stimuli_mode_stream;
        tdm_slots         : positive               := 1;
        stall_probability : real                   := 0.0;
        stall_max_cycles  : positive               := 1;
        stall_min_cycles  : positive               := 1;
        msg               : string                 := "");

    -- *** VUnit Operations ***
    -- Message Types
    constant fix_stimuli_play_file_msg : msg_type_t := new_msg_type("fix_stimuli_play_filemsg");

    -- Constructor
    impure function new_olo_test_fix_stimuli return olo_test_fix_stimuli_t;

    -- Casts
    impure function as_sync (instance : olo_test_fix_stimuli_t) return sync_handle_t;

end package;

package body olo_test_fix_stimuli_pkg is

    -- *** Master Operations ***

    -- Transaction
    procedure fix_stimuli_play_file (
        signal net        : inout network_t;
        stimuli           : olo_test_fix_stimuli_t;
        file_path         : string;
        mode              : olo_fix_stimuli_mode_t := stimuli_mode_stream;
        tdm_slots         : positive               := 1;
        stall_probability : real                   := 0.0;
        stall_max_cycles  : positive               := 1;
        stall_min_cycles  : positive               := 1;
        msg               : string                 := "") is
        -- Declarations
        variable msg_v  : msg_t := new_msg(fix_stimuli_play_file_msg);
    begin
        -- checks
        check(stall_probability >= 0.0 and stall_probability <= 1.0, "stall_probability must be between 0.0 and 1.0");
        check(stall_max_cycles >= stall_min_cycles, "stall_max_cycles must be greater than stall_min_cycles");

        -- Create message7
        push_string(msg_v, file_path);
        push(msg_v, olo_fix_stimuli_mode_t'pos(mode));
        push(msg_v, tdm_slots);
        push(msg_v, stall_probability);
        push(msg_v, stall_max_cycles);
        push(msg_v, stall_min_cycles);
        push_string(msg_v, msg);

        -- Send message
        send(net, stimuli.p_actor, msg_v);
    end procedure;

    -- Constructor
    impure function new_olo_test_fix_stimuli return olo_test_fix_stimuli_t is
    begin
        return (p_actor => new_actor);
    end function;

    -- Casts
    impure function as_sync (instance : olo_test_fix_stimuli_t) return sync_handle_t is
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
    use work.olo_test_fix_stimuli_pkg.all;

library olo;
    use olo.en_cl_fix_pkg.all;

entity olo_test_fix_stimuli_vc is
    generic (
        instance                 : olo_test_fix_stimuli_t;
        is_timing_master         : boolean := true;
        fmt                      : FixFormat_t
    );
    port (
        clk      : in    std_logic;
        rst      : in    std_logic;
        ready    : in    std_logic := '1';
        valid    : inout std_logic; -- input for slave, output for master
        last     : out   std_logic;
        data     : out   std_logic_vector(cl_fix_width(fmt)-1 downto 0)
    );
end entity;

architecture a of olo_test_fix_stimuli_vc is

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
        variable mode              : olo_fix_stimuli_mode_t;
        variable tdm_slots         : positive;
        variable stall_probability : real;
        variable stall_max_cycles  : positive;
        variable stall_min_cycles  : positive;

        -- File
        file data_file : text;

        variable line_v        : line;
        variable next_line_v   : line;
        variable fmt_v         : FixFormat_t;
        variable data_slv      : std_logic_vector(cl_fix_width(fmt)-1 downto 0);
        variable next_data_slv : std_logic_vector(cl_fix_width(fmt)-1 downto 0);
        variable good          : boolean;
        variable has_data      : boolean;
        variable next_has_data : boolean;

        -- Others
        variable stall_random : real;
        variable stall_cycles : positive;
        variable slot_cnt     : natural;
        variable is_last      : boolean;
    begin

        -- Initialize
        if is_timing_master then
            valid <= '0';
        else
            valid <= 'Z';
        end if;
        last <= '0';
        data <= (others => 'U');
        random_v.InitSeed(random_v'instance_name);

        -- Waiit for reset release
        wait until rising_edge(clk) and rst = '0';

        -- Loop though messages
        loop
            -- Receive message
            receive(net, instance.p_actor, request_msg);
            msg_type := message_type(request_msg);

            -- *** Handle Messages ***
            if msg_type = fix_stimuli_play_file_msg then
                -- Pop Transaction
                file_path_p       := new_string_ptr(pop_string(request_msg));
                mode              := olo_fix_stimuli_mode_t'val(integer'(pop(request_msg)));
                tdm_slots         := pop(request_msg);
                stall_probability := pop(request_msg);
                stall_max_cycles  := pop(request_msg);
                stall_min_cycles  := pop(request_msg);
                msg_p             := new_string_ptr(pop_string(request_msg));

                -- Open file and check format
                file_open(data_file, to_string(file_path_p), read_mode);

                -- Check format (first line)
                readline(data_file, line_v);
                fmt_v := cl_fix_format_from_string(line_v.all);
                assert fmt_v = fmt
                    report "olo_test_fix_stimuli - " & to_string(msg_p) & "Format mismatch: expected " & to_string(fmt) &
                           ", got " & to_string(fmt_v) & " in file " & to_string(file_path_p)
                    severity error;

                -- Read first data line
                if not endfile(data_file) then
                    readline(data_file, line_v);
                    hread(line_v, data_slv, good);
                    assert good
                        report "olo_test_fix_stimuli - " & to_string(msg_p) & "- Failed to read from file" & to_string(file_path_p)
                        severity error;
                    has_data := true;
                else
                    has_data := false;
                end if;

                slot_cnt := 0;

                -- Iterate through lines in file
                while has_data loop
                    -- Try read next line
                    if not endfile(data_file) then
                        readline(data_file, next_line_v);
                        hread(next_line_v, next_data_slv, good);
                        assert good
                            report "olo_test_fix_stimuli - " & to_string(msg_p) & "- Failed to read from file" & to_string(file_path_p)
                            severity error;
                        next_has_data := true;
                    else
                        next_has_data := false;
                    end if;

                    -- Determine Last
                    is_last := false;
                    if mode = stimuli_mode_packet and not next_has_data then
                        is_last := true;
                    elsif mode = stimuli_mode_tdm and slot_cnt = tdm_slots - 1 then
                        is_last := true;
                    end if;

                    -- Update slot counter
                    if slot_cnt = tdm_slots - 1 then
                        slot_cnt := 0;
                    else
                        slot_cnt := slot_cnt + 1;
                    end if;

                    -- Apply Data
                    data <= data_slv;
                    if is_last then
                        last <= '1';
                    else
                        last <= '0';
                    end if;

                    -- Wait for ready signal if timing master
                    if is_timing_master then
                        -- Apply
                        valid <= '1';
                        wait until rising_edge(clk) and ready = '1';
                        -- Stall
                        stall_random := random_v.RandReal(0.0, 1.0);
                        if stall_random < stall_probability then
                            -- Remove data
                            valid <= '0';
                            last  <= '0';
                            data  <= (others => 'U');

                            -- Wait for stall
                            stall_cycles := random_v.RandInt(stall_min_cycles, stall_max_cycles);

                            for i in 0 to stall_cycles - 1 loop
                                wait until rising_edge(clk);
                            end loop;

                        end if;
                    else
                        wait until rising_edge(clk) and ready = '1' and valid = '1';
                    end if;

                    -- Move next to current
                    data_slv := next_data_slv;
                    has_data := next_has_data;
                end loop;

                -- Close the file
                file_close(data_file);

                -- Idle output
                if is_timing_master then
                    valid <= '0';
                end if;
                last <= '0';
                data <= (others => 'U');

            elsif msg_type = wait_until_idle_msg then
                handle_wait_until_idle(net, msg_type, request_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;

    end process;

end architecture;
