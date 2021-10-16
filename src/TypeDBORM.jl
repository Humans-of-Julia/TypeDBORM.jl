module TypeDBORM

using TypeDBClient: ConceptMap, AbstractAttributeType, Proto, ConceptManager, AbstractThingType
using TypeDBClient: AbstractCoreTransaction, AbstractAttributeType, AbstractAttribute
using TypeDBClient: get_instances, as_remote, get_has
using TypeDBClient

include("read_orm.jl")

end
