# Assets, characters and names

The MIT license in [LICENSE](LICENSE) covers this repository's **code
only**. This file covers everything else.

## Touhou Project

Touhou Project (東方Project) and its characters, places, music and
artwork are the work of ZUN / Team Shanghai Alice. This is an unofficial,
non-commercial fan work made under
[Team Shanghai Alice's guidelines for fan works](https://touhou-project.news/guidelines_en/).
It is not made, endorsed or supported by ZUN, Team Shanghai Alice or the
Shady project.

The rice uses names of places from the games (博麗神社, 紅魔館, …) as
workspace names, the games' vocabulary (spell cards, Player, Bomb, Graze,
point and power items) and the look of their side panel. It contains **no
artwork, sprites, music or text taken from the games**: the shrine, the
sky, the magic circles, the bullets and the items are drawn by code
(`shaders/`, `plugins/shaders/`) and are MIT licensed like the rest of the
code. Nothing in this repository grants rights to the characters or to
anything else of Touhou Project. Use it for non-commercial purposes only;
if you fork or redistribute it, the same guidelines apply to you.

## Pictures and video

No picture ships with the rice. `tools/portrait.sh` puts **your own**
picture in the side panel; it is stored outside this repository, in
`~/.local/share/shady/touhou/`, and never added to it. Official artwork and
fan art found online may not be added to this repository; only pictures
whose author has agreed to share them here may be, listed below with their
author, source and terms:

| File | Author | Source | Terms |
|---|---|---|---|
| *(none)* | | | |

Bad Apple!! (Super+A) plays from your own copy of the video, turned into
frames by Shady's `tools/bad-apple.sh`. No frames, audio or video ship with
the rice or with Shady.

The screenshots in `docs/` were taken with the rice's stand-in apps and
without a panel picture (`capture.sh`).

## Fonts

`fonts/` holds subsets of two typefaces under the
[SIL Open Font License 1.1](https://openfontlicense.org), each with its
license beside it: Shippori Mincho B1 (© 2021 The Shippori Mincho Project
Authors; `fonts/OFL-ShipporiMinchoB1.txt`), cut down to Latin, kana and the
JIS level 1 kanji, and Zen Kaku Gothic New (© 2022 The Zen Kaku Gothic
Project Authors; `fonts/OFL-ZenKakuGothicNew.txt`). Neither declares a
Reserved Font Name, so the subsets keep their names.
