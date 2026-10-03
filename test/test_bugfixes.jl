@testitem "Bugfix regressions" tags=[:bugfixes] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Pauli, Measurement, ExpHalfPiPauli, ExpQuatPiPauli,
    ExpEighPiPauli, PauliConditional, BitConditional, traversal, preprocess_circuit,
    validate_CircuitOp, PauliQubitMismatchError, find_variant_indices, group_nonclifford,
    quantum_measurement, resolve_conditionals,
    run, CompilerState, MeasurementResult,
    SimRuntime, DummyRuntime
using .MeasurementResult: ClassicalDetermRes
using QuantumClifford: @P_str, @S_str
using Moshi.Derive: @derive
using Moshi.Match: isa_variant

@derive CircuitOp[Eq, Show]

@testset "traversal with end_index left of start is a no-op" begin
    circuit = Circuit([Pauli(P"X", [1]), Pauli(P"Y", [1]), Pauli(P"Z", [1])])
    snapshot = copy(circuit)
    traversal(circuit, (a, b) -> (b, a), :left, 1, 0)
    @test circuit == snapshot
    traversal(circuit, (a, b) -> (b, a), :right, 2, 1)
    @test circuit == snapshot
end

@testset "group_nonclifford with a non-Clifford at index 1" begin
    e1 = ExpEighPiPauli(P"Z", [1])
    c  = ExpQuatPiPauli(P"X", [1])
    e2 = ExpEighPiPauli(P"Z", [1])
    circuit = Circuit([e1, c, e2])
    group_nonclifford(circuit)
    # e1 has nothing to its left and must stay put; e2 commutes past c (conjugated)
    @test circuit[1] == e1
    @test isa_variant(circuit[2], CircuitOp.ExpEighPiPauli)
    @test circuit[3] == c
end

@testset "traversal deletes both ops on empty-tuple result" begin
    cancel_all(op1, op2) = ()
    circuit = Circuit([Pauli(P"X", [1]), Pauli(P"Y", [1])])
    traversal(circuit, cancel_all, :right)
    @test isempty(circuit)
    # :left direction, deletion at the tail must not read out of bounds
    circuit = Circuit([Pauli(P"X", [1]), Pauli(P"Y", [1]), Pauli(P"Z", [1])])
    delete_yz(op1, op2) = (op1.pauli == P"Y" && op2.pauli == P"Z") ? () : nothing
    traversal(circuit, delete_yz, :left)
    @test length(circuit) == 1 && circuit[1].pauli == P"X"
end

@testset "inverse rotations cancel instead of leaving a placeholder" begin
    merge_ops = PBCCompiler.merge_ops
    # pi/8 followed by -pi/8 about the same axis is the identity
    circuit = Circuit([ExpEighPiPauli(P"Z", [1]), ExpEighPiPauli(-P"Z", [1])])
    merge_ops(circuit)
    @test isempty(circuit)
    # two pi/2 rotations about the same axis are a global phase
    circuit = Circuit([ExpHalfPiPauli(P"Z", [1]), ExpHalfPiPauli(P"Z", [1])])
    merge_ops(circuit)
    @test isempty(circuit)
    # same-sign pi/8 pair still merges into a pi/4 rotation
    circuit = Circuit([ExpEighPiPauli(P"Z", [1]), ExpEighPiPauli(P"Z", [1])])
    merge_ops(circuit)
    @test length(circuit) == 1
    @test isa_variant(circuit[1], CircuitOp.ExpQuatPiPauli)
end

end
