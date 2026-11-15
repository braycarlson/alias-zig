# alias-zig

A weighted sampler for Zig, based on the alias method of [Vose (1991)](https://doi.org/10.1109/32.92917). The library builds a table once from a set of weights, and each draw then takes constant time regardless of how many outcomes the table holds. The capacity is fixed at compile time and the table needs no allocator. The library is useful when a program draws from one distribution many times.
