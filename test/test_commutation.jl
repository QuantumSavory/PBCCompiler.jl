@testitem "check_commutation" tags=[:check_commutation] begin

using PBCCompiler
using PBCCompiler: Circuit, CircuitOp, Measurement, ExpHalfPiPauli, ExpQuatPiPauli, ExpEighPiPauli, PauliConditional, BitConditional, affectedqubits, MainIteration
using Test
using PBCCompiler: check_commutation
using QuantumClifford: @P_str, comm
@testset "Test unordered input" begin
    op1=ExpQuatPiPauli(P"XY", [1, 3])
    op2=ExpQuatPiPauli(P"ZXY", [3, 1, 2])

    t_1=comm(op1.pauli,op2.pauli)
    @test t_1 == 0x00

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x01

end

@testset "Test non-overlapping input" begin
    op1=ExpQuatPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [2])

    t_1=comm(op1.pauli,op2.pauli)
    @test t_1 == 0x01

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x00

end

@testset "Test partially overlapping input" begin
    op1=ExpQuatPiPauli(P"XX", [1, 3])
    op2=ExpQuatPiPauli(P"ZY", [3, 4])

    t_1=comm(op1.pauli,op2.pauli)
    @test t_1 == 0x00

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x01

end

@testset "Test different Pauli Product Rotation input" begin
    op1=ExpHalfPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [1])
    op3=ExpEighPiPauli(P"Y", [1])

    t_1=check_commutation(op1,op2)
    @test t_1 == 0x01

    t_2=check_commutation(op1, op2)
    @test t_2 == 0x01

    t_3=check_commutation(op1,op3)
    @test t_3 == 0x01

end

@testset "Test Pauli Conditional input" begin
    op1=ExpQuatPiPauli(P"ZX", [1, 2])
    op2=ExpQuatPiPauli(P"ZY", [1, 2])
    op3=ExpQuatPiPauli(P"YX", [1, 2])
    CNOT=PauliConditional(P"Z", [1], P"X", [2])

    t_1=check_commutation(op1,CNOT)
    @test t_1 == (0x00,0x00)

    t_2=check_commutation(op2,CNOT)
    @test t_2 == (0x00,0x01)

    t_3=check_commutation(op3,CNOT)
    @test t_3 == (0x01,0x00)

end

@testset "Test Bit Conditional input" begin
    op1=ExpQuatPiPauli(P"X", [1])
    op2=ExpQuatPiPauli(P"Z", [1])
    bit_cond_op=BitConditional(op1, 0)

    t_1=check_commutation(bit_cond_op, op2)
    @test t_1 === nothing

end

end