"""
Plotting scaffolding for circuit visualization.

The actual implementation is provided by the PBCCompilerMakieExt extension
when Makie is loaded.
"""

"""
    circuitplot(circuit::Circuit)
    circuitplot!(ax, circuit::Circuit)

Create a visual representation of a quantum circuit.

Requires the Makie package to be loaded. Each operation is drawn as a colored
rectangle spanning the qubits it affects. Measurements show the classical bit
index, and conditional operations show their dependency.

# Plot Attributes
- `gatewidth`: Width of gate rectangles (default: 0.8)
- `qubitspacing`: Vertical spacing between qubit lines (default: 1.0)
- `wirecolor`: Color of qubit wire lines (default: :black)
- `wirelinewidth`: Width of qubit wire lines (default: 1.0)

# Gate Colors (by variant)
- `paulicolor`: Color for Pauli gates
- `measurementcolor`: Color for measurements
- `exphalfpicolor`: Color for exp(i*pi/2*P) gates
- `expquatpicolor`: Color for exp(i*pi/4*P) gates
- `expeighpicolor`: Color for exp(i*pi/8*P) gates
- `conditionalcolor`: Color for PauliConditional gates
- `bitconditionalcolor`: Color for BitConditional gates
"""
function circuitplot end

function circuitplot! end

"""
    circuitplot_axis(subfig, circuit; kwargs...)

Create a complete Makie figure panel with a circuit plot and appropriate axis settings.

Returns a tuple of (subfig, axis, plot).
"""
function circuitplot_axis end
