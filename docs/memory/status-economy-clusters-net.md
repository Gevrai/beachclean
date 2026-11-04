Economy after clusters/floaters/net: ~835 pieces (about 150 float, 110 of them beyond waist-deep reach = net only), upgrade base costs in cents bag 200 / arms 300 / grabber 480 / sandals 240 / rake 600 / net 1200, COST_GROWTH 1.5 (net max 3 levels: range 12/18/22 m, radius 2/3/4 m).
tune_sim estimate (reasonable player): first upgrade ~1.2 min, net bought ~8 min, 25% 5.7, 50% 9.2, 75% 13.5, 100% ~18.3 min (17.3 fast aim, 20.0 slow aim).
Why: 2.5x more pieces made the old costs (x1.6) give ~24 min; cheaper bases/growth bring it back to 15-20 min.
How to apply: re-run `godot --headless --path . res://tools/tests/tune_sim.tscn -- --fresh [--n= --far= --aim= --cost=]` after changing counts, costs or item values (keep the sim's N/FAR in step with DebrisManager).
