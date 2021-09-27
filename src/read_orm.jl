function filter_attributes(concept::ConceptMap)
    return filter(x->typeof(x.type) <: AbstractAttributeType, collect(values(concept.data)))
end

function values_of_attributes(attributes::Vector)
    attribute_values = Dict{String,Any}()
    for attribute in attributes
        attribute_values[attribute.type.label.name] = attribute.value
    end
    return attribute_values
end

function define_conversation(concept::ConceptMap, inp_struct::Type{<:Any})
    dict_convers = Dict{String,String}()
    for attr in filter_attributes(concept)
        dict_convers[Symbol(attr.type.label.name)] = attr.type.label.name
    end
    return dict_convers
end

function concept_to_struct(concept::ConceptMap, inp_struct::Type{<:Any})
    attributes = values_of_attributes(filter_attributes(concept))
    conversation_attributes = define_conversation(concept, inp_struct)
    field_values = Dict{Symbol,Any}()
    values = Vector{Any}()

    for field in fieldnames(inp_struct)
        if haskey(conversation_attributes, field) && haskey(attributes, conversation_attributes[field])
            field_values[Symbol(field)] = attributes[conversation_attributes[field]]
        else
            field_values[Symbol(field)] = default_value_of(fieldtype(inp_struct, field))
        end
    end
    for (_, v) in field_values
        push!(values, v)
    end

    return inp_struct(values...)
end

default_value_of(::Type{String}) = ""
default_value_of(::Type{Bool}) = false
default_value_of(::Type{<:Number}) = 0
