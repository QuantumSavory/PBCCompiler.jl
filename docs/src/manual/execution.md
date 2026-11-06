# Execution and runtimes

```@meta
CurrentModule = PBCCompiler
```

[`run`](@ref) compiles a circuit and resolves its measurements one by one against a
runtime. The result is a [`CompilerState`](@ref), which holds the measurement results,
the classical register and the final stabilizer group.

## Runtimes

| Runtime | Behaviour |
|---|---|
| `SimRuntime` | Simulates the magic-state register, so quantum measurements are faithful |
| `DummyRuntime` | Replaces quantum measurements with biased coin flips (fast, not faithful) |

!!! note "TODO"
    Say when to use each runtime, and document `AbstractRuntime` as the extension
    point for new backends.

## Classifying measurements

Each measurement gets classified: classically determined by the stabilizer group,
classically random, or requiring a quantum measurement. See
[`get_measurement_result`](@ref) and [`MeasurementResult`](@ref).

!!! note "TODO"
    Walk through the quickstart result and explain each entry of
    `state.measurement_results`.
