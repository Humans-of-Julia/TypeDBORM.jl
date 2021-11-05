module TypeDBORM

using TypeDBClient: ConceptMap, AbstractAttributeType, Proto, ConceptManager, AbstractThingType
using TypeDBClient: AbstractCoreTransaction, AbstractAttribute, AbstractThing, AttributeType
using TypeDBClient: AbstractRelationType, Label
using TypeDBClient: as_remote, create, get_has, get_instances, put, set_has, unset_has
using TypeDBClient: add_player, get_relations
using TypeDBClient
using Dates

include("read_write_orm.jl")

export read_concept_from_struct, write_struct, default_value_of

const Direct_Storables = Union{AbstractString, Number, Bool, Date, DateTime}

end
