# API reference

```@meta
CurrentModule = PBCCompiler
```

Every documented name in PBCCompiler, grouped by source file. Nothing is exported
yet, so all of these are accessed as `PBCCompiler.<name>`.

```@index
Pages = ["api.md"]
```

## Circuit and result types

`CircuitOp` and `MeasurementResult` are algebraic data types (Moshi.jl `@data`).
Each one is a submodule holding one type per variant, so `@autodocs` doesn't see
them and they're listed explicitly here.

```@docs
CircuitOp
CircuitOp.Measurement
CircuitOp.Pauli
CircuitOp.ExpHalfPiPauli
CircuitOp.ExpQuatPiPauli
CircuitOp.ExpEighPiPauli
CircuitOp.PrepMagic
CircuitOp.PauliConditional
CircuitOp.BitConditional
MeasurementResult
MeasurementResult.ClassicalDetermRes
MeasurementResult.ClassicalRandomRes
MeasurementResult.QuantumRes
```

```@autodocs
Modules = [PBCCompiler]
Pages = ["type.jl"]
```

## Compilation

```@autodocs
Modules = [PBCCompiler]
Pages = ["logic.jl", "preprocess.jl"]
```

## Pair transformations and traversal

```@autodocs
Modules = [PBCCompiler]
Pages = ["traversal.jl", "pair_transformation.jl"]
```

## Measurement resolution

```@autodocs
Modules = [PBCCompiler]
Pages = ["joint_measurement_check.jl"]
```

## Circuit queries

```@autodocs
Modules = [PBCCompiler]
Pages = ["affectedqubits.jl", "random_circuit.jl"]
```

## File I/O

```@autodocs
Modules = [PBCCompiler]
Pages = ["io.jl"]
```

## Plotting

```@autodocs
Modules = [PBCCompiler]
Pages = ["plotting.jl"]
```
