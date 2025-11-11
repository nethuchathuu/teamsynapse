:- dynamic(patient/2).
:- dynamic(diag/2).

% Knowledge Base: Questions

question(1,'When you get a headache, can you still continue normal work or do you need to stop and rest?').
question(2,'Is your headache so painful that you cannot concentrate, study, or work?').
question(3,'Is your headache throbbing or pounding (like heartbeat pain)?').
question(4,'Do you prefer pills/tablets?').
question(5,'Is the pain on one side of your head or behind one eye?').
question(6,'Do you want fast relief?').
question(7,'Can you take injections?').
question(8,'Do you have heart problems?').
question(9,'Does the headache last many hours?').
question(10,'Have doctors told you that you have poor blood circulation in your legs or feet? (for example, pain when walking or cold feet)').
question(11,'Are you currently having chemotherapy?').
question(12,'Do you have nausea or vomiting after surgery?').
question(13,'Do you have acid reflux or heartburn?').
question(14,'Do you have a viral infection like a cold or flu?').
question(15,'Do you have Raynaud\'s disease (very cold fingers/toes)?').
question(16,'Do you have muscle tension in your neck or shoulders?').
question(17,'Have you ever had fits or sudden body shaking (like epilepsy)?').
question(18,'Do you often feel very worried, nervous, or tense (like anxiety)?').
question(19,'Do you have stomach problems like ulcers or bleeding?').
question(20,'Do you often get dehydrated?').
question(21,'Before today, have you ever taken migraine medicines like Sumatriptan or Zomig, and had any bad reaction (rash, dizziness, etc.)?').
question(22,'Are you allergic to ergotamine?').
question(23,'Are you allergic to CGRP migraine medicines?').
question(24,'Are you allergic to NSAIDs (ibuprofen, naproxen)?').
question(25,'Are you allergic to anti-nausea medicines?').
question(26,'Are you allergic to combination headache medicines?').
question(27,'Do you have slow stomach emptying (gastroparesis)?').
question(28,'Do you have high blood pressure?').
question(29,'Are you pregnant or breastfeeding?').
question(30,'Are you taking other medicines?').
question(31,'Are you taking other headache medicines?').
question(32,'Do you have a stomach or intestinal infection?').
question(33,'Have you recently been exposed to radiation?').
question(34,'Are you taking medicines that raise serotonin (risk of serotonin syndrome)?').
question(35,'Do you have liver or kidney disease?').
question(36,'Do you have osteoarthritis?').
question(37,'Do you drink alcohol heavily?').
question(38,'Do you have visual symptoms like flashing lights or partial vision loss (aura)?').
question(39,'Are you taking antidepressant medicines?').
question(40,'Do you have any inflammation or infection?').
question(41,'Do you have brainstem aura symptoms (dizziness, trouble speaking, fainting)?').
question(42,'Do you have arthritis?').
question(43,'Do you use one dose per migraine attack?').
question(44,'Do you have irritable bowel syndrome (IBS)?').
question(45,'Are you sensitive to light?').
question(46,'Are you sensitive to sound?').
question(47,'Is touch painful or uncomfortable during a headache?').
question(48,'Do you have nausea?').
question(49,'Are you vomiting?').
question(50,'Do you have blurred vision?').
question(51,'Do you feel lightheaded?').
question(52,'Do you have dizziness, confusion, or trouble speaking?').
question(53,'Do you have neck pain?').
question(54,'Do you have severe pain at the upper neck or back of the head?').
question(55,'Do you prefer suppositories (medicine inserted into the rectum)?').
question(56, 'Do you often skip meals or fast for long hours?').
question(57, 'Do you spend long hours in front of a phone or computer screen?').
question(58, 'Do you feel headaches worsen under hot sun or dehydration?').
question(59, 'Do you drink tea or coffee more than 2–3 cups per day?').
question(60, 'Do you sleep less than 6 hours at night or have irregular sleep?').
question(61, 'Do you travel long distances or by bus/train often before headache starts?').
question(62, 'Do you experience headaches during stressful or emotional days?').

% User Interaction Predicates

% Ask a question if not already answered
ask(QID) :- patient(QID,_), !.
ask(QID) :- question(QID,Text), format('~w (yes/no): ', [Text]), read(Response),
            (Response == yes ; Response == no), !, assertz(patient(QID,Response)).
ask(QID) :- write('Please answer "yes." or "no."'), nl, ask(QID).

% Retrieve answer for a question
answer(QID,Val) :- (patient(QID,V) -> Val = V ; ask(QID), patient(QID,Val)).
yes(QID) :- answer(QID,yes).
no(QID) :- answer(QID,no).

% Core Feature Sets for Diagnosis
key_features_without_aura([2,3,5,48,49,45,46]).
key_features_with_aura([2,3,5,38,48,45,46]).

% Count number of 'yes' matches for a set of questions
match_count([],0,[]).
match_count([Q|Qs],Count,Matched) :-
    (answer(Q,yes) ->
        match_count(Qs,C1,M1), Count is C1+1, Matched=[Q|M1]
    ;
        match_count(Qs,C1,M1), Count=C1, Matched=M1).

% Calculate confidence percentage
confidence_percentage(M,T,P) :-
    ( T =:= 0 ->
        P = 0
    ;
        % multiply before dividing to keep precision, then round
        PFloat is (M * 100) / T,
        P is round(PFloat)
    ).

% New diagnosis logic informed by ICHD-3-like rules
try_diagnose(Type,Confidence,Matched) :-
    % define core feature sets
    CoreWithAura = [2,3,5,48,45,46],      % core features excluding aura (38)
    CoreWithoutAura = [2,3,5,48,49,45,46],

    % check for aura-first rule
    ( answer(38,yes) ->
        % count matches among core-without-aura
        match_count(CoreWithAura, MCore, MatchedCore),
        length(CoreWithAura, TotalCore),
        % additional aura rule requirements:
        % at least 3 core features AND (nausea/vomiting OR both photophobia+phonophobia)
        ( MCore >= 3,
          ( answer(48,yes) ; answer(49,yes) ; (answer(45,yes), answer(46,yes)) ) ->
            confidence_percentage(MCore, TotalCore, Conf),
            Type = migraine_with_aura,
            Confidence = Conf,
            Matched = [38|MatchedCore]
        ;
            % aura present but not enough core features
            Type = not_a_migraine, Confidence = 0, Matched = []
        )
    ;
        % no aura: evaluate without-aura criteria
        match_count(CoreWithoutAura, MCoreWO, MatchedWO),
        length(CoreWithoutAura, TotalWO),
        ( % condition 1: at least 4 core features
          MCoreWO >= 4 ->
            confidence_percentage(MCoreWO, TotalWO, Conf2),
            Type = migraine_without_aura, Confidence = Conf2, Matched = MatchedWO
        ; % condition 2: mandatory features 2,3,5 plus one additional among {48,49,45,46}
          ( answer(2,yes), answer(3,yes), answer(5,yes),
            ( answer(48,yes) ; answer(49,yes) ; answer(45,yes) ; answer(46,yes) ) ) ->
            % recompute matched list & confidence
            match_count(CoreWithoutAura, MCoreWO2, MatchedWO2),
            confidence_percentage(MCoreWO2, TotalWO, Conf3),
            Type = migraine_without_aura, Confidence = Conf3, Matched = MatchedWO2
        ;
            % fallback
            Type = not_a_migraine, Confidence = 0, Matched = []
        )
    ).

% Ensure required core answers are present before attempting diagnosis
ensure_core_answers([]).
ensure_core_answers([Q|Qs]) :- answer(Q,_), ensure_core_answers(Qs).

% Ask safety/allergy/comorbidity questions proactively after diagnosis
proactive_safety_questions(Type) :-
    ( (Type == migraine_with_aura ; Type == migraine_without_aura) ->
        SafetyQs = [21,8,10,28,24,19,25,29],
        ensure_core_answers(SafetyQs)
    ; true ).

% Conditional follow-ups to disambiguate partial matches
ask_conditional_followups :-
    Followups = [9,43,6,27,30],
    ensure_core_answers(Followups).

diagnose :-
    retractall(diag(_,_)),
    % core question set required
    CoreQ = [2,3,5,38,45,46,48,49],
    ensure_core_answers(CoreQ),
    % compute initial matched core count
    match_count(CoreQ,InitialMatchedCount,InitialMatchedList),
    try_diagnose(Type,Conf,Matched),
    ( Type == not_a_migraine,
      InitialMatchedCount >= 2,
      InitialMatchedCount < 4 ->
        % partial match: ask follow-ups and retry
        ask_conditional_followups,
        try_diagnose(Type2,Conf2,Matched2),
        FinalType = Type2, FinalConf = Conf2, FinalMatched = Matched2
    ;
        FinalType = Type, FinalConf = Conf, FinalMatched = Matched
    ),
    % proactively ask safety questions used in recommendations
    proactive_safety_questions(FinalType),
    assertz(diag(FinalType,FinalConf)),
    nl,
    write('Diagnosis: '), write(FinalType), nl,
    write('Confidence: '), write(FinalConf), write('%'), nl,
    explain(FinalMatched,FinalType), nl,
    recommend(FinalType).

% Explanation & Matched Questions
explain([],not_a_migraine) :-
    write('Explanation: Insufficient key migraine features detected. Consider other headache types.'), nl.
explain(MatchedQs,Type) :-
    MatchedQs \= [],
    write('Explanation: Diagnosis supported by:'), nl,
    print_matched(MatchedQs),
    write('Rule matched: '), write(Type), nl.
print_matched([]).
print_matched([Q|Qs]) :-
    question(Q,Text),
    write('- ('), write(Q), write(') '), write(Text), nl,
    print_matched(Qs).

% Recommendations
recommend(Type) :-
    (Type == not_a_migraine ->
        write('No migraine detected. Consult clinician if persistent.'), nl
    ;
        write('Recommended medications:'), nl,
        recommend_triptans,
        recommend_nsaids,
        recommend_anti_nausea, nl,
        write('Lifestyle:'), nl,
        list_activities, nl,
        write('Diet:'), nl,
        write('Eat:'), nl,
        foods(suitable,S), print_foods(S),
        write('Avoid:'), nl,
        foods(avoid,A), print_foods(A),
        nl,
        write('Specialists:'), nl, list_doctors).

recommend_triptans :-
    (answer(21,yes) -> write('- Triptans (special migraine tablets): NOT recommended (allergy).'), nl
    ;answer(8,yes) -> write('- Triptans (like Sumatriptan): Avoid due to heart problems.'), nl
    ;write('- Triptans (special migraine tablets like Sumatriptan): Can help if no heart or blood issues.'), nl).

recommend_nsaids :-
    (answer(24,yes) -> write('- Common painkillers (Panadol, Ibuprofen): NOT recommended (allergy).'), nl
    ;write('- Common painkillers like Panadol or Ibuprofen: Can be used early during headache.'), nl).


recommend_anti_nausea :-
    ((answer(48,yes);answer(49,yes)) ->
        (answer(25,yes) -> write('- Anti-nausea meds: NOT recommended (allergy).'), nl
        ;write('- Anti-nausea meds: Recommended for nausea/vomiting.'), nl)
    ;true).

% Lifestyle tips
list_activities :-
    write('- Regular sleep schedule.'), nl,
    write('- Stay hydrated.'), nl,
    write('- Manage stress, relax.'), nl,
    write('- Avoid bright light; rest in quiet room.'), nl.

% Food recommendations
foods(suitable, [
    'Fresh fruits like banana, papaya, and watermelon',
    'Vegetables (especially green leaves)',
    'Rice, kurakkan, or whole grains',
    'Light meals taken regularly',
    'Plenty of water and king coconut'
]).

foods(avoid, [
    'Too much tea or coffee',
    'Spicy or oily curries',
    'Coconut milk-heavy meals at night',
    'MSG or instant noodles',
    'Skipping breakfast'
]).

print_foods([]).
print_foods([H|T]) :-
    write('- '), write(H), nl,
    print_foods(T).

% List recommended specialists
list_doctors :-
    write('- Primary Care Physician'), nl,
    write('- Neurologist / Headache Specialist'), nl,
    write('- Pain Specialist'), nl.

% Run System
run :-
    retractall(patient(_,_)),
    retractall(diag(_,_)),
    write('--- NeuroRelief Sri Lanka (Migraine Expert System) ---'), nl,
    write('This tool helps identify if your headache matches migraine patterns.'), nl,
    write('Please answer in simple "yes." or "no."'), nl,
    write('If unsure, you can type "no."'), nl, nl,
    diagnose, nl,
    write('--- End of Consultation ---'), nl.

% Reset all answers and diagnosis
reset_answers :-
    retractall(patient(_,_)),
    retractall(diag(_,_)),
    write('All stored answers and diagnosis cleared.'), nl.
