# PBCCompiler.jl

```@meta
DocTestSetup = quote
    using QuantumClifford, PBCCompiler
end
```

Tools for Pauli Based Computation (PBC), a modality of quantum computation.

## Overview

PBCCompiler.jl provides infrastructure for compiling and executing Pauli-based quantum circuits. The package includes:

- **Circuit Operations** - Algebraic data types for representing quantum operations
- **Compilation Pipeline** - Transform circuits through optimization stages
- **Runtime System** - Execute circuits on quantum backends

## Circuit Operations

The `CircuitOp` type represents quantum operations:

- `Measurement` - Pauli measurement with classical bit output
- `Pauli` - Pauli gate application
- `ExpHalfPiPauli`, `ExpQuatPiPauli`, `ExpEighPiPauli` - Rotation gates
- `PrepMagic` - Magic state preparation
- `PauliConditional` - Pauli gate conditioned on another Pauli
- `BitConditional` - Operation conditioned on classical bit

## Related Packages

- [QuantumClifford.jl](https://github.com/QuantumSavory/QuantumClifford.jl) - Stabilizer formalism
- [BPGates.jl](https://github.com/QuantumSavory/BPGates.jl) - Bell-preserving gates
