module PBCCompilerMakieExt

using Makie
using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, affectedqubits
using Moshi.Match: @match

import PBCCompiler: circuitplot, circuitplot!, circuitplot_axis

# Define the recipe with attributes
Makie.@recipe(CircuitPlot, circuit) do scene
    Makie.Theme(;
        # Gate dimensions
        gatewidth = 0.8,
        qubitspacing = 1.0,
        # Wire appearance
        wirecolor = :black,
        wirelinewidth = 1.0,
        # Gate colors by variant
        paulicolor = Makie.RGB(0.2, 0.6, 0.2),           # green
        measurementcolor = Makie.RGB(0.8, 0.2, 0.2),     # red
        exphalfpicolor = Makie.RGB(0.2, 0.4, 0.8),       # blue
        expquatpicolor = Makie.RGB(0.5, 0.2, 0.8),       # purple
        expeighpicolor = Makie.RGB(0.8, 0.4, 0.8),       # magenta
        conditionalcolor = Makie.RGB(0.8, 0.6, 0.2),     # orange
        bitconditionalcolor = Makie.RGB(0.6, 0.6, 0.6),  # gray
        # Text appearance
        fontsize = 10,
        textcolor = :white,
    )
end

"""Get the color for a CircuitOp variant."""
function gate_color(op::CircuitOp.Type, plot::CircuitPlot)
    @match op begin
        CircuitOp.Measurement(_, _, _) => plot.measurementcolor[]
        CircuitOp.Pauli(_, _) => plot.paulicolor[]
        CircuitOp.ExpHalfPiPauli(_, _) => plot.exphalfpicolor[]
        CircuitOp.ExpQuatPiPauli(_, _) => plot.expquatpicolor[]
        CircuitOp.ExpEighPiPauli(_, _) => plot.expeighpicolor[]
        CircuitOp.PrepMagic(_, _) => :transparent  # Not visualized
        CircuitOp.PauliConditional(_, _, _, _) => plot.conditionalcolor[]
        CircuitOp.BitConditional(_, _) => plot.bitconditionalcolor[]
    end
end

"""Get a short label for a CircuitOp variant."""
function gate_label(op::CircuitOp.Type)
    @match op begin
        CircuitOp.Measurement(_, _, _) => "M"
        CircuitOp.Pauli(_, _) => "P"
        CircuitOp.ExpHalfPiPauli(_, _) => "S"
        CircuitOp.ExpQuatPiPauli(_, _) => "T"
        CircuitOp.ExpEighPiPauli(_, _) => "R"
        CircuitOp.PrepMagic(_, _) => ""
        CircuitOp.PauliConditional(_, _, _, _) => "CP"
        CircuitOp.BitConditional(inner, _) => gate_label(inner)
    end
end

"""Check if an operation is a PrepMagic (not visualized for now)."""
function is_prepmagic(op::CircuitOp.Type)
    @match op begin
        CircuitOp.PrepMagic(_, _) => true
        _ => false
    end
end

"""Get the classical bit index for a Measurement, or nothing."""
function measurement_bit(op::CircuitOp.Type)
    @match op begin
        CircuitOp.Measurement(_, bit, _) => bit
        CircuitOp.BitConditional(inner, _) => measurement_bit(inner)
        _ => nothing
    end
end

"""Get the conditioning bit index for a BitConditional, or nothing."""
function conditioning_bit(op::CircuitOp.Type)
    @match op begin
        CircuitOp.BitConditional(_, bit) => bit
        _ => nothing
    end
end

function Makie.plot!(plot::CircuitPlot)
    circuit = plot[:circuit][]

    if isempty(circuit)
        return plot
    end

    # Get all qubits in the circuit
    all_qubits = affectedqubits(circuit)
    if isempty(all_qubits)
        return plot
    end

    min_qubit = minimum(all_qubits)
    max_qubit = maximum(all_qubits)

    gw = plot.gatewidth[]
    qs = plot.qubitspacing[]

    # Draw qubit wires (horizontal lines)
    for q in min_qubit:max_qubit
        y = q * qs
        # Wire extends from before first gate to after last gate
        Makie.lines!(plot, [0.5, length(circuit) + 0.5], [y, y];
            color = plot.wirecolor[],
            linewidth = plot.wirelinewidth[]
        )
    end

    # Draw each gate
    for (idx, op) in enumerate(circuit)
        # Skip PrepMagic for now
        if is_prepmagic(op)
            continue
        end

        qubits = affectedqubits(op)
        if isempty(qubits)
            continue
        end

        # Calculate rectangle bounds
        x_center = idx
        x_left = x_center - gw / 2
        x_right = x_center + gw / 2

        y_min = minimum(qubits) * qs
        y_max = maximum(qubits) * qs

        # Ensure minimum height for single-qubit gates
        if y_min == y_max
            y_min -= 0.3 * qs
            y_max += 0.3 * qs
        else
            # Add small padding
            y_min -= 0.1 * qs
            y_max += 0.1 * qs
        end

        # Draw rectangle
        color = gate_color(op, plot)
        Makie.poly!(plot,
            Makie.Point2f[(x_left, y_min), (x_right, y_min), (x_right, y_max), (x_left, y_max)];
            color = color,
            strokecolor = :black,
            strokewidth = 1
        )

        # Draw gate label in center
        label = gate_label(op)
        if !isempty(label)
            Makie.text!(plot, x_center, (y_min + y_max) / 2;
                text = label,
                align = (:center, :center),
                fontsize = plot.fontsize[],
                color = plot.textcolor[]
            )
        end

        # Draw measurement bit index (top-right corner)
        mbit = measurement_bit(op)
        if mbit !== nothing
            Makie.text!(plot, x_right - 0.05, y_max - 0.1;
                text = "c$mbit",
                align = (:right, :top),
                fontsize = plot.fontsize[] * 0.7,
                color = :black
            )
        end

        # Draw conditioning bit index (bottom-left corner)
        cbit = conditioning_bit(op)
        if cbit !== nothing
            Makie.text!(plot, x_left + 0.05, y_min + 0.1;
                text = "?c$cbit",
                align = (:left, :bottom),
                fontsize = plot.fontsize[] * 0.7,
                color = :black
            )
        end
    end

    return plot
end

"""
    circuitplot_axis(subfig, circuit; kwargs...)

Create a complete Makie figure panel with a circuit plot and appropriate axis settings.

Returns a tuple of (subfig, axis, plot).
"""
function circuitplot_axis(subfig, circuit::Circuit; kwargs...)
    ax = Makie.Axis(subfig[1, 1])
    p = circuitplot!(ax, circuit; kwargs...)

    # Configure axis
    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)
    ax.aspect = Makie.DataAspect()

    # Set axis limits with padding
    if !isempty(circuit)
        all_qubits = affectedqubits(circuit)
        if !isempty(all_qubits)
            min_q = minimum(all_qubits)
            max_q = maximum(all_qubits)
            Makie.xlims!(ax, 0, length(circuit) + 1)
            Makie.ylims!(ax, min_q - 0.5, max_q + 0.5)
        end
    end

    return (subfig, ax, p)
end

end # module
