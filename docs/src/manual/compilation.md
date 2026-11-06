# Compilation pipeline

```@meta
CurrentModule = PBCCompiler
```

[`preprocess_circuit`](@ref) turns a Clifford + ``T`` circuit into Pauli Product form
by running these passes in order, each of which rewrites the circuit in place:

1. [`remove_pauliconditional`](@ref): rewrite `PauliConditional` ops as Pauli rotations.
2. [`group_nonclifford`](@ref): commute non-Clifford rotations to the front.
3. [`merge_ops`](@ref): merge adjacent compatible rotations.
4. [`remove_clifford`](@ref): absorb Clifford rotations into the measurements.
5. [`remove_nonclifford`](@ref): replace non-Clifford rotations with magic-state gadgets.
6. [`remove_post_measurement`](@ref): drop operations after the last measurement.

!!! note "TODO"
    For each pass, add a before/after example (`@example` block) and explain the
    invariants it relies on and the ones it establishes.

## Pair transformations and traversal

Most passes come down to [`traversal`](@ref), which sweeps a circuit and applies a
*pair transformation* to each adjacent pair of operations. The pair transformation
can return a new pair, merge the two into one operation, or return `nothing` to
leave the pair unchanged.

The building blocks are [`check_commutation`](@ref), [`conjugate_noncliff`](@ref)
and [`conjugate_measurement`](@ref).

!!! note "TODO"
    Show how to write a custom pair transformation and run it with `traversal`.
