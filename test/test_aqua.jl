@testitem "Aqua analysis" tags=[:aqua] begin

using Aqua, PBCCompiler

Aqua.test_all(PBCCompiler)

end
