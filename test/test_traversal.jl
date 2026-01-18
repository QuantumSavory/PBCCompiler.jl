@testitem "Traversal" tags=[:traversal] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, traversal
using QuantumClifford: @P_str
using Moshi.Data: isa_variant

# Helper to create simple Pauli gates for testing
make_pauli(p, qubits) = Pauli(p, qubits)

# Helper to check if an operation is a Pauli variant (Moshi ADT compatible)
is_pauli(op) = isa_variant(op, CircuitOp.Pauli)

@testset "Basic traversal" begin
    # Test empty circuit
    circuit = Circuit()
    traversal(circuit, (a, b) -> nothing)
    @test isempty(circuit)

    # Test single-element circuit (no pairs to traverse)
    circuit = Circuit([make_pauli(P"X", [1])])
    traversal(circuit, (a, b) -> nothing)
    @test length(circuit) == 1
end

@testset "Swap transformation" begin
    # Simple swap: swap adjacent operations
    swap_transform(op1, op2) = (op2, op1)

    # Create circuit [X, Y, Z]
    circuit = Circuit([
        make_pauli(P"X", [1]),
        make_pauli(P"Y", [1]),
        make_pauli(P"Z", [1])
    ])

    # After traversal with swap:
    # Pair (X, Y) -> (Y, X): [Y, X, Z]
    # Pair (X, Z) -> (Z, X): [Y, Z, X]
    traversal(circuit, swap_transform)

    @test is_pauli(circuit[1])
    @test is_pauli(circuit[2])
    @test is_pauli(circuit[3])
    # Check that X has moved to the end (bubble sort behavior)
    @test circuit[1].pauli == P"Y"
    @test circuit[2].pauli == P"Z"
    @test circuit[3].pauli == P"X"
end

@testset "No-op transformation" begin
    # Transformation that returns nothing (no change)
    no_op(op1, op2) = nothing

    circuit = Circuit([
        make_pauli(P"X", [1]),
        make_pauli(P"Y", [1]),
        make_pauli(P"Z", [1])
    ])

    original_length = length(circuit)
    traversal(circuit, no_op)

    @test length(circuit) == original_length
    @test circuit[1].pauli == P"X"
    @test circuit[2].pauli == P"Y"
    @test circuit[3].pauli == P"Z"
end

@testset "Combining transformation" begin
    # Transformation that combines two operations into one
    # For testing, combine any two Paulis into a single X
    combine_paulis(op1, op2) = begin
        if is_pauli(op1) && is_pauli(op2)
            return make_pauli(P"X", [1])  # Combine into single X
        end
        return nothing
    end

    circuit = Circuit([
        make_pauli(P"X", [1]),
        make_pauli(P"Y", [1]),
        make_pauli(P"Z", [1])
    ])

    # After first combination: [X, Z] (X and Y combined into X)
    # After second combination: [X] (X and Z combined into X)
    traversal(circuit, combine_paulis)

    @test length(circuit) == 1
    @test is_pauli(circuit[1])
end

@testset "Left direction traversal" begin
    swap_transform(op1, op2) = (op2, op1)

    circuit = Circuit([
        make_pauli(P"X", [1]),
        make_pauli(P"Y", [1]),
        make_pauli(P"Z", [1])
    ])

    # With left direction, start from the right side
    # Pair (Y, Z) -> (Z, Y): [X, Z, Y]
    # Pair (X, Z) -> (Z, X): [Z, X, Y]
    traversal(circuit, swap_transform, :left)

    @test circuit[1].pauli == P"Z"
    @test circuit[2].pauli == P"X"
    @test circuit[3].pauli == P"Y"
end

@testset "Partial traversal with indices" begin
    swap_transform(op1, op2) = (op2, op1)

    circuit = Circuit([
        make_pauli(P"X", [1]),
        make_pauli(P"Y", [1]),
        make_pauli(P"Z", [1]),
        make_pauli(P"I", [1])
    ])

    # Only traverse from index 2 to 2 (pair at positions 2,3)
    traversal(circuit, swap_transform, :right, 2, 2)

    # Only Y and Z should be swapped
    @test circuit[1].pauli == P"X"
    @test circuit[2].pauli == P"Z"
    @test circuit[3].pauli == P"Y"
    @test circuit[4].pauli == P"I"
end

@testset "Conditional transformation" begin
    # Only swap if first operation is an X Pauli
    conditional_swap(op1, op2) = begin
        if is_pauli(op1) && op1.pauli == P"X"
            return (op2, op1)
        end
        return nothing
    end

    circuit = Circuit([
        make_pauli(P"X", [1]),
        make_pauli(P"Y", [1]),
        make_pauli(P"Z", [1])
    ])

    # Pair (X, Y): X is first, so swap -> [Y, X, Z]
    # Pair (X, Z): X is first, so swap -> [Y, Z, X]
    traversal(circuit, conditional_swap)

    @test circuit[1].pauli == P"Y"
    @test circuit[2].pauli == P"Z"
    @test circuit[3].pauli == P"X"
end

@testset "Invalid direction error" begin
    circuit = Circuit([make_pauli(P"X", [1]), make_pauli(P"Y", [1])])
    @test_throws ArgumentError traversal(circuit, (a,b) -> nothing, :invalid)
end

end
