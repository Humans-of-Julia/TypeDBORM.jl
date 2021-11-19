using TypeDBORM
using Test

using TypeDBORM: _resulting_fieldtype

include(joinpath(dirname(@__FILE__),"types_structs.jl"))

@testset "util_functions" begin
    rel_type = _resulting_fieldtype(Employee, :address_rel)
    @info rel_type
    @test rel_type == Address
end
