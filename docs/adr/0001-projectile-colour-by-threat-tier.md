# Projectile colour encodes threat tier, not shooter identity

Enemy projectiles are coloured by **how the player must dodge them** (straight = blue, aimed = orange, pattern = purple), not by which enemy fired them. Player shots are yellow/white so ownership is never ambiguous.

We picked this over colour-by-ownership (under-uses the 3-colour asset palette and gives the player no dodging cue) and sprite-by-shooter (poor readability on a 540×960 mobile screen at speed, and forces new art for every new enemy). Threat-tier colouring scales for free: classifying a new enemy's bullet pattern is the design work; the sprite is already drawn.

Consequence: when adding a new enemy, decide its projectile's tier before wiring its scene. The pattern tier is boss-gated — using purple on a grunt would teach the player the wrong lesson.
