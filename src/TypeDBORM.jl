module TypeDBORM

using TypeDBClient: ConceptMap, AbstractAttributeType, Proto, ConceptManager, AbstractThingType
using TypeDBClient: AbstractCoreTransaction, AbstractAttribute
using TypeDBClient: as_remote, create, get_has, get_instances, put, set_has
using TypeDBClient

include("read_write_orm.jl")

export read_concept_from_struct, write_struct

end
