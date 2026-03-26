library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--! @file TennisTop.vhd
--! @brief Top-level modul za povezivanje teniskog semafora sa Nexys A7 pločom.
--! @details
--! Ovaj modul obavlja:
--! - povezivanje fizičkih tastera sa logikom semafora
--! - pozivanje glavnog modula TennisMain
--! - dekodiranje brojeva i simbola za 7-segmentni displej
--! - multipleksiranje 8 cifara displeja
--! - prikaz poena, gemova, setova i tie-break rezultata
--! - kontrolu decimalnih tačaka kao separatora
--! @author Jelena Radaković
--! @version 1.0

--! @brief Entitet top-level modula za Nexys A7.
entity TennisTop is
    port(
        --! Glavni clock signal sa ploče (100 MHz)
        CLK100MHZ : in  std_logic;
        --! Taster za poen igrača A
        BTNL      : in  std_logic;
        --! Taster za poen igrača B
        BTNR      : in  std_logic;
        --! Taster za undo igrača A
        BTNU      : in  std_logic;
        --! Taster za undo igrača B
        BTND      : in  std_logic;
        --! Reset taster
        BTNC      : in  std_logic;

        --! Izlazi za 7-segmentni displej
        CA        : out std_logic;
        --! Segment B
        CB        : out std_logic;
        --! Segment C
        CC        : out std_logic;
        --! Segment D
        CD        : out std_logic;
        --! Segment E
        CE        : out std_logic;
        --! Segment F
        CF        : out std_logic;
        --! Segment G
        CG        : out std_logic;
        --! Decimalna tačka
        DP        : out std_logic;
        --! Aktivacija displeja AN0-AN7
        AN        : out std_logic_vector(7 downto 0)
    );
end entity;

--! @brief Behavioral arhitektura top-level modula.
architecture Behavioral of TennisTop is

    --! Kodirani poeni igrača A
    signal points_a : std_logic_vector(2 downto 0);
    --! Kodirani poeni igrača B
    signal points_b : std_logic_vector(2 downto 0);
    --! Gemovi igrača A
    signal games_a  : unsigned(3 downto 0);
    --! Gemovi igrača B
    signal games_b  : unsigned(3 downto 0);
    --! Setovi igrača A
    signal sets_a   : unsigned(3 downto 0);
    --! Setovi igrača B
    signal sets_b   : unsigned(3 downto 0);

    --! Signal aktivnog tie-break režima
    signal tb_active_i : std_logic;
    --! Tie-break rezultat igrača A
    signal tb_a        : unsigned(3 downto 0);
    --! Tie-break rezultat igrača B
    signal tb_b        : unsigned(3 downto 0);

    --! Niz cifara za prikaz na 8 displeja
    type digit_array_t is array (0 to 7) of unsigned(4 downto 0);
    --! Interni niz cifara
    signal digits : digit_array_t := (others => to_unsigned(31, 5));

    --! Brojač za osvježavanje displeja
    signal refresh_cnt : unsigned(19 downto 0) := (others => '0');
    --! Izbor trenutno aktivnog displeja
    signal scan_sel    : unsigned(2 downto 0);
    --! Izlazna vrijednost za 7 segmenata
    signal seg7        : std_logic_vector(6 downto 0);

    --! Kod za prikaz slova A
    constant DIGIT_A     : unsigned(4 downto 0) := to_unsigned(10, 5);
    --! Kod za prikaz slova d
    constant DIGIT_d     : unsigned(4 downto 0) := to_unsigned(11, 5);
    --! Kod za prazan displej
    constant DIGIT_BLANK : unsigned(4 downto 0) := to_unsigned(31, 5);

    --! @brief Funkcija za dekodiranje cifre u 7-segmentni prikaz.
    --! @param d Ulazna cifra ili simbol.
    --! @return 7-bitni active-low kod za segmente abcdefg.
    function to_7seg_active_low(d : unsigned(4 downto 0)) return std_logic_vector is
    begin
        case to_integer(d) is
            when 0  => return "0000001";
            when 1  => return "1001111";
            when 2  => return "0010010";
            when 3  => return "0000110";
            when 4  => return "1001100";
            when 5  => return "0100100";
            when 6  => return "0100000";
            when 7  => return "0001111";
            when 8  => return "0000000";
            when 9  => return "0000100";
            when 10 => return "0001000"; -- A
            when 11 => return "1000010"; -- d
            when others => return "1111111"; -- blank
        end case;
    end function;

begin

    --------------------------------------------------------------------
    -- Glavna logika
    --------------------------------------------------------------------
    --! @brief Instanca glavnog modula teniskog semafora.
    U_MAIN: entity work.TennisMain
        port map(
            clk              => CLK100MHZ,
            reset            => BTNC,
            button_a         => BTNL,
            button_b         => BTNR,
            undo_a           => BTNU,
            undo_b           => BTND,
            display_points_a => points_a,
            display_points_b => points_b,
            display_games_a  => games_a,
            display_games_b  => games_b,
            display_sets_a   => sets_a,
            display_sets_b   => sets_b,
            tb_active        => tb_active_i,
            display_tb_a     => tb_a,
            display_tb_b     => tb_b
        );

    --------------------------------------------------------------------
    -- Formiranje cifara
    --------------------------------------------------------------------
    --! @brief Priprema 8 cifara za prikaz na displeju.
    --! @details
    --! U normalnom režimu prikazuje poene, gemove i setove.
    --! U tie-break režimu na lijeva četiri displeja prikazuje tie-break rezultat.
    process(points_a, points_b, games_a, games_b, sets_a, sets_b, tb_active_i, tb_a, tb_b)
        --! Privremena vrijednost tie-break rezultata igrača A
        variable val_a, val_b : integer;
    begin
        for i in 0 to 7 loop
            digits(i) <= DIGIT_BLANK;
        end loop;

        if tb_active_i = '1' then
            val_a := to_integer(tb_a);
            val_b := to_integer(tb_b);

            digits(7) <= to_unsigned(val_a / 10, 5);
            digits(6) <= to_unsigned(val_a mod 10, 5);

            digits(5) <= to_unsigned(val_b / 10, 5);
            digits(4) <= to_unsigned(val_b mod 10, 5);

        else
            case points_a is
                when "000" =>
                    digits(7) <= to_unsigned(0, 5);
                    digits(6) <= to_unsigned(0, 5);
                when "001" =>
                    digits(7) <= to_unsigned(1, 5);
                    digits(6) <= to_unsigned(5, 5);
                when "010" =>
                    digits(7) <= to_unsigned(3, 5);
                    digits(6) <= to_unsigned(0, 5);
                when "011" =>
                    digits(7) <= to_unsigned(4, 5);
                    digits(6) <= to_unsigned(0, 5);
                when "100" =>
                    digits(7) <= DIGIT_A;
                    digits(6) <= DIGIT_d;
                when others =>
                    digits(7) <= DIGIT_BLANK;
                    digits(6) <= DIGIT_BLANK;
            end case;

            case points_b is
                when "000" =>
                    digits(5) <= to_unsigned(0, 5);
                    digits(4) <= to_unsigned(0, 5);
                when "001" =>
                    digits(5) <= to_unsigned(1, 5);
                    digits(4) <= to_unsigned(5, 5);
                when "010" =>
                    digits(5) <= to_unsigned(3, 5);
                    digits(4) <= to_unsigned(0, 5);
                when "011" =>
                    digits(5) <= to_unsigned(4, 5);
                    digits(4) <= to_unsigned(0, 5);
                when "100" =>
                    digits(5) <= DIGIT_A;
                    digits(4) <= DIGIT_d;
                when others =>
                    digits(5) <= DIGIT_BLANK;
                    digits(4) <= DIGIT_BLANK;
            end case;
        end if;

        digits(3) <= resize(games_a, 5); -- AN3
        digits(2) <= resize(games_b, 5); -- AN2
        digits(1) <= resize(sets_a,  5); -- AN1
        digits(0) <= resize(sets_b,  5); -- AN0
    end process;

    --------------------------------------------------------------------
    -- Refresh
    --------------------------------------------------------------------
    --! @brief Brojač za multipleksiranje displeja.
    process(CLK100MHZ)
    begin
        if rising_edge(CLK100MHZ) then
            refresh_cnt <= refresh_cnt + 1;
        end if;
    end process;

    --! Izbor aktivnog displeja
    scan_sel <= refresh_cnt(19 downto 17);

    --------------------------------------------------------------------
    -- Multipleksiranje
    --------------------------------------------------------------------
    --! @brief Multipleksiranje 8 cifara na 7-segmentni displej.
    process(scan_sel, digits)
    begin
        AN <= (others => '1');

        case to_integer(scan_sel) is
            when 0 =>
                AN <= "11111110"; -- AN0
                seg7 <= to_7seg_active_low(digits(0));
            when 1 =>
                AN <= "11111101"; -- AN1
                seg7 <= to_7seg_active_low(digits(1));
            when 2 =>
                AN <= "11111011"; -- AN2
                seg7 <= to_7seg_active_low(digits(2));
            when 3 =>
                AN <= "11110111"; -- AN3
                seg7 <= to_7seg_active_low(digits(3));
            when 4 =>
                AN <= "11101111"; -- AN4
                seg7 <= to_7seg_active_low(digits(4));
            when 5 =>
                AN <= "11011111"; -- AN5
                seg7 <= to_7seg_active_low(digits(5));
            when 6 =>
                AN <= "10111111"; -- AN6
                seg7 <= to_7seg_active_low(digits(6));
            when others =>
                AN <= "01111111"; -- AN7
                seg7 <= to_7seg_active_low(digits(7));
        end case;
    end process;

    --! Direktno povezivanje segmenata
    CA <= seg7(6);
    --! Povezivanje segmenta B
    CB <= seg7(5);
    --! Povezivanje segmenta C
    CC <= seg7(4);
    --! Povezivanje segmenta D
    CD <= seg7(3);
    --! Povezivanje segmenta E
    CE <= seg7(2);
    --! Povezivanje segmenta F
    CF <= seg7(1);
    --! Povezivanje segmenta G
    CG <= seg7(0);

    --------------------------------------------------------------------
    -- DP:
    -- AN6 = poslije poena prvog igraca
    -- AN2 = poslije gemova
    --------------------------------------------------------------------
    --! @brief Kontrola decimalnih tačaka kao separatora.
    process(scan_sel)
    begin
        case to_integer(scan_sel) is
            when 6 => DP <= '0';
            when 2 => DP <= '0';
            when others => DP <= '1';
        end case;
    end process;

end Behavioral;