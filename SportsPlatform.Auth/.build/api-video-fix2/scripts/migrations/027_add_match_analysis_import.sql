CREATE TABLE IF NOT EXISTS public.match_analysis_report (
    report_id uuid PRIMARY KEY,
    team_id uuid NULL REFERENCES public.team(team_id) ON DELETE SET NULL,
    team_code varchar(20) NOT NULL,
    opponent_code varchar(20) NOT NULL,
    opponent_name varchar(120) NOT NULL,
    match_date date NOT NULL,
    competition varchar(160) NOT NULL,
    venue varchar(180) NULL,
    game_no varchar(80) NULL,
    team_score integer NOT NULL,
    opponent_score integer NOT NULL,
    result varchar(20) NOT NULL,
    summary text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.match_lineup_analysis (
    lineup_id uuid PRIMARY KEY,
    report_id uuid NOT NULL REFERENCES public.match_analysis_report(report_id) ON DELETE CASCADE,
    team_code varchar(20) NOT NULL,
    lineup_players text NOT NULL,
    time_on_court varchar(12) NOT NULL,
    time_seconds integer NOT NULL,
    points_for integer NOT NULL,
    points_against integer NOT NULL,
    score_diff integer NOT NULL,
    points_per_minute numeric(8, 4) NOT NULL,
    rebounds integer NOT NULL,
    steals integer NOT NULL,
    turnovers integer NOT NULL,
    assists integer NOT NULL
);

CREATE TABLE IF NOT EXISTS public.match_analysis_document (
    document_id uuid PRIMARY KEY,
    report_id uuid NOT NULL REFERENCES public.match_analysis_report(report_id) ON DELETE CASCADE,
    document_type varchar(80) NOT NULL,
    file_name varchar(240) NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_match_analysis_report_match_date ON public.match_analysis_report(match_date);
CREATE INDEX IF NOT EXISTS ix_match_analysis_report_team_id ON public.match_analysis_report(team_id);
CREATE INDEX IF NOT EXISTS ix_match_lineup_analysis_report_diff ON public.match_lineup_analysis(report_id, score_diff);

INSERT INTO public.match_analysis_report (
    report_id, team_code, opponent_code, opponent_name, match_date, competition, venue, game_no,
    team_score, opponent_score, result, summary, created_at, updated_at
) VALUES
('11111111-1111-1111-1111-111111111111', 'EGY', 'MLI', 'Mali', DATE '2026-02-26', 'FIBA Egypt match reports', 'Borg Elarab Arena', '29779-D-1', 77, 86, 'Loss', 'Egypt lost by 9 after Mali controlled several extended lineup runs. The best Egypt unit was +6 in 2:49 with Amin, Abdelhalim, Metwaly, Mahmoud, and Marei.', now(), now()),
('22222222-2222-2222-2222-222222222222', 'EGY', 'ANG', 'Angola', DATE '2026-02-28', 'FIBA Egypt match reports', 'Borg Elarab Arena', '29779-D-4', 72, 83, 'Loss', 'Egypt lost by 11 to Angola. The opening Marei group stayed positive at +1 over 6:19, while one four-minute stretch was heavily negative.', now(), now()),
('33333333-3333-3333-3333-333333333333', 'EGY', 'UGA', 'Uganda', DATE '2026-03-01', 'FIBA Egypt match reports', 'Borg Elarab Arena', '29779-D-6', 91, 52, 'Win', 'Egypt won by 39 against Uganda. The Zahran, Amin, Moussa, Mahmoud, and Oraby unit produced the strongest run at +15 in 7:13.', now(), now())
ON CONFLICT (report_id) DO UPDATE SET
    team_code = EXCLUDED.team_code,
    opponent_code = EXCLUDED.opponent_code,
    opponent_name = EXCLUDED.opponent_name,
    match_date = EXCLUDED.match_date,
    competition = EXCLUDED.competition,
    venue = EXCLUDED.venue,
    game_no = EXCLUDED.game_no,
    team_score = EXCLUDED.team_score,
    opponent_score = EXCLUDED.opponent_score,
    result = EXCLUDED.result,
    summary = EXCLUDED.summary,
    updated_at = now();

INSERT INTO public.match_lineup_analysis (
    lineup_id, report_id, team_code, lineup_players, time_on_court, time_seconds,
    points_for, points_against, score_diff, points_per_minute, rebounds, steals, turnovers, assists
) VALUES
('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'EGY', '4- Amin E/ 7- Metwaly A/ 8- Abdalatif M/ 10- Mahmoud A/ 15- Gardner P/', '06:07', 367, 12, 16, -4, 1.9619, 7, 2, 3, 2),
('10000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'EGY', '4- Amin E/ 7- Metwaly A/ 8- Abdalatif M/ 10- Mahmoud A/ 28- Abdelgawad K/', '05:25', 325, 8, 12, -4, 1.4769, 5, 1, 2, 2),
('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'EGY', '5- Abdelhalim A/ 7- Metwaly A/ 9- Moussa A/ 15- Gardner P/ 55- Oraby O/', '04:48', 288, 9, 4, 5, 1.8750, 6, 0, 0, 3),
('10000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'EGY', '1- Zahran I/ 5- Abdelhalim A/ 9- Moussa A/ 28- Abdelgawad K/ 55- Oraby O/', '03:26', 206, 7, 2, 5, 2.0388, 3, 1, 0, 1),
('10000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'EGY', '1- Zahran I/ 4- Amin E/ 5- Abdelhalim A/ 7- Metwaly A/ 10- Mahmoud A/', '02:49', 169, 12, 6, 6, 4.2553, 2, 1, 0, 4),
('10000000-0000-0000-0000-000000000006', '22222222-2222-2222-2222-222222222222', 'EGY', '5- Abdelhalim A/ 7- Metwaly A/ 8- Abdalatif M/ 10- Mahmoud A/ 50- Marei A/', '06:19', 379, 12, 11, 1, 1.8997, 5, 0, 1, 4),
('10000000-0000-0000-0000-000000000007', '22222222-2222-2222-2222-222222222222', 'EGY', '1- Zahran I/ 5- Abdelhalim A/ 9- Moussa A/ 15- Gardner P/ 55- Oraby O/', '05:34', 334, 9, 9, 0, 1.6168, 10, 0, 0, 3),
('10000000-0000-0000-0000-000000000008', '22222222-2222-2222-2222-222222222222', 'EGY', '1- Zahran I/ 5- Abdelhalim A/ 7- Metwaly A/ 10- Mahmoud A/ 50- Marei A/', '05:07', 307, 4, 6, -2, 0.7797, 5, 1, 0, 2),
('10000000-0000-0000-0000-000000000009', '22222222-2222-2222-2222-222222222222', 'EGY', '4- Amin E/ 7- Metwaly A/ 8- Abdalatif M/ 10- Mahmoud A/ 50- Marei A/', '04:50', 290, 7, 16, -9, 1.4483, 4, 3, 6, 2),
('10000000-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222', 'EGY', '1- Zahran I/ 5- Abdelhalim A/ 9- Moussa A/ 10- Mahmoud A/ 50- Marei A/', '02:38', 158, 8, 7, 1, 3.0208, 2, 0, 0, 1),
('10000000-0000-0000-0000-000000000011', '33333333-3333-3333-3333-333333333333', 'EGY', '4- Amin E/ 5- Abdelhalim A/ 7- Metwaly A/ 15- Gardner P/ 50- Marei A/', '07:44', 464, 17, 14, 3, 2.1983, 7, 2, 2, 5),
('10000000-0000-0000-0000-000000000012', '33333333-3333-3333-3333-333333333333', 'EGY', '1- Zahran I/ 4- Amin E/ 9- Moussa A/ 10- Mahmoud A/ 55- Oraby O/', '07:13', 433, 16, 1, 15, 2.2156, 15, 1, 1, 3),
('10000000-0000-0000-0000-000000000013', '33333333-3333-3333-3333-333333333333', 'EGY', '1- Zahran I/ 4- Amin E/ 7- Metwaly A/ 15- Gardner P/ 50- Marei A/', '05:01', 301, 7, 9, -2, 1.3953, 3, 1, 3, 3),
('10000000-0000-0000-0000-000000000014', '33333333-3333-3333-3333-333333333333', 'EGY', '5- Abdelhalim A/ 9- Moussa A/ 10- Mahmoud A/ 35- Rehan A/ 55- Oraby O/', '04:13', 253, 9, 3, 6, 2.1344, 9, 0, 0, 3),
('10000000-0000-0000-0000-000000000015', '33333333-3333-3333-3333-333333333333', 'EGY', '7- Metwaly A/ 8- Abdalatif M/ 10- Mahmoud A/ 28- Abdelgawad K/ 35- Rehan A/', '01:51', 111, 7, 5, 2, 3.7838, 2, 1, 1, 1)
ON CONFLICT (lineup_id) DO UPDATE SET
    report_id = EXCLUDED.report_id,
    team_code = EXCLUDED.team_code,
    lineup_players = EXCLUDED.lineup_players,
    time_on_court = EXCLUDED.time_on_court,
    time_seconds = EXCLUDED.time_seconds,
    points_for = EXCLUDED.points_for,
    points_against = EXCLUDED.points_against,
    score_diff = EXCLUDED.score_diff,
    points_per_minute = EXCLUDED.points_per_minute,
    rebounds = EXCLUDED.rebounds,
    steals = EXCLUDED.steals,
    turnovers = EXCLUDED.turnovers,
    assists = EXCLUDED.assists;

INSERT INTO public.match_analysis_document (document_id, report_id, document_type, file_name) VALUES
('20000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Box Score', 'FIBA Box Score MLI vs EGY 26 February.pdf'),
('20000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Line Up Analysis', 'Line Up Analysis MLI vs EGY 26 February.pdf'),
('20000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Play by Play', 'Play by Play MLI vs EGY 26 February.pdf'),
('20000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Player PlusMinus Summary', 'Player PlusMinus Summary MLI vs EGY 26 February.pdf'),
('20000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'Shot Areas', 'Shot Areas MLI vs EGY 26 February.pdf'),
('20000000-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'Shot Chart', 'Shot Chart MLI vs EGY 26 February.pdf'),
('20000000-0000-0000-0000-000000000007', '22222222-2222-2222-2222-222222222222', 'Box Score', 'FIBA Box Score EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000008', '22222222-2222-2222-2222-222222222222', 'Line Up Analysis', 'Line Up Analysis EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000009', '22222222-2222-2222-2222-222222222222', 'Play by Play', 'Play by Play EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222', 'Player PlusMinus Summary', 'Player PlusMinus Summary EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000011', '22222222-2222-2222-2222-222222222222', 'Rotations Summary', 'Rotations Summary EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000012', '22222222-2222-2222-2222-222222222222', 'Shot Areas', 'Shot Areas EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000013', '22222222-2222-2222-2222-222222222222', 'Shot Chart', 'Shot Chart EGY vs ANG 28 February.pdf'),
('20000000-0000-0000-0000-000000000014', '33333333-3333-3333-3333-333333333333', 'Box Score', 'FIBA Box Score UGA vs EGY 01 March.pdf'),
('20000000-0000-0000-0000-000000000015', '33333333-3333-3333-3333-333333333333', 'Line Up Analysis', 'Line Up Analysis UGA vs EGY 01 March.pdf'),
('20000000-0000-0000-0000-000000000016', '33333333-3333-3333-3333-333333333333', 'Play by Play', 'Play by Play UGA vs EGY 01 March.pdf'),
('20000000-0000-0000-0000-000000000017', '33333333-3333-3333-3333-333333333333', 'Player PlusMinus Summary', 'Player PlusMinus Summary UGA vs EGY 01 March.pdf'),
('20000000-0000-0000-0000-000000000018', '33333333-3333-3333-3333-333333333333', 'Rotations Summary', 'Rotations Summary UGA vs EGY 01 March.pdf'),
('20000000-0000-0000-0000-000000000019', '33333333-3333-3333-3333-333333333333', 'Shot Areas', 'Shot Areas UGA vs EGY 01 March.pdf'),
('20000000-0000-0000-0000-000000000020', '33333333-3333-3333-3333-333333333333', 'Shot Chart', 'Shot Chart UGA vs EGY 01 March.pdf')
ON CONFLICT (document_id) DO UPDATE SET
    report_id = EXCLUDED.report_id,
    document_type = EXCLUDED.document_type,
    file_name = EXCLUDED.file_name;
