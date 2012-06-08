import Euterpea

harmonize intervals pitch  = (pitch : map (flip trans $ pitch) intervals)
minor root = harmonize [3, 7] root
major root = harmonize [4, 7] root
dim root = harmonize [3, 6] root

iplay ins music = play $ instrument ins music
imelody ins xs = play $ instrument ins $ line xs
cello = instrument Cello
grandPiano = instrument AcousticGrandPiano

swapFirstTwo (x:y:zs) = y:x:zs

attachDur notes durations = zipWith note durations notes
forDur dur notes = zipWith note (repeat dur) notes


prefix = [a 4 qn, b 4 qn, c 5 qn]
middle = [d 5 qn, f 5 qn, b 4 qn, a 4 qn]

center = prefix ++ middle ++ [c 5 (5 / 4)]
sad = prefix ++ middle ++ [e 4 (5 / 4)]
tension = prefix ++ middle ++ [f 4 (5 / 4)]
keening = prefix ++ middle ++ [e 5 (5 / 4)]

build = reverse prefix ++ [e 5 qn] ++ prefix
peak = [es 5 qn] ++ reverse (tail prefix)
turn = (peak ++ [es 5 qn] ++ reverse prefix)


opening = line $ sad ++ [wnr] ++ center ++ [b 4 (3/4)] ++ tension ++ [wnr] ++ keening ++ [wnr]
openingHarmony = line $ map (chord . forDur wn) $ [minor (A, 4), major (F, 4), major (C, 4), minor (E, 4)]
openingSection = cello opening :=: grandPiano (openingHarmony:+:openingHarmony:+:openingHarmony:+:openingHarmony)

turnMelody = line $ build ++ [qnr] ++ turn
turnHarmony = line $ map (chord . forDur wn) $ [major (F, 4), minor (A, 4), major (C, 4), minor (E, 4)]
turnSection = cello turnMelody  :=: grandPiano  turnHarmony

ending = line $ prefix ++ tail middle ++ [e 4 qn, e 4 wn] ++ prefix ++ middle ++ (tail . tail $ middle) ++ [c 5 (4 / 4), b 4 (7 / 4)]
endingHarmony = line $ map (chord . forDur wn) $ [major(F, 4), major(C, 4), minor (E, 4), minor (E, 4)]
endingHarmony2 = line $ map (chord . forDur wn) $ [major(F, 4), minor(A, 4), major (C, 4), minor (E, 4)]
endSection = cello ending :=: grandPiano (endingHarmony:+:finalHarmony)

mid = line $ tension ++ [wnr] ++ (prefix ++ tail middle ++ [f 4 hn, g 4 wn, b 4 hn]) ++ keening ++ [wnr]
midSection = cello mid :=: grandPiano (endingHarmony2:+:endingHarmony2:+:endingHarmony2)

finalLine = line $ prefix ++ tail middle ++ [e 4 hn, b 3 wn, c 4 (4/4)]
finalHarmony = (line $ map (chord . forDur wn) $ [major(F, 4), minor(A, 4), major (C, 4), major (F, 4)])
finalSection = cello finalLine :=: grandPiano endingHarmony2

song = openingSection :+: turnSection :+: midSection :+: turnSection :+: endSection :+: turnSection :+: finalSection



