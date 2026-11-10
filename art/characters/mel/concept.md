# Mel, the ex-copper (player hero, built side by side with Del)

**Idea.** Mel walked the Mill Street beat for twenty years and retired the week the gangs moved in. No warrant card any more, but the training is still there: control holds, short hard strikes and throws. Mel doesn't brawl. Mel arrests people, roughly.

**Gameplay role.** A grappler. Slower and tougher than Del, with a heavy slam.
- Stats: speed 112 (Del 118, Max 126); HP 120 (Del 110, Max 100).
- Brawler combo: palm strike (`punch_1`), elbow (`punch_2`), knee (`kick_1`), uppercut finisher (`punch_3`).
- `slam`: the strongest throw in the game (the over-the-shoulder finisher).
- `dash_attack`: a sliding tackle.
- `special`: a spinning clothesline.
- `super`: a big two-handed ground slam.
- `flying_kick`: a running jump kick.

**Look.**
- Weathered ex-police officer.
- Long **navy** coat with silver buttons, flat cap, **white gloves**, dark trousers, polished boots.
- The white gloves and silver trim make Mel easy to spot among the red and black enemies on the purple street. The flat cap is navy, not grey, so the silhouette differs from Del's.
- Style: detailed 32-bit pixel art, side view (slightly turned toward the viewer), about 62 px tall, standing in a ready stance with the hands up.

**Animations.**
- Generated: idle, walk, run, jump, punch, kick, uppercut, slam, flying_kick, dash_attack, special, super, hurt, knockdown, getup and win.
- `punch_1` and `punch_2` are cut from the one generated punch.
- `win` is only stored in the sheet; nothing plays it yet.
- Block, dodge and taunt use the game's fallbacks (defend, defend with afterimages, idle).

**Open questions.**
- A character select screen, so you can choose between Del and Mel in the game.
- Whether to add a "level clear" pose that plays `win`.
