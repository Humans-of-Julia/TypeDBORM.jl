module TypeDBORM

using TypeDBClient: ConceptMap, AbstractAttributeType, Proto
using TypeDBClient

export concept_to_struct, define_conversation

include("read_orm.jl")

struct Person
    email::String
    full_name::String
end

end
