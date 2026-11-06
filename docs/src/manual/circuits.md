# Circuits

```@meta
CurrentModule = PBCCompiler
```

!!! note "TODO"
    Explain how circuits are represented: qubit indexing, how a Pauli string pairs
    with its `qubits` vector, and the classical-bit convention for measurements.

A [`Circuit`](@ref) is a `Vector` of [`CircuitOp`](@ref) values. `CircuitOp` is an
algebraic data type with these variants:

| Variant | Meaning |
|---|---|
| `CircuitOp.Measurement` | Pauli product measurement, outcome stored in a classical bit |
| `CircuitOp.ExpHalfPiPauli` | ``\pi/2`` Pauli product rotation |
| `CircuitOp.ExpQuatPiPauli` | ``\pi/4`` Pauli product rotation (Clifford) |
| `CircuitOp.ExpEighPiPauli` | ``\pi/8`` Pauli product rotation (non-Clifford) |
| `CircuitOp.PauliConditional` | Pauli rotation controlled on a Pauli eigenspace |
| `CircuitOp.BitConditional` | Operation controlled on a classical bit |

!!! tip "Checking variants"
    Use `Moshi.Data.isa_variant(op, CircuitOp.Pauli)`, not `op isa CircuitOp.Pauli`.

## Querying circuits

!!! note "TODO"
    Add a short example of [`affectedqubits`](@ref).

## Measurement results

!!! note "TODO"
    Describe the three [`MeasurementResult`](@ref) variants (`ClassicalDetermRes`,
    `ClassicalRandomRes`, `QuantumRes`) and when each is produced.

See the [API reference](@ref) for the full docstrings.
