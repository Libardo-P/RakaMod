# RakaMod media credits

Every file under `Media/` that RakaMod ships, with author and licence. "Unknown" means
the author or licence could not be verified from the file itself or from the repository
history; those assets are kept at the maintainer's request and should be replaced or
cleared before the repository is made public or redistributed.

All assets are registered by RakaMod itself (vendored LibSharedMedia-3.0) under names
starting with `Rk `. No shared-media addon is required.

## Fonts (`Media/font/`)

Author and licence for fonts are read from each font's embedded name table.

| File | Registered as | Author | Licence | Status |
| --- | --- | --- | --- | --- |
| `RakaMod.ttf` | `Rk RakaMod` | The Inter Project Authors (Rasmus Andersson), https://github.com/rsms/inter | SIL OFL 1.1, see `Media/licenses/OFL-Inter.txt` | OK |
| `Montserrat-Black.ttf`, `Montserrat-Bold.ttf`, `Montserrat-Medium.ttf` | `Rk Montserrat Black` / `Bold` / `Medium` | The Montserrat Project Authors (Julieta Ulanovsky), https://github.com/JulietaUla/Montserrat | SIL OFL 1.1 (http://scripts.sil.org/OFL; the OFL text in `Media/licenses/OFL-Inter.txt` is the same licence) | OK; the project's copyright line should accompany redistribution |
| `Roboto Condensed.ttf` | `Rk Roboto Condensed` | Google Inc. | Apache License 2.0, http://www.apache.org/licenses/LICENSE-2.0 | OK; keep this notice |
| `BigNoodleToo.ttf` | `Rk BigNoodleToo` | James Arboghast / Sentinel Type | Font metadata says: "authorized for use by Sentinel Type licensees of Blizzard Entertainment Inc, only & may not be copied or distributed" | **Restricted, not redistributable.** Remove before any public release |
| `Doris PP.ttf` | `Rk Doris PP` | Ares Software Corp. (1993) | Commercial, all rights reserved; no redistribution terms found | **Unknown / likely not redistributable** |
| `ToxiUI.ttf` | `Rk ToxiUI` | ToxiUI (Tomas Leonavicius) | Unknown (copyright 2023 ToxiUI) | **Unknown** |
| `ToxiUIIcons.ttf` | `Rk ToxiUI Icons` | ToxiUI Team | Unknown (copyright 2023 ToxiUI Team) | **Unknown** |

## Status bar textures (`Media/statusbar/`)

None of these files carry author or licence metadata. They were added in the "Rk media
pack" commit (`8e0fd0a`) without source notes.

| File | Registered as | Author | Licence |
| --- | --- | --- | --- |
| `Arrow.tga` | `Rk Arrow` | Unknown | Unknown |
| `BuiOnePixel.tga` | `Rk Bui One Pixel` | Unknown (name suggests ElvUI BenikUI) | Unknown |
| `KMT47.tga` | `Rk KMT47` | Unknown | Unknown |
| `Resting.tga` | `Rk Resting` | Unknown | Unknown |
| `Rupture.tga` | `Rk Rupture` | Unknown | Unknown |
| `ToxiUI-clean.tga` | `Rk ToxiUI Clean` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-dark.tga` | `Rk ToxiUI Dark` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-fade.blp` | `Rk ToxiUI Fade` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-g1.tga` | `Rk ToxiUI G1` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-g2.tga` | `Rk ToxiUI G2` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-grad.tga` | `Rk ToxiUI Grad` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-half.tga` | `Rk ToxiUI Half` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-half-transparent.blp` | `Rk ToxiUI Half Transparent` | Unknown (name suggests ToxiUI) | Unknown |
| `ToxiUI-half-transparent-stroke.blp` | `Rk ToxiUI Half Transparent Stroke` | Unknown (name suggests ToxiUI) | Unknown |
| `TX-WorldState-Score.blp` | `Rk TX WorldState Score` | Unknown (name suggests Blizzard UI art) | Unknown |

## Backgrounds and class art (`Media/background/`, `Media/class/`)

| File | Registered as | Author | Licence |
| --- | --- | --- | --- |
| `background/grain.tga` | `Rk Grain` | Unknown | Unknown |
| `class/fabled.tga` | `Rk Class Fabled` | Unknown (name suggests ToxiUI) | Unknown |
| `class/fabledclass.tga` | `Rk Class Fabled Class` | Unknown | Unknown |
| `class/fabledcore.tga` | `Rk Class Fabled Core` | Unknown | Unknown |
| `class/fableddimension.tga` | `Rk Class Fabled Dimension` | Unknown | Unknown |
| `class/fabledmyth.tga` | `Rk Class Fabled Myth` | Unknown | Unknown |
| `class/fabledpixels.tga` | `Rk Class Fabled Pixels` | Unknown | Unknown |
| `class/fabledpixelsv2.tga` | `Rk Class Fabled Pixels V2` | Unknown | Unknown |
| `class/fabledrealm.tga` | `Rk Class Fabled Realm` | Unknown | Unknown |
| `class/fabledrealmv2.tga` | `Rk Class Fabled Realm V2` | Unknown | Unknown |
| `class/intothevoid.tga` | `Rk Class Into The Void` | Unknown | Unknown |

## Portrait shapes (`Media/portraits/`)

60 circle and droplet shapes and masks (`circle*`, `circle-thin*`, `droplet*`,
`droplet-thin*`, `droplet-left*`, in sizes 32 to 512), registered as `Rk Portrait <file>`.
Author: Unknown. Licence: Unknown.

## RakaMod-only art

| File | Author | Licence |
| --- | --- | --- |
| `icon.tga` (crest icon) | Raka | All rights reserved (see `LICENSE.txt`) |
| `colorwheel.tga` (colour picker underlay) | Unknown (generated for this addon; source not recorded) | Unknown |
| `ui/nav-*.tga` (settings window nav icons) | Raka, drawn with `tools/make_nav_icons.py` | All rights reserved (see `LICENSE.txt`) |

## Bundled libraries (`Libs/`)

LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDBIcon-1.0 and LibDataBroker-1.1 are
third-party libraries kept unmodified under their own licences (public domain / BSD /
LGPL, see each file header).
