@testitem "affectedqubits" tags=[:affectedqubits] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PrepMagic, PauliConditional, BitConditional, affectedqubits
using QuantumClifford: @P_str

@testset "Single operation qubits" begin
    # Pauli gate
    op = Pauli(P"X", [1])
    @test affectedqubits(op) == [1]

    op = Pauli(P"XY", [1, 3])
    @test affectedqubits(op) == [1, 3]

    # Measurement
    op = Measurement(P"Z", 0, [2])
    @test affectedqubits(op) == [2]

    op = Measurement(P"ZZ", 1, [1, 4])
    @test affectedqubits(op) == [1, 4]

    # ExpHalfPiPauli
    op = ExpHalfPiPauli(P"Y", [3])
    @test affectedqubits(op) == [3]

    # ExpQuatPiPauli
    op = ExpQuatPiPauli(P"X", [2])
    @test affectedqubits(op) == [2]

    # ExpEighPiPauli
    op = ExpEighPiPauli(P"Z", [5])
    @test affectedqubits(op) == [5]
end

@testset "PrepMagic qubits" begin
    # PrepMagic has a single qubit and additional qubits
    op = PrepMagic(1, [2, 3])
    @test affectedqubits(op) == [1, 2, 3]

    op = PrepMagic(5, Int[])
    @test affectedqubits(op) == [5]
end

@testset "PauliConditional qubits" begin
    # PauliConditional has control and target qubits
    op = PauliConditional(P"X", [1], P"Z", [2])
    @test affectedqubits(op) == [1, 2]

    op = PauliConditional(P"XX", [1, 2], P"ZZ", [3, 4])
    @test affectedqubits(op) == [1, 2, 3, 4]

    # Overlapping qubits should be deduplicated
    op = PauliConditional(P"X", [1], P"Z", [1])
    @test affectedqubits(op) == [1]
end

@testset "BitConditional qubits" begin
    # BitConditional wraps another operation
    inner = Pauli(P"XY", [2, 3])
    op = BitConditional(inner, 0)
    @test affectedqubits(op) == [2, 3]

    inner = Measurement(P"Z", 1, [5])
    op = BitConditional(inner, 0)
    @test affectedqubits(op) == [5]
end

@testset "Circuit qubits" begin
    # Empty circuit
    circuit = Circuit()
    @test affectedqubits(circuit) == Int[]

    # Single operation circuit
    circuit = Circuit([Pauli(P"X", [1])])
    @test affectedqubits(circuit) == [1]

    # Multiple operations
    circuit = Circuit([
        Pauli(P"X", [1]),
        Measurement(P"Z", 0, [2]),
        ExpHalfPiPauli(P"Y", [3])
    ])
    @test affectedqubits(circuit) == [1, 2, 3]

    # Operations with overlapping qubits
    circuit = Circuit([
        Pauli(P"XX", [1, 2]),
        Pauli(P"YY", [2, 3])
    ])
    @test affectedqubits(circuit) == [1, 2, 3]

    # Non-contiguous qubits
    circuit = Circuit([
        Pauli(P"X", [1]),
        Pauli(P"Z", [5]),
        Pauli(P"Y", [3])
    ])
    @test affectedqubits(circuit) == [1, 3, 5]
end

end
