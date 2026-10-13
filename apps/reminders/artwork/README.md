# Reminders icon artwork

`AppIcon-source.png` is original artwork generated with the built-in imagegen tool. The composition was checked against the checklist icon on page 88 of Apple's [iPhone User Guide for iOS 6](https://cdsassets.apple.com/live/6GJYWVAV/user/ma1658_iphone_ios6_user_guide.pdf). Historical screenshots are reference material and are not shipped as app assets.

The source is kept separately from the asset catalog. `scripts/generate_resources.py` converts it to an opaque 1024-pixel app icon without changing its composition. iOS supplies the outer icon mask.

The generation prompt is recorded in [icon-prompt.txt](icon-prompt.txt). The generated source is intentionally retained so resource regeneration does not replace it with a schematic drawing.
