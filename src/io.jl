using JLD2
import Base: show
##
"""
    parse_input(filepath::String) -> Circuit

Read an OpenQASM 2.0 file and return a `Circuit`.

Supported gates: `h`, `s`, `sdg`, `t`, `tdg`, `x`, `y`, `z`, `cx`, `measure`.
Each gate is translated to `CircuitOp` variants:
- `h`   → three `ExpQuatPiPauli`: Z, X, Z
- `s`   → `ExpQuatPiPauli(P"Z")`
- `sdg` → `ExpQuatPiPauli(-P"Z")`
- `t`   → `ExpEighPiPauli(P"Z")`
- `tdg` → `ExpEighPiPauli(-P"Z")`
- `x/y/z` → `ExpHalfPiPauli`
- `cx q[c],q[t]` → `PauliConditional(P"Z", [c], P"X", [t])`
- `measure q[i] -> c[j]` → `Measurement(P"Z", j, [i])`

Header lines (`OPENQASM`, `include`, `qreg`, `creg`, `barrier`) are skipped.
"""
function parse_input(filepath::String)::Circuit
    circuit = Circuit()

    open(filepath) do file
        for raw in eachline(file)
            line = strip(raw)
            isempty(line) && continue
            startswith(line, "//") && continue
            any(startswith(line, pfx) for pfx in
                ("OPENQASM", "include", "qreg", "creg", "barrier")) && continue

            # measure q[i] -> c[j];
            m = match(r"^measure\s+\w+\[(\d+)\]\s*->\s*\w+\[(\d+)\];$", line)
            if m !== nothing
                q = parse(Int, m[1])
                c = parse(Int, m[2])
                push!(circuit, CircuitOp.Measurement(P"Z", c, [q]))
                continue
            end

            # cx q[ctrl],q[tgt];
            m = match(r"^[Cc][Xx]\s+\w+\[(\d+)\]\s*,\s*\w+\[(\d+)\];$", line)
            if m !== nothing
                ctrl = parse(Int, m[1])
                tgt  = parse(Int, m[2])
                push!(circuit, CircuitOp.PauliConditional(P"Z", [ctrl], P"X", [tgt]))
                continue
            end

            # single-qubit gate: <name> q[i];
            m = match(r"^(\w+)\s+\w+\[(\d+)\];$", line)
            if m !== nothing
                gate = m[1]
                q    = parse(Int, m[2])
                append!(circuit, _single_qubit_ops(gate, q))
                continue
            end
        end
    end

    return circuit
end

# Internal: translate a single-qubit gate name to its CircuitOps.
function _single_qubit_ops(gate::AbstractString, q::Int)::Vector{CircuitOp.Type}
    if gate == "h"
        return CircuitOp.Type[
            CircuitOp.ExpQuatPiPauli(P"Z", [q]),
            CircuitOp.ExpQuatPiPauli(P"X", [q]),
            CircuitOp.ExpQuatPiPauli(P"Z", [q]),
        ]
    elseif gate == "s"
        return [CircuitOp.ExpQuatPiPauli(P"Z",  [q])]
    elseif gate == "sdg"
        return [CircuitOp.ExpQuatPiPauli(-P"Z", [q])]
    elseif gate == "t"
        return [CircuitOp.ExpEighPiPauli(P"Z",  [q])]
    elseif gate == "tdg"
        return [CircuitOp.ExpEighPiPauli(-P"Z", [q])]
    elseif gate == "x"
        return [CircuitOp.ExpHalfPiPauli(P"X",  [q])]
    elseif gate == "y"
        return [CircuitOp.ExpHalfPiPauli(P"Y",  [q])]
    elseif gate == "z"
        return [CircuitOp.ExpHalfPiPauli(P"Z",  [q])]
    else
        error("Unsupported gate: $gate")
    end
end

"""
    save(result::ComputerState, filepath::String)

Save the first four fields of `result.memory_state` (`pauli_qubits`, `magic_qubits`,
`measurement_results`, `StabilizerGroup`) to a `.jld2` file at `filepath`.
"""
function save(result::ComputerState, filepath::String)
    ms = result.memory_state
    JLD2.jldsave(filepath;
        pauli_qubits        = ms.pauli_qubits,
        magic_qubits        = ms.magic_qubits,
        measurement_results = ms.measurement_results,
        StabilizerGroup     = ms.StabilizerGroup,
    )
end
