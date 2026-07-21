@testitem "random_circuit" tags=[:random_circuit] begin
using PBCCompiler
using PBCCompiler: random_test_circuit, get_circuit_width

@testset "random circuit generation" begin
    num_qubits = 3
    num_ops = 15

    circuit = random_test_circuit(num_ops, num_qubits)

    @test length(circuit) == num_ops + num_qubits
    @test get_circuit_width(circuit) == num_qubits
end

end
