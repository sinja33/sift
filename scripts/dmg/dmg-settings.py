# Layout of the install window inside the disk image, for dmgbuild (used by scripts/make-dmg.sh).
# Icon positions are the icons' centres measured from the top-left; keep them in sync with background.swift.
app = defines.get("app", "build/Sift.app")  # noqa: F821 (dmgbuild provides `defines`)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = "Support/AppIcon.icns"
background = "Support/dmg-background.tiff"

window_rect = ((200, 140), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 112
text_size = 14
icon_locations = {
    "Sift.app": (175, 215),
    "Applications": (465, 215),
}
