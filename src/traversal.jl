"""
Circuit traversal utilities for gate simplifications and transformations.
"""

"""
    traversal(circuit::Circuit, pair_transformation, direction=:right, starting_index=1, end_index=:end)

Traverse a circuit and apply `pair_transformation` to each pair of adjacent operations.

# Arguments
- `circuit::Circuit`: The circuit to traverse (modified in-place)
- `pair_transformation`: A function that takes two operations and returns:
  - A tuple of operations `(op1, op2)` to replace the current pair
  - A single operation to replace both operations (combining them)
  - `nothing` to keep the original operations unchanged
- `direction`: `:right` to traverse left-to-right, `:left` to traverse right-to-left (default: `:right`)
- `starting_index`: Index to start traversal from (default: `1`)
- `end_index`: Index to end traversal at, or `:end` for the last valid pair (default: `:end`)

# Returns
The modified circuit.

# Example
```julia
# Swap adjacent operations
swap_transform(op1, op2) = (op2, op1)
traversal(circuit, swap_transform)
```
"""
function traversal(circuit::Circuit, pair_transformation, direction::Symbol=:right, starting_index::Int=1, end_index::Union{Int,Symbol}=:end)
    if isempty(circuit) || length(circuit) < 2
        return circuit
    end

    # Resolve end_index
    actual_end = end_index === :end ? length(circuit) - 1 : end_index

    # Validate indices
    if starting_index < 1 || starting_index > length(circuit) - 1
        return circuit
    end
    if actual_end < 1 || actual_end > length(circuit) - 1
        actual_end = length(circuit) - 1
    end

    if direction === :right
        _traversal_right!(circuit, pair_transformation, starting_index, actual_end)
    elseif direction === :left
        _traversal_left!(circuit, pair_transformation, starting_index, actual_end)
    else
        throw(ArgumentError("direction must be :right or :left, got :$direction"))
    end

    return circuit
end

"""
Internal: Traverse left-to-right, applying pair_transformation to adjacent pairs.
"""
function _traversal_right!(circuit::Circuit, pair_transformation, start_idx::Int, end_idx::Int)
    i = start_idx
    while i <= end_idx && i <= length(circuit) - 1
        op1 = circuit[i]
        op2 = circuit[i + 1]

        result = pair_transformation(op1, op2)

        if result === nothing
            # No change, move to next pair
            i += 1
        elseif result isa Tuple && !(result isa CircuitOp.Type) && length(result) == 2
            # Replace with tuple elements (explicitly check it's a 2-tuple and not a CircuitOp)
            circuit[i] = result[1]
            circuit[i + 1] = result[2]
            i += 1
        else
            # Single operation replaces both - splice to remove one element
            circuit[i] = result
            deleteat!(circuit, i + 1)
            # Adjust end_idx since we removed an element
            end_idx = min(end_idx, length(circuit) - 1)
            # Don't increment i, check the new pair at this position
        end
    end
end

"""
Internal: Traverse right-to-left, applying pair_transformation to adjacent pairs.
"""
function _traversal_left!(circuit::Circuit, pair_transformation, start_idx::Int, end_idx::Int)
    i = end_idx
    while i >= start_idx && i >= 1
        op1 = circuit[i]
        op2 = circuit[i + 1]

        result = pair_transformation(op1, op2)

        if result === nothing
            # No change, move to previous pair
            i -= 1
        elseif result isa Tuple && !(result isa CircuitOp.Type) && length(result) == 2
            # Replace with tuple elements (explicitly check it's a 2-tuple and not a CircuitOp)
            circuit[i] = result[1]
            circuit[i + 1] = result[2]
            i -= 1
        else
            # Single operation replaces both - splice to remove one element
            circuit[i] = result
            deleteat!(circuit, i + 1)
            # Move to previous pair
            i -= 1
        end
    end
end
