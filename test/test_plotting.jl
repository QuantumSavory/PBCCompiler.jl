@testitem "plotting" tags=[:plotting] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PauliConditional, BitConditional, circuitplot, circuitplot!, circuitplot_axis
using QuantumClifford: @P_str
using CairoMakie

@testset "Empty circuit" begin
    # Empty circuits don't have content to plot, but the function should not error
    circuit = Circuit()
    fig = Figure()
    # For empty circuits, we create the axis but don't plot anything
    # This verifies the function handles the edge case without erroring
    @test circuitplot_axis(fig[1, 1], circuit) isa Tuple
end

@testset "Single Pauli gate" begin
    circuit = Circuit([Pauli(P"X", [1])])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_single_pauli.png", fig)
    @test isfile("test_single_pauli.png")
    rm("test_single_pauli.png")
end

@testset "Multi-qubit Pauli gate" begin
    circuit = Circuit([Pauli(P"XYZ", [1, 2, 3])])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_multiqubit_pauli.png", fig)
    @test isfile("test_multiqubit_pauli.png")
    rm("test_multiqubit_pauli.png")
end

@testset "Measurement" begin
    circuit = Circuit([Measurement(P"Z", 0, [1])])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_measurement.png", fig)
    @test isfile("test_measurement.png")
    rm("test_measurement.png")
end

@testset "Rotation gates" begin
    circuit = Circuit([
        ExpHalfPiPauli(P"X", [1]),
        ExpQuatPiPauli(P"Y", [2]),
        ExpEighPiPauli(P"Z", [3])
    ])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_rotations.png", fig)
    @test isfile("test_rotations.png")
    rm("test_rotations.png")
end

@testset "PauliConditional" begin
    circuit = Circuit([PauliConditional(P"X", [1], P"Z", [2])])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_pauliconditional.png", fig)
    @test isfile("test_pauliconditional.png")
    rm("test_pauliconditional.png")
end

@testset "BitConditional" begin
    circuit = Circuit([
        Measurement(P"Z", 0, [1]),
        BitConditional(Pauli(P"X", [2]), 0)
    ])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_bitconditional.png", fig)
    @test isfile("test_bitconditional.png")
    rm("test_bitconditional.png")
end

@testset "Mixed circuit" begin
    circuit = Circuit([
        Pauli(P"X", [1]),
        ExpHalfPiPauli(P"Y", [2]),
        Measurement(P"ZZ", 0, [1, 2]),
        BitConditional(Pauli(P"X", [3]), 0),
        ExpQuatPiPauli(P"Z", [3])
    ])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_mixed_circuit.png", fig)
    @test isfile("test_mixed_circuit.png")
    rm("test_mixed_circuit.png")
end

@testset "Non-contiguous qubits" begin
    circuit = Circuit([
        Pauli(P"X", [1]),
        Pauli(P"Y", [5]),
        Pauli(P"Z", [10])
    ])
    fig = Figure()
    circuitplot_axis(fig[1, 1], circuit)
    save("test_noncontiguous.png", fig)
    @test isfile("test_noncontiguous.png")
    rm("test_noncontiguous.png")
end

@testset "Custom plot attributes" begin
    circuit = Circuit([
        Pauli(P"X", [1]),
        Measurement(P"Z", 0, [2])
    ])
    fig = Figure()
    ax = Axis(fig[1, 1])
    circuitplot!(ax, circuit;
        gatewidth=1.0,
        qubitspacing=2.0,
        paulicolor=:blue,
        measurementcolor=:red
    )
    save("test_custom_attrs.png", fig)
    @test isfile("test_custom_attrs.png")
    rm("test_custom_attrs.png")
end

end
