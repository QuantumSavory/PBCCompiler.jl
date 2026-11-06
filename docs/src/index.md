# PBCCompiler.jl

```@meta
CurrentModule = PBCCompiler
DocTestSetup = quote
    using QuantumClifford, PBCCompiler
end
```

Tools for compiling gate-based quantum circuits into Pauli-Based Computation (PBC)
form and executing them against stabilizer-state backends.

!!! note "TODO"
    Write a short overview: what PBC is, what this package does, and who it is for.
    Cite the reference construction (Litinski, *A Game of Surface Codes*,
    [Quantum 3, 128 (2019)](https://quantum-journal.org/papers/q-2019-03-05-128/)).

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/QuantumSavory/PBCCompiler.jl")
```

## Quickstart

A circuit is a vector of [`CircuitOp`](@ref) operations. [`run`](@ref) preprocesses
a copy of it into Pauli Product form and then executes the measurements against a
runtime, returning the final [`CompilerState`](@ref).

```@example quickstart
using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, SimRuntime
using QuantumClifford: @P_str
using Random
Random.seed!(1)  # SimRuntime samples measurement outcomes; seed for reproducibility

circuit = Circuit([
    CircuitOp.PauliConditional(P"X", [1], P"Z", [2]),
    CircuitOp.ExpHalfPiPauli(P"YZ", [1, 2]),
    CircuitOp.ExpEighPiPauli(P"Z", [2]),
    CircuitOp.Measurement(P"Z", 1, [1]),
    CircuitOp.Measurement(P"Z", 2, [2]),
])

state = PBCCompiler.run(circuit, SimRuntime())
```

To see just the compiled circuit, apply [`preprocess_circuit`](@ref) yourself.
It rewrites its argument in place:

```@example quickstart
compiled = copy(circuit)
PBCCompiler.preprocess_circuit(compiled)
compiled
```

!!! note
    PBCCompiler does not export names yet. Qualify them (`PBCCompiler.run`) or import
    them explicitly (`using PBCCompiler: Circuit, CircuitOp`). Don't bring `run` into
    scope unqualified, because it would shadow `Base.run`.

## Where to go next

- [Circuits](@ref): the operation types a circuit is built from.
- [Compilation pipeline](@ref): what `preprocess_circuit` does, stage by stage.
- [Execution and runtimes](@ref): running a compiled circuit and interpreting measurement results.
- [Input and output](@ref): reading OpenQASM and saving results.
- [Visualization](@ref): plotting circuits with Makie.
- [API reference](@ref): every documented name, grouped by source file.

## Related packages

- [QuantumClifford.jl](https://github.com/QuantumSavory/QuantumClifford.jl): stabilizer formalism backend.
- [BPGates.jl](https://github.com/QuantumSavory/BPGates.jl): Bell-preserving gates.
