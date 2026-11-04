Every aimable node (debris, coin, bottle) must implement label_text(), set_highlight(on), pick_up(cam), refuse(); Player._update_target calls them without checks.
Why: the message bottle lacked label_text and crashed when aimed at.
How to apply: when adding a new aimable kind, add it to tools/tests/t11_test.gd. Sizes: model at real metres, one Catalog.VIS_SCALE for readability, Catalog.MIN_PICK_RADIUS keeps tiny items pickable.
