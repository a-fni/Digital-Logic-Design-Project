library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Main project entity (copy-pasted)
entity project_reti_logiche is
    port (
        i_clk       : in std_logic;
        i_rst       : in std_logic;
        i_start     : in std_logic;
        i_w         : in std_logic;
        
        o_z0        : out std_logic_vector(7 downto 0);
        o_z1        : out std_logic_vector(7 downto 0);
        o_z2        : out std_logic_vector(7 downto 0);
        o_z3        : out std_logic_vector(7 downto 0);
        o_done      : out std_logic;
        
        o_mem_addr  : out std_logic_vector(15 downto 0);
        i_mem_data  : in std_logic_vector(7 downto 0);
        o_mem_we    : out std_logic;
        o_mem_en    : out std_logic
    );
end project_reti_logiche;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Datapath entity
entity datapath is
    port (
        i_clk       : in std_logic;
        i_rst       : in std_logic;
        i_w         : in std_logic;

        ch1_load    : in std_logic;
        ch0_load    : in std_logic;
        addr_load   : in std_logic;
        addr_wipe   : in std_logic;

        o_mem_addr  : out std_logic_vector (15 downto 0);
        i_mem_data  : in std_logic_vector (7 downto 0);

        z_ctrl      : in std_logic;

        o_done      : in std_logic;
        m0_o        : out std_logic_vector (7 downto 0);
        m1_o        : out std_logic_vector (7 downto 0);
        m2_o        : out std_logic_vector (7 downto 0);
        m3_o        : out std_logic_vector (7 downto 0)
    );
end datapath;


-- Datapath architecture
architecture Behavioral of datapath is
    signal ch1_o        : std_logic;
    signal ch0_o        : std_logic;

    signal next_addr    : std_logic_vector (15 downto 0);
    signal addr_o       : std_logic_vector (15 downto 0);

    signal z0_load      : std_logic;
    signal z1_load      : std_logic;
    signal z2_load      : std_logic;
    signal z3_load      : std_logic;

    signal z0_o         : std_logic_vector (7 downto 0);
    signal z1_o         : std_logic_vector (7 downto 0);
    signal z2_o         : std_logic_vector (7 downto 0);
    signal z3_o         : std_logic_vector (7 downto 0);
begin

    -- CH1 register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            ch1_o  <= '0';
        elsif (i_clk'event and i_clk = '0') then
            if (ch1_load = '1') then
                ch1_o <= i_w;
            end if;
        end if;
    end process;

    -- CH0 register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            ch0_o <= '0';
        elsif (i_clk'event and i_clk = '0') then
            if (ch0_load = '1') then
                ch0_o <= i_w;
            end if;
        end if;
    end process;

    -- Address output and address shift circuit
    o_mem_addr <= addr_o;
    next_addr <= addr_o(14 downto 0) & i_w;

    -- ADDR register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            addr_o <= (others => '0');
        elsif (i_clk'event and i_clk = '0') then
            if (addr_wipe = '1') then
                addr_o <= (others => '0');
            elsif (addr_load = '1') then
                addr_o <= next_addr;
            end if;
        end if;
    end process;

    -- Register control signals
    z0_load <= z_ctrl and (not ch1_o) and (not ch0_o);
    z1_load <= z_ctrl and (not ch1_o) and ch0_o;
    z2_load <= z_ctrl and ch1_o and (not ch0_o);
    z3_load <= z_ctrl and ch1_o and ch0_o;

    -- Z0 register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            z0_o <= (others => '0');
        elsif (i_clk'event and i_clk = '1') then
            if (z0_load = '1') then
                z0_o <= i_mem_data;
            end if;
        end if;
    end process;

    -- Z1 register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            z1_o <= (others => '0');
        elsif (i_clk'event and i_clk = '1') then
            if (z1_load = '1') then
                z1_o <= i_mem_data;
            end if;
        end if;
    end process;

    -- Z2 register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            z2_o  <= (others => '0');
        elsif (i_clk'event and i_clk = '1') then
            if (z2_load = '1') then
                z2_o <= i_mem_data;
            end if;
        end if;
    end process;

    -- Z3 register description
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            z3_o  <= (others => '0');
        elsif (i_clk'event and i_clk = '1') then
            if (z3_load = '1') then
                z3_o <= i_mem_data;
            end if;
        end if;
    end process;

    -- Output multiplexer logic description
    with o_done select
        m0_o <= (others => '0') when '0', z0_o when '1', (others => 'X') when others;
    with o_done select
        m1_o <= (others => '0') when '0', z1_o when '1', (others => 'X') when others;
    with o_done select
        m2_o <= (others => '0') when '0', z2_o when '1', (others => 'X') when others;
    with o_done select
        m3_o <= (others => '0') when '0', z3_o when '1', (others => 'X') when others;

end Behavioral;


-- project_reti_logiche architecture & Finite State Machine design
architecture Behavioral of project_reti_logiche is
    component datapath is
        port (
            i_clk       : in std_logic;
            i_rst       : in std_logic;
            i_w         : in std_logic;

            ch1_load    : in std_logic;
            ch0_load    : in std_logic;
            addr_load   : in std_logic;
            addr_wipe   : in std_logic;

            o_mem_addr  : out std_logic_vector (15 downto 0);
            i_mem_data  : in std_logic_vector (7 downto 0);

            z_ctrl      : in std_logic;

            o_done      : in std_logic;
            m0_o        : out std_logic_vector (7 downto 0);
            m1_o        : out std_logic_vector (7 downto 0);
            m2_o        : out std_logic_vector (7 downto 0);
            m3_o        : out std_logic_vector (7 downto 0)
        );
    end component;
    
    signal ch1_load     : std_logic;
    signal ch0_load     : std_logic;
    signal addr_load    : std_logic;
    signal addr_wipe    : std_logic;
    signal z_ctrl       : std_logic;
    signal done_ctrl    : std_logic;

    type S is (S0, S1, S2, S3, S4, S5, S6);
    signal curr_state   : S;
    signal next_state   : S;
begin
    DATAPATH0: datapath port map (
        i_clk       => i_clk,
        i_rst       => i_rst,
        i_w         => i_w,
        
        ch1_load    => ch1_load,
        ch0_load    => ch0_load,
        addr_load   => addr_load,
        addr_wipe   => addr_wipe,
        
        o_mem_addr  => o_mem_addr,
        i_mem_data  => i_mem_data,
        
        z_ctrl      => z_ctrl,
        o_done      => done_ctrl,
        
        m0_o        => o_z0,
        m1_o        => o_z1,
        m2_o        => o_z2,
        m3_o        => o_z3
    );

    -- State resetting / updating logic 
    process (i_clk, i_rst)
    begin
        if (i_rst = '1') then
            curr_state <= S0;
        elsif (i_clk'event and i_clk = '1') then
            curr_state <= next_state;
        end if;
    end process;

    -- FSM transition function description
    process (curr_state, i_start, i_rst)
    begin
        -- By default we remaing on current state
        next_state <= curr_state;

        case curr_state is
            when S0 =>
                if (i_start = '1') then
                    next_state <= S1;
                end if; 
            
            when S1 =>
                next_state <= S2;
            
            when S2 =>
                if (i_start = '1') then
                    next_state <= S3;
                else
                    next_state <= S4;
                end if;
            
            when S3 =>
                if (i_start = '0') then
                    next_state <= S4;
                end if;

            when S4 =>
                next_state <= S5;

            when S5 =>
                next_state <= S6;

            when S6 =>
                next_state <= S0;

        end case;
    end process;

    -- FSM output function description
    process (curr_state)
    begin
        -- Resetting all signals to '0' by default for safety...
        ch1_load  <= '0';
        ch0_load  <= '0';
        addr_load <= '0';
        addr_wipe <= '0';
        z_ctrl    <= '0';
        done_ctrl <= '0';
        o_mem_en  <= '0';
        o_mem_we  <= '0';

        case curr_state is
            when S0 =>
                addr_wipe <= '1';

            when S1 =>
                ch1_load <= '1';

            when S2 =>
                ch1_load <= '0';
                ch0_load <= '1';

            when S3 =>
                ch0_load <= '0';
                addr_load <= '1';

            when S4 =>
                addr_load <= '0';
                o_mem_en <= '1';

            when S5 =>
                o_mem_en <= '0';
                z_ctrl <= '1';

            when S6 =>
                z_ctrl <= '0';
                done_ctrl <= '1';

        end case;
    end process;
    
    -- Finally, we simply connect the internal done-control wire to the output done signal wire
    o_done <= done_ctrl;

end Behavioral;
