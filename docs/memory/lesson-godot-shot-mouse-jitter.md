tools/shot occasionally comes out with a rotated/wrong camera because the captured mouse delivers a motion event at startup. If a shot looks wrong, just rerun it.
Why: Player reads relative mouse motion while the mouse is captured; the window may emit one on focus.
How to apply: for framed screenshots use `--pos=x,z,yaw,pitch` / `--pitch=` and check the image before trusting it. `--showcase` (items) and `--fill --sort-demo` (bins mid-sort) are the dev args behind .logs/catalog.png / bins.png.
