# dmgbuild settings. Paths arrive through -D defines from scripts/make_dmg.sh.
# Icon positions are icon centres in a 640x400 window and match scripts/dmg/background.swift.
import os.path
import unicodedata

app = defines["app"]  # noqa: F821 - injected by dmgbuild
notes = defines["notes"]  # noqa: F821

filesystem = "HFS+"
format = "UDZO"
files = [app, notes]
symlinks = {"Applications": "/Applications"}

background = defines["background"]  # noqa: F821
# Height adds the title bar so the 640x400 content area matches the background.
window_rect = ((200, 140), (640, 428))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 96
text_size = 13
# HFS+ stores names decomposed (NFD); Finder ignores positions whose name does not match byte for byte.
icon_locations = {
    unicodedata.normalize("NFD", name): position
    for name, position in {
        os.path.basename(app): (160, 175),
        "Applications": (480, 175),
        os.path.basename(notes): (320, 305),
    }.items()
}
