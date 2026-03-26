library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--! @file TennisMain.vhd
--! @brief Glavni modul za upravljanje logikom teniskog semafora.
--! @details
--! Ovaj modul implementira kompletnu logiku teniskog meča:
--! - brojanje poena (0, 15, 30, 40, Advantage)
--! - deuce/advantage logiku
--! - brojanje gemova
--! - brojanje setova
--! - tie-break pri rezultatu 6:6
--! - reset gemova nakon osvojenog seta
--! - undo funkcionalnost za posljednju akciju
--! - blokadu daljeg unosa poena nakon 3 osvojena seta
--! @author Jelena Radaković
--! @version 1.0

--! @brief Entitet glavnog modula teniskog semafora.
entity TennisMain is
    port(
        --! Ulazni clock signal
        clk, reset       : in std_logic;
        --! Taster za dodavanje poena igraču A
        button_a         : in std_logic;
        --! Taster za dodavanje poena igraču B
        button_b         : in std_logic;
        --! Taster za undo posljednje akcije igrača A
        undo_a           : in std_logic;
        --! Taster za undo posljednje akcije igrača B
        undo_b           : in std_logic;

        --! Kodirani izlaz poena igrača A
        display_points_a : out std_logic_vector(2 downto 0);
        --! Kodirani izlaz poena igrača B
        display_points_b : out std_logic_vector(2 downto 0);
        --! Broj gemova igrača A
        display_games_a  : out unsigned(3 downto 0);
        --! Broj gemova igrača B
        display_games_b  : out unsigned(3 downto 0);
        --! Broj setova igrača A
        display_sets_a   : out unsigned(3 downto 0);
        --! Broj setova igrača B
        display_sets_b   : out unsigned(3 downto 0);

        --! Signal koji označava da li je tie-break aktivan
        tb_active        : out std_logic;
        --! Tie-break rezultat igrača A
        display_tb_a     : out unsigned(3 downto 0);
        --! Tie-break rezultat igrača B
        display_tb_b     : out unsigned(3 downto 0)
    );
end TennisMain;

--! @brief Behavioral arhitektura glavnog modula.
architecture Behavioral of TennisMain is

    --! Interni kod poena:
    --! 0 = 0, 1 = 15, 2 = 30, 3 = 40, 4 = ADV
    signal points_a_i : unsigned(2 downto 0) := (others => '0');
    --! Interni kod poena igrača B
    signal points_b_i : unsigned(2 downto 0) := (others => '0');

    --! Interni brojač gemova igrača A
    signal games_a_i  : unsigned(3 downto 0) := (others => '0');
    --! Interni brojač gemova igrača B
    signal games_b_i  : unsigned(3 downto 0) := (others => '0');

    --! Interni brojač setova igrača A
    signal sets_a_i   : unsigned(3 downto 0) := (others => '0');
    --! Interni brojač setova igrača B
    signal sets_b_i   : unsigned(3 downto 0) := (others => '0');

    --! Interni tie-break rezultat igrača A
    signal tb_a_i     : unsigned(3 downto 0) := (others => '0');
    --! Interni tie-break rezultat igrača B
    signal tb_b_i     : unsigned(3 downto 0) := (others => '0');
    --! Registar koji označava da li je tie-break aktivan
    signal tie_break_reg : std_logic := '0';

    --! Signal koji označava da je meč završen
    signal match_over : std_logic := '0';

    --! One-pulse signali za dodavanje poena
    signal btn_a_pulse, btn_b_pulse   : std_logic := '0';
    --! One-pulse signali za undo
    signal undo_a_pulse, undo_b_pulse : std_logic := '0';
    --! Prethodno stanje tastera A i B
    signal last_btn_a, last_btn_b     : std_logic := '0';
    --! Prethodno stanje undo tastera
    signal last_undo_a, last_undo_b   : std_logic := '0';

    --! Snapshot prethodnog stanja za undo funkcionalnosi
    signal prev_points_a : unsigned(2 downto 0) := (others => '0');
    signal prev_points_b : unsigned(2 downto 0) := (others => '0');
    signal prev_games_a  : unsigned(3 downto 0) := (others => '0');
    signal prev_games_b  : unsigned(3 downto 0) := (others => '0');
    signal prev_sets_a   : unsigned(3 downto 0) := (others => '0');
    signal prev_sets_b   : unsigned(3 downto 0) := (others => '0');
    signal prev_tb_a     : unsigned(3 downto 0) := (others => '0');
    signal prev_tb_b     : unsigned(3 downto 0) := (others => '0');
    signal prev_tb_active : std_logic := '0';

    --! Signal koji označava da li je undo dozvoljen
    signal undo_valid    : std_logic := '0';
    --! Signal koji označava da je posljednja akcija bila od igrača A
    signal last_action_a : std_logic := '0';
    --! Signal koji označava da je posljednja akcija bila od igrača B
    signal last_action_b : std_logic := '0';

begin

    --! @brief Detekcija kraja meča.
    --! @details Meč je gotov kada jedan od igrača osvoji 3 seta.
    match_over <= '1' when (sets_a_i = 3 or sets_b_i = 3) else '0';

    --------------------------------------------------------------------
    -- One-pulse
    --------------------------------------------------------------------
    --! @brief Generisanje one-pulse impulsa za tastere.
    --! @details
    --! Ovaj proces obezbjeđuje da se svaki pritisak tastera registruje
    --! samo jednom, bez obzira koliko dugo je taster zadržan.
    process(clk)
    begin
        if rising_edge(clk) then
            last_btn_a   <= button_a;
            btn_a_pulse  <= button_a and not last_btn_a;

            last_btn_b   <= button_b;
            btn_b_pulse  <= button_b and not last_btn_b;

            last_undo_a  <= undo_a;
            undo_a_pulse <= undo_a and not last_undo_a;

            last_undo_b  <= undo_b;
            undo_b_pulse <= undo_b and not last_undo_b;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Glavna logika
    --------------------------------------------------------------------
    --! @brief Glavni sekvencijalni proces za upravljanje tokom meča.
    --! @details
    --! Ovaj proces upravlja:
    --! - resetovanjem stanja
    --! - undo funkcijom
    --! - normalnim tokom osvajanja poena, gemova i setova
    --! - tie-break logikom
    --! - blokadom sistema nakon završetka meča
    process(clk, reset)
        --! Trenutni broj poena igrača A u integer formi
        variable pa, pb : integer;
        --! Trenutni broj gemova igrača A i B
        variable ga, gb : integer;
        --! Trenutni broj setova igrača A i B
        variable sa, sb : integer;
        --! Trenutni tie-break rezultat igrača A i B
        variable tba, tbb : integer;
        --! Privremeni novi broj gemova
        variable new_ga, new_gb : integer;
        --! Privremeni novi tie-break rezultat
        variable new_tba, new_tbb : integer;
    begin
        if reset = '1' then
            points_a_i <= (others => '0');
            points_b_i <= (others => '0');
            games_a_i  <= (others => '0');
            games_b_i  <= (others => '0');
            sets_a_i   <= (others => '0');
            sets_b_i   <= (others => '0');
            tb_a_i     <= (others => '0');
            tb_b_i     <= (others => '0');
            tie_break_reg <= '0';

            prev_points_a <= (others => '0');
            prev_points_b <= (others => '0');
            prev_games_a  <= (others => '0');
            prev_games_b  <= (others => '0');
            prev_sets_a   <= (others => '0');
            prev_sets_b   <= (others => '0');
            prev_tb_a     <= (others => '0');
            prev_tb_b     <= (others => '0');
            prev_tb_active <= '0';

            undo_valid    <= '0';
            last_action_a <= '0';
            last_action_b <= '0';

        elsif rising_edge(clk) then

            --! @brief Undo funkcionalnost.
            --! @details Vraća kompletno prethodno stanje samo za zadnju validnu akciju.
            if (undo_a_pulse = '1' and undo_valid = '1' and last_action_a = '1') or
               (undo_b_pulse = '1' and undo_valid = '1' and last_action_b = '1') then

                points_a_i <= prev_points_a;
                points_b_i <= prev_points_b;
                games_a_i  <= prev_games_a;
                games_b_i  <= prev_games_b;
                sets_a_i   <= prev_sets_a;
                sets_b_i   <= prev_sets_b;
                tb_a_i     <= prev_tb_a;
                tb_b_i     <= prev_tb_b;
                tie_break_reg <= prev_tb_active;

                undo_valid    <= '0';
                last_action_a <= '0';
                last_action_b <= '0';

            else
                pa  := to_integer(points_a_i);
                pb  := to_integer(points_b_i);
                ga  := to_integer(games_a_i);
                gb  := to_integer(games_b_i);
                sa  := to_integer(sets_a_i);
                sb  := to_integer(sets_b_i);
                tba := to_integer(tb_a_i);
                tbb := to_integer(tb_b_i);

                --! @brief Blokada unosa poena nakon kraja meča.
                if match_over = '1' then
                    null;

                ----------------------------------------------------------------
                -- TIE-BREAK
                ----------------------------------------------------------------
                --! @brief Logika za tie-break režim.
                elsif tie_break_reg = '1' then

                    if btn_a_pulse = '1' then
                        prev_points_a  <= points_a_i;
                        prev_points_b  <= points_b_i;
                        prev_games_a   <= games_a_i;
                        prev_games_b   <= games_b_i;
                        prev_sets_a    <= sets_a_i;
                        prev_sets_b    <= sets_b_i;
                        prev_tb_a      <= tb_a_i;
                        prev_tb_b      <= tb_b_i;
                        prev_tb_active <= tie_break_reg;
                        undo_valid     <= '1';
                        last_action_a  <= '1';
                        last_action_b  <= '0';

                        new_tba := tba + 1;

                        if (new_tba >= 7) and (new_tba >= tbb + 2) then
                            if sa < 3 then
                                sets_a_i <= to_unsigned(sa + 1, 4);
                            end if;
                            games_a_i <= (others => '0');
                            games_b_i <= (others => '0');
                            points_a_i <= (others => '0');
                            points_b_i <= (others => '0');
                            tb_a_i <= (others => '0');
                            tb_b_i <= (others => '0');
                            tie_break_reg <= '0';
                        else
                            tb_a_i <= to_unsigned(new_tba, 4);
                        end if;

                    elsif btn_b_pulse = '1' then
                        prev_points_a  <= points_a_i;
                        prev_points_b  <= points_b_i;
                        prev_games_a   <= games_a_i;
                        prev_games_b   <= games_b_i;
                        prev_sets_a    <= sets_a_i;
                        prev_sets_b    <= sets_b_i;
                        prev_tb_a      <= tb_a_i;
                        prev_tb_b      <= tb_b_i;
                        prev_tb_active <= tie_break_reg;
                        undo_valid     <= '1';
                        last_action_a  <= '0';
                        last_action_b  <= '1';

                        new_tbb := tbb + 1;

                        if (new_tbb >= 7) and (new_tbb >= tba + 2) then
                            if sb < 3 then
                                sets_b_i <= to_unsigned(sb + 1, 4);
                            end if;
                            games_a_i <= (others => '0');
                            games_b_i <= (others => '0');
                            points_a_i <= (others => '0');
                            points_b_i <= (others => '0');
                            tb_a_i <= (others => '0');
                            tb_b_i <= (others => '0');
                            tie_break_reg <= '0';
                        else
                            tb_b_i <= to_unsigned(new_tbb, 4);
                        end if;
                    end if;

                ----------------------------------------------------------------
                -- NORMALNI GEMOVI
                ----------------------------------------------------------------
                --! @brief Logika za normalnu igru van tie-break režima.
                else

                    ------------------------------------------------------------
                    -- Poen za A
                    ------------------------------------------------------------
                    if btn_a_pulse = '1' then
                        prev_points_a  <= points_a_i;
                        prev_points_b  <= points_b_i;
                        prev_games_a   <= games_a_i;
                        prev_games_b   <= games_b_i;
                        prev_sets_a    <= sets_a_i;
                        prev_sets_b    <= sets_b_i;
                        prev_tb_a      <= tb_a_i;
                        prev_tb_b      <= tb_b_i;
                        prev_tb_active <= tie_break_reg;
                        undo_valid     <= '1';
                        last_action_a  <= '1';
                        last_action_b  <= '0';

                        if pa <= 2 then
                            points_a_i <= to_unsigned(pa + 1, 3);

                        elsif pa = 3 then
                            if pb <= 2 then
                                new_ga := ga + 1;

                                points_a_i <= (others => '0');
                                points_b_i <= (others => '0');

                                if (new_ga >= 6) and (new_ga >= gb + 2) then
                                    if sa < 3 then
                                        sets_a_i <= to_unsigned(sa + 1, 4);
                                    end if;
                                    games_a_i <= (others => '0');
                                    games_b_i <= (others => '0');
                                    tb_a_i <= (others => '0');
                                    tb_b_i <= (others => '0');
                                    tie_break_reg <= '0';

                                elsif (new_ga = 6) and (gb = 6) then
                                    games_a_i <= to_unsigned(new_ga, 4);
                                    tb_a_i <= (others => '0');
                                    tb_b_i <= (others => '0');
                                    tie_break_reg <= '1';

                                else
                                    games_a_i <= to_unsigned(new_ga, 4);
                                end if;

                            elsif pb = 3 then
                                points_a_i <= to_unsigned(4, 3); -- ADV A

                            else
                                points_b_i <= to_unsigned(3, 3); -- vrati sa ADV B na 40
                            end if;

                        else
                            new_ga := ga + 1; -- A sa ADV osvaja gem

                            points_a_i <= (others => '0');
                            points_b_i <= (others => '0');

                            if (new_ga >= 6) and (new_ga >= gb + 2) then
                                if sa < 3 then
                                    sets_a_i <= to_unsigned(sa + 1, 4);
                                end if;
                                games_a_i <= (others => '0');
                                games_b_i <= (others => '0');
                                tb_a_i <= (others => '0');
                                tb_b_i <= (others => '0');
                                tie_break_reg <= '0';

                            elsif (new_ga = 6) and (gb = 6) then
                                games_a_i <= to_unsigned(new_ga, 4);
                                tb_a_i <= (others => '0');
                                tb_b_i <= (others => '0');
                                tie_break_reg <= '1';

                            else
                                games_a_i <= to_unsigned(new_ga, 4);
                            end if;
                        end if;

                    ------------------------------------------------------------
                    -- Poen za B
                    ------------------------------------------------------------
                    elsif btn_b_pulse = '1' then
                        prev_points_a  <= points_a_i;
                        prev_points_b  <= points_b_i;
                        prev_games_a   <= games_a_i;
                        prev_games_b   <= games_b_i;
                        prev_sets_a    <= sets_a_i;
                        prev_sets_b    <= sets_b_i;
                        prev_tb_a      <= tb_a_i;
                        prev_tb_b      <= tb_b_i;
                        prev_tb_active <= tie_break_reg;
                        undo_valid     <= '1';
                        last_action_a  <= '0';
                        last_action_b  <= '1';

                        if pb <= 2 then
                            points_b_i <= to_unsigned(pb + 1, 3);

                        elsif pb = 3 then
                            if pa <= 2 then
                                new_gb := gb + 1;

                                points_a_i <= (others => '0');
                                points_b_i <= (others => '0');

                                if (new_gb >= 6) and (new_gb >= ga + 2) then
                                    if sb < 3 then
                                        sets_b_i <= to_unsigned(sb + 1, 4);
                                    end if;
                                    games_a_i <= (others => '0');
                                    games_b_i <= (others => '0');
                                    tb_a_i <= (others => '0');
                                    tb_b_i <= (others => '0');
                                    tie_break_reg <= '0';

                                elsif (new_gb = 6) and (ga = 6) then
                                    games_b_i <= to_unsigned(new_gb, 4);
                                    tb_a_i <= (others => '0');
                                    tb_b_i <= (others => '0');
                                    tie_break_reg <= '1';

                                else
                                    games_b_i <= to_unsigned(new_gb, 4);
                                end if;

                            elsif pa = 3 then
                                points_b_i <= to_unsigned(4, 3); -- ADV B

                            else
                                points_a_i <= to_unsigned(3, 3); -- vrati sa ADV A na 40
                            end if;

                        else
                            new_gb := gb + 1; -- B sa ADV osvaja gem

                            points_a_i <= (others => '0');
                            points_b_i <= (others => '0');

                            if (new_gb >= 6) and (new_gb >= ga + 2) then
                                if sb < 3 then
                                    sets_b_i <= to_unsigned(sb + 1, 4);
                                end if;
                                games_a_i <= (others => '0');
                                games_b_i <= (others => '0');
                                tb_a_i <= (others => '0');
                                tb_b_i <= (others => '0');
                                tie_break_reg <= '0';

                            elsif (new_gb = 6) and (ga = 6) then
                                games_b_i <= to_unsigned(new_gb, 4);
                                tb_a_i <= (others => '0');
                                tb_b_i <= (others => '0');
                                tie_break_reg <= '1';

                            else
                                games_b_i <= to_unsigned(new_gb, 4);
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Kodiranje poena za display
    --------------------------------------------------------------------
    --! @brief Kodiranje internog stanja poena igrača A za izlazni prikaz.
    process(points_a_i)
    begin
        case to_integer(points_a_i) is
            when 0      => display_points_a <= "000";
            when 1      => display_points_a <= "001";
            when 2      => display_points_a <= "010";
            when 3      => display_points_a <= "011";
            when 4      => display_points_a <= "100";
            when others => display_points_a <= "000";
        end case;
    end process;

    --! @brief Kodiranje internog stanja poena igrača B za izlazni prikaz.
    process(points_b_i)
    begin
        case to_integer(points_b_i) is
            when 0      => display_points_b <= "000";
            when 1      => display_points_b <= "001";
            when 2      => display_points_b <= "010";
            when 3      => display_points_b <= "011";
            when 4      => display_points_b <= "100";
            when others => display_points_b <= "000";
        end case;
    end process;

    --! Direktno povezivanje internih registara sa izlazima
    display_games_a <= games_a_i;
    display_games_b <= games_b_i;
    display_sets_a  <= sets_a_i;
    display_sets_b  <= sets_b_i;

    tb_active    <= tie_break_reg;
    display_tb_a <= tb_a_i;
    display_tb_b <= tb_b_i;

end Behavioral;