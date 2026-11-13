# Layout of the install window inside the disk image, for dmgbuild (used by scripts/make-dmg.sh).
# Icon positions are the icons' centres measured from the top-left of the area under the title bar;
# keep them in sync with background.swift.
app = defines.get("app", "build/Sift.app")  # noqa: F821 (dmgbuild provides `defines`)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = "Support/AppIcon.icns"
background = "Support/dmg-background.tiff"

# The size includes the title bar (about 28 points), so the area under it matches the 640 × 337 design.
window_rect = ((200, 140), (640, 365))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 112
text_size = 14
icon_locations = {
    "Sift.app": (175, 174),
    "Applications": (467, 174),
}
