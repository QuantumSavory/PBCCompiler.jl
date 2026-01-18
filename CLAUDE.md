# PBCCompiler.jl

Tools for Pauli Based Computation (PBC), a modality of quantum computation.

## Project Structure

- `src/PBCCompiler.jl` - Main module with circuit operations and compiler infrastructure
- `src/traversal.jl` - Circuit traversal utilities for gate simplifications
- `src/affectedqubits.jl` - Query functions for qubit indices affected by operations
- `src/plotting.jl` - Plotting function stubs (scaffolding for extensions)
- `ext/PBCCompilerMakieExt/` - Makie extension for circuit visualization
- `test/` - Test suite using TestItemRunner.jl
- `benchmark/` - Performance benchmarks using BenchmarkTools.jl

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

### Circuit Traversal
The `traversal` function (`src/traversal.jl`) applies transformations to adjacent pairs of circuit operations:
```julia
traversal(circuit, pair_transformation, direction=:right, starting_index=1, end_index=:end)
```
- `pair_transformation(op1, op2)` returns:
  - `(new_op1, new_op2)` tuple to replace the pair
  - Single operation to combine the pair into one
  - `nothing` to keep unchanged
- Supports left-to-right (`:right`) or right-to-left (`:left`) traversal
- Used for gate commutation, simplification, and compilation passes

**Note on Moshi types**: Use `Moshi.Data.isa_variant(op, CircuitOp.Pauli)` instead of `op isa CircuitOp.Pauli` to check variant types.

### Affected Qubits
The `affectedqubits` function (`src/affectedqubits.jl`) returns the sorted list of qubit indices affected by an operation or circuit:
```julia
affectedqubits(op::CircuitOp.Type) -> Vector{Int}
affectedqubits(circuit::Circuit) -> Vector{Int}
```

### Circuit Visualization (Makie Extension)
When Makie is loaded, the `PBCCompilerMakieExt` extension provides circuit plotting:
```julia
using CairoMakie  # or GLMakie
using PBCCompiler

circuit = Circuit([...])
circuitplot(circuit)  # Create a plot
circuitplot!(ax, circuit)  # Add to existing axis
circuitplot_axis(fig[1,1], circuit)  # Create complete figure panel
```

**Plot features:**
- Gates shown as colored rectangles spanning affected qubits
- Horizontal qubit wire lines
- Measurement results marked with classical bit index (e.g., "c0")
- Conditional operations marked with dependency index (e.g., "?c0")
- PrepMagic gates not visualized (placeholder for future)

**Configurable attributes:**
- `gatewidth`, `qubitspacing` - Gate dimensions
- `wirecolor`, `wirelinewidth` - Wire appearance
- `paulicolor`, `measurementcolor`, etc. - Gate colors by variant

## Development

### Workflow
1. Always pull latest master: `git pull`
2. Create feature branches for new work
3. Commit often at each change
4. Update CLAUDE.md with new functionality
5. Run tests before creating PRs
6. Add benchmarks for new performance-critical functionality

### Docstring Guidelines
- Docstrings are for **users**, not developers
- Do not include implementation details (e.g., "uses pattern matching", "implemented via recursion")
- Focus on: what the function does, its arguments, return values, and usage examples
- Implementation notes belong in code comments, not docstrings

### Run tests
```bash
julia -tauto --project -e 'using Pkg; Pkg.test("PBCCompiler")'
```

### Benchmarks
Benchmarks are managed with BenchmarkTools.jl and run in CI via AirspeedVelocity.jl.

Run benchmarks locally:
```bash
julia -tauto --project=benchmark -e 'include("benchmark/benchmarks.jl"); run(SUITE)'
```

**When to add benchmarks:**
- New compilation passes or transformations
- New traversal operations
- Any function that processes circuits at scale
- Performance-critical code paths

**Benchmark file structure:**
- Add new benchmarks to `benchmark/benchmarks.jl`
- Use `evals=1` for functions that modify state in-place
- Use `setup=` to create fresh data for each evaluation
- Group related benchmarks using `BenchmarkGroup`

### Julia invocation
Always use the `-tauto` flag when launching Julia to utilize all available threads, which drastically speeds up compilation times:
```bash
julia -tauto --project
```

### Related source code
- QuantumClifford.jl source: `../QuantumClifford.jl`
- QuantumInterface.jl source: `../QuantumInterface.jl`

### Reference paper
- "Game of Surface Codes" - https://quantum-journal.org/papers/q-2019-03-05-128/pdf/

## Related Packages

- [QuantumClifford.jl](https://github.com/QuantumSavory/QuantumClifford.jl) - Stabilizer formalism
- [BPGates.jl](https://github.com/QuantumSavory/BPGates.jl) - Bell-preserving gates
