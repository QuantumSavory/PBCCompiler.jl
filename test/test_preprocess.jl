@testitem "Preprocess" tags=[:preprocess] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, ExpQuatPiPauli,ExpEighPiPauli, PauliConditional, BitConditional, preprocess_circuit
using QuantumClifford: @P_str
using Moshi.Derive: @derive

@derive CircuitOp[Eq, Show]

@testset "Basic Preprocess" begin
    # Test empty circuit
    circuit = Circuit()
    preprocess_circuit(circuit)
    @test isempty(circuit)

    # Test single-element circuit (no pairs to traverse)
    circuit = Circuit([Pauli(P"X", [1])])
    preprocess_circuit(circuit)
    @test length(circuit) == 1
end

@testset "Preprocess Correctness" begin
    circuit = Circuit([
    ExpQuatPiPauli(P"Z", [1]),
    ExpQuatPiPauli(P"X", [1]),
    ExpQuatPiPauli(P"Z", [1]),
    PauliConditional(P"Z", [1], P"X", [2]),
    ExpEighPiPauli(P"Z", [2]),
    Measurement(P"Z", 1, [1]),
    Measurement(P"Z", 2, [2])
    ])

    preprocess_circuit(circuit)

    @test circuit[1] == Measurement(P"XZZ", 3, [1, 2, 3])
    @test circuit[2] == Measurement(P"X", 4, [3])
    @test circuit[3] == BitConditional((ExpQuatPiPauli(P"XZ", [1, 2])), 3)
    @test circuit[4] == BitConditional((ExpHalfPiPauli(P"XZ", [1, 2])), 4)
    @test circuit[5] == Measurement(P"X_", 1, [1, 2])
    @test circuit[6] == Measurement(P"XZ", 2, [1, 2])
end

end
