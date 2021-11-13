function fieldnames_types(in_type::Type{<:Any})
    return [FieldName_Type(x,fieldtype(in_type, x)) for x in fieldnames(in_type)]
end

function tuple_field_id(in_type::Type{<:Any})
    tmp = filter(x->x.type == DbId, fieldnames_types(in_type))
    result = length(tmp) == 1 ? tmp[1] : nothing
    result === nothing && throw("Please ensure that one field in your struct $in_type has filedtype DbId")
    return result
end

function _get_struct_iid(inp_struct)
    iid_field_tuple = tuple_field_id(typeof(inp_struct))
    iid_field_tuple === nothing && throw("Your type $(typeof(inp_struct)) has no id field or too many.
                                            This field has to be of field type DbId")
    return getproperty(inp_struct, iid_field_tuple.fieldname)
end
