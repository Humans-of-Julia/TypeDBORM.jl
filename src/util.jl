function fieldnames_types(in_type::Type{<:Any})
    return [(x,fieldtype(in_type, x)) for x in fieldnames(in_type)]
end

function tuple_field_id(in_type::Type{<:Any})
    tmp = filter(x->x[2] == DbId, fieldnames_types(in_type))
    result = length(tmp) == 1 ? tmp[1] : nothing
    return result
end
