# Del, the retired boxer (player hero)

**Idea.** Del ran the boxing gym on Mill Street for thirty years. The gangs have started leaning on the shops, so he's tied his hands up and gone out to sort it himself. He's older and slower than the street kids, but every punch lands like a brick.

**Gameplay role.** He replaces the built-in hero, Max, as the player character.
- The punch combo is his strength: jab 6, cross 7, hook 11 (Max has 5, 6 and 9). The hook reaches 2 px further.
- His kicks are the same as Max's: low kick 7, roundhouse 12.
- He's a bit slower (move speed 118 against Max's 126) and tougher (110 HP against 100).
- How he should feel: heavy hands and steady. He wins by landing punch combos, not by running around.

**Look.**
- Stocky older man with grey stubble and a grey flat cap.
- White sleeveless vest, dark grey tracksuit bottoms, black boxing boots.
- Hands wrapped in white tape, with no gloves.
- He should read as **white/pale** against the grey world and red enemies, the same rule the built-in hero follows.
- About 62 px tall in game, the same as the Biker. Side view, facing right.

**Animations.**
- Generated: idle (guard up), walk, punch (straight right), kick (roundhouse) and hurt.
- Optional, if credits allow: block and jump.
- The importer builds the rest from those: jab, cross and hook copy `punch`; low kick and air kick come from `kick`; the grab, throw and carry poses come from idle and walk.

**Open questions.**
- Should the jab, cross and hook eventually be three separate generated animations, not copies of one punch?
- Should Del get a different HUD portrait from the one the importer crops automatically?
