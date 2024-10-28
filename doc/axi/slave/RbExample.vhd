p_rb : process(Clk)
begin
    if rising_edge(Clk) then
        -- Write
        if Rb_Wr = '1' then
            case Rb_Addr is
                when X"00" =>
                    -- Register with byte enables
                    for i in 0 to 3 loop
                        SomeReg(8*(i+1)-1 downto 8*i) <= Rb_WrData(8*i-1 downto 8*i);
                    end loop;$
                when X"04" =>
                    -- Register without byte enables
                    OtherReg <= Rb_WrData;
                when X"08" =>
                    -- Register with clear-by-write-one bits
                    VectorReg <= VectorReg and not Rb_WrData;
                when others => null;
            end case;
        end if;

        -- Read
        Rb_RdValid <= '0'; -- Defuault value
        if Rb_Rd = '1' then
            case Rb_Addr is
                when X"00" =>
                    Rb_RdData <= SomeReg;
                    Rb_RdValid <= '1';
                when X"04" =>
                    -- Register with clear-on-write
                    Rb_RdData <= OtherReg;
                    OtherReg <= (others => '0');
                    Rb_RdValid <= '1';
                when X"08" =>
                    Rb_RdData <= VectorReg;
                    Rb_RdValid <= '1';
                when others => null; -- Fail by timeout for illegal addreses
            end case;
        end if;

        -- Reset and other logic omitted
    end if;
end process;
