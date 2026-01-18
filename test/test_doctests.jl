@testitem "doctests" tags=[:doctests] begin

using Documenter
using PBCCompiler

DocMeta.setdocmeta!(PBCCompiler, :DocTestSetup, :(using QuantumClifford, PBCCompiler); recursive=true)
doctest(PBCCompiler)

end
