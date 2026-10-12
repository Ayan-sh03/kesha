"""Art sets: every painted asset in Dwaar, with its prompt."""

ISO = ("isolated on a plain flat pure white background, entire subject visible with margin, no ground, no cast shadow, "
       "hand-painted 2D video game asset, painterly brushwork, highly detailed, rich texture, "
       "lit by warm oil-lamp light from the lower left and cool indigo moonlight from the upper right, rim light, no text")

CHAR = ("full body, side profile view facing right, standing straight, arms relaxed and slightly apart from the body, legs slightly apart, "
        "isolated on a plain flat pure white background, hand-painted 2D video game character art, painterly, highly detailed, "
        "soft warm lamplight from the left, cool rim light, no text")


def dry_ghat():
    A = "assets/art/dry_ghat/"
    return [
        {"out": A + "sky.png", "ultra": True, "aspect": "21:9", "seed": 11,
         "prompt": "extremely wide panoramic night sky over a flat dry Indian plain, enormous low pale moon on the right with a soft halo, thin dust haze bands glowing in the moonlight, faint stars, deep indigo zenith fading to dusty violet and ash rose at the horizon, the flat horizon line very low, almost no land"},
        {"out": A + "far_bank.png", "ultra": True, "aspect": "21:9", "seed": 12,
         "prompt": "extremely wide panorama at night, the far bank of a dead dry river in rural India seen across a cracked riverbed, a long low silhouette of ancient brick ghat steps, small domed chhatri pavilions, cold dome kilns, mud houses, a few tiny warm lamp lights, enormous pale moon low in an indigo sky with dust haze, atmospheric perspective, misty, quiet and ominous"},
        {"out": A + "src/chhatri.png", "cutout": A + "chhatri.png", "aspect": "3:4", "seed": 21,
         "prompt": "an old weathered red-brick and lime-plaster chhatri pavilion with a small white dome on four pillars, a clay oil lamp burning inside, cracked plaster, " + ISO, "style": False},
        {"out": A + "src/house1.png", "cutout": A + "house1.png", "aspect": "4:3", "seed": 22,
         "prompt": "a single-storey lime-washed mud house of a potters' village in rural India with a clay-tile roof, a low wooden-free doorway, beside the threshold a wall niche of five tiny clay doors each with a small brass bell, drying clay pots stacked against the wall, cracked whitewash revealing red earth, " + ISO, "style": False},
        {"out": A + "src/house2.png", "cutout": A + "house2.png", "aspect": "4:3", "seed": 23,
         "prompt": "two joined flat-roofed mud and brick houses of a potters' village in rural India, lime-washed walls stained with red earth, a lit window glowing warm orange, rows of clay water pots drying on the parapet, " + ISO, "style": False},
        {"out": A + "src/kiln.png", "cutout": A + "kiln.png", "aspect": "1:1", "seed": 24,
         "prompt": "a large cold traditional potter's dome kiln made of clay and brick, soot-blackened arched firing mouth, ash heap and broken shards at its base, thin smoke rising, " + ISO, "style": False},
        {"out": A + "src/pots.png", "cutout": A + "pots.png", "aspect": "3:2", "seed": 25,
         "prompt": "a stacked pyramid of unglazed terracotta matka water pots and surahi pitchers drying, red earthenware with white slip bands, some cracked, " + ISO, "style": False},
        {"out": A + "src/crowd1.png", "cutout": A + "crowd1.png", "aspect": "16:9", "seed": 31,
         "prompt": "a group of eight rural Indian villagers, men in white dhotis and turbans and women in colourful saris with veils, standing motionless in prayer with eyes shut and fingers pressed in their ears, lips pressed shut, some holding small burning clay oil lamps, eerie and silent, three-quarter view, " + ISO, "style": False},
        {"out": A + "src/crowd2.png", "cutout": A + "crowd2.png", "aspect": "16:9", "seed": 32,
         "prompt": "a group of six rural Indian village women and children in faded saris and odhnis standing very still in silent prayer, eyes closed, holding small burning clay diyas in cupped hands, faces lit warm from below, eerie, three-quarter view, " + ISO, "style": False},
        {"out": A + "src/elders.png", "cutout": A + "elders.png", "aspect": "16:9", "seed": 33,
         "prompt": "five stern old Indian village elders in white kurtas, white dhotis and white turbans with white beards, kneeling in a half circle around a small clay boat, pressing wet river clay with their fingers, solemn, three-quarter view, " + ISO, "style": False},
        {"out": A + "src/boat.png", "cutout": A + "boat.png", "aspect": "16:9", "seed": 34,
         "prompt": "a small shallow boat made of red terracotta clay, inside it lies a 12-year-old Indian girl in a dark red skirt and blouse, her eyes, ears, lips, nostrils and palms sealed with grey river clay, a single small clay oil lamp burning at her feet, side view, " + ISO, "style": False},
        {"out": A + "src/baba.png", "cutout": A + "baba.png", "aspect": "3:4", "seed": 35,
         "prompt": "a broad-shouldered Indian village potter in his forties, bare-chested with a white dhoti, clay-stained arms, standing with eyes shut and head bowed in grief, " + CHAR, "style": False},
        {"out": "assets/art/chars/src/tesu.png", "cutout": "assets/art/chars/tesu_full.png", "aspect": "2:3", "seed": 41,
         "prompt": "Tesu, a thin 12-year-old Indian village boy with dark brown skin, big dark eyes and messy black hair, wearing a faded orange kurta the colour of tesu flowers and a short white dhoti, a red thread tied on his wrist, barefoot, a small wooden pot-paddle strapped across his back, a slingshot tucked into his waistband, " + CHAR, "style": False},
    ]


def dry_ghat2():
    A = "assets/art/dry_ghat/"
    return [
        {"out": A + "far_bank2.png", "ultra": True, "aspect": "21:9", "seed": 13,
         "prompt": "richly detailed oil painting, extremely wide panorama at night: across a vast dead cracked riverbed, the far bank of an ancient Indian river town, long flights of crumbling red-brick ghat steps, white domed chhatri pavilions, dome kilns, terraced mud houses with a few warm lamp-lit windows, silhouettes of motionless people holding tiny lamps on the steps, an enormous pale moon low in a deep indigo sky with luminous dust haze, atmospheric perspective, painterly, cinematic, melancholy"},
        {"out": A + "src/fg_pots.png", "cutout": A + "fg_pots.png", "aspect": "16:9", "seed": 51, "style": False,
         "prompt": "a long low row of large dark clay water pots, stacked bricks, coiled ropes and a broken clay cart wheel, almost black silhouettes with a thin warm rim light, isolated on a plain flat pure white background, hand-painted 2D video game foreground asset, painterly"},
        {"out": A + "src/mouth.png", "cutout": A + "mouth.png", "aspect": "16:9", "seed": 52, "style": False,
         "prompt": "a gaping round sinkhole torn open in a cracked dry riverbed, jagged crumbling clay edges, a bottomless black abyss inside with a faint indigo glow far below, seen from the side and slightly above, isolated on a plain flat pure white background, hand-painted 2D video game asset, painterly, ominous"},
        {"out": A + "src/lamps.png", "cutout": A + "lamps.png", "aspect": "16:9", "seed": 53, "style": False,
         "prompt": "a long row of dozens of small burning clay oil lamps diyas on old brick steps, warm flickering flames, isolated on a plain flat pure white background, hand-painted 2D video game asset, painterly"},
    ]
