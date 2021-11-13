mutable struct DbId
    iid::String
end

function DbId()
    DbId("")
end

struct FieldName_Type
    fieldname::Symbol
    type::Type
end

const Filter_Types = Union{<:AbstractAttributeType, <:AbstractRelationType}
const Build_Types = Union{<:AbstractAttribute, <:AbstractRelation}
