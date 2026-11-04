Tween.tween_method(callable.bind(x), from, to, t) calls callable(value, x): the tweened value comes FIRST, bound args are appended.
Why: Callable.bind appends args after call args; wrong order is a parse/type error.
How to apply: declare `func f(v: float, id: String)`. Also, for animals placed in world coords under an origin node, scale each animal (not the group root) when fading in, or they slide toward the origin.
