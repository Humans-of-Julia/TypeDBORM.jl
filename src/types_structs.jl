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

const Build_Types = Union{<:AbstractAttribute, <:AbstractRelation}
const Direct_Storables = Union{<:AbstractString, <:Number, Bool, Date, DateTime}
