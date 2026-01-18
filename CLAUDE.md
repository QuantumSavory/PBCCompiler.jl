# PBCCompiler.jl

Tools for Pauli Based Computation (PBC), a modality of quantum computation.

## Project Structure

- `src/PBCCompiler.jl` - Main module with circuit operations and compiler infrastructure
- `test/` - Test suite using TestItemRunner.jl

## Dependencies

- **Moshi.jl** - Algebraic data types via `@data` macro
- **QuantumClifford.jl** - Pauli operators and stabilizer formalism

## Key Concepts

### Circuit Operations (`CircuitOp`)
Algebraic data type representing quantum circuit operations:
- `Measurement` - Pauli measurement with classical bit output
- `Pauli` - Pauli gate application
- `ExpHalfPiPauli`, `ExpQuatPiPauli`, `ExpEighPiPauli` - Rotation gates (pi/2, pi/4, pi/8)
- `PrepMagic` - Magic state preparation
- `PauliConditional` - Pauli gate conditioned on another Pauli
- `BitConditional` - Operation conditioned on classical bit

### Compilation Pipeline
The `preprocess_circuit` function transforms circuits through stages:
1. Remove Pauli conditionals
2. Commute non-Clifford gates to front
3. Group non-Clifford operations
4. Commute measurements to end
5. Remove non-Clifford gates (introduce magic states)
6. Remove post-measurement operations

### Runtime
- `QuantumRuntime` - Abstract type for quantum execution backends
- `MockRuntime` - Testing runtime where measurements return deterministic results
- `ComputerState` - Tracks circuit, instruction pointer, and memory state

## Development

Run tests:
```julia
using Pkg
Pkg.test("PBCCompiler")
```

## Related Packages

- [QuantumClifford.jl](https://github.com/QuantumSavory/QuantumClifford.jl) - Stabilizer formalism
- [BPGates.jl](https://github.com/QuantumSavory/BPGates.jl) - Bell-preserving gates
