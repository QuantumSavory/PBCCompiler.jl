# Input and output

```@meta
CurrentModule = PBCCompiler
```

- [`parse_input`](@ref): read an OpenQASM 2.0 file into a [`Circuit`](@ref).
- [`save`](@ref): write a [`CompilerState`](@ref) to a `.jld2` file.
- [`random_test_circuit`](@ref): generate a random circuit, useful for testing and benchmarks.

!!! note "TODO"
    List the supported OpenQASM gate set, and add a round-trip example
    (`parse_input` → `run` → `save`).
