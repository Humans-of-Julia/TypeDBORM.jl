mutable struct DbId
    iid::String
end

function DbId()
    DbId("")
end

const Filter_Types = Union{<:AbstractAttributeType, <:AbstractRelationType}
const Build_Types = Union{<:AbstractAttribute, <:AbstractRelation}
