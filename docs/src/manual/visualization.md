# Visualization

```@meta
CurrentModule = PBCCompiler
```

Plotting is provided by a package extension that loads when a Makie backend is loaded:

```julia
using CairoMakie   # or GLMakie
using PBCCompiler
using PBCCompiler: circuitplot, circuitplot!, circuitplot_axis

fig = Figure()
circuitplot_axis(fig[1, 1], circuit)
fig
```

Each operation is drawn as a coloured rectangle spanning the qubits it affects.
Measurements are labelled with their classical bit (`c1`), and conditional operations
with the bit they depend on (`?c1`). See [`circuitplot`](@ref) for the configurable
attributes, and [`circuitplot_axis`](@ref).

!!! note "TODO"
    Add a rendered example. That needs CairoMakie in `docs/Project.toml`, with the
    extension module added to `modules` in `make.jl`.
