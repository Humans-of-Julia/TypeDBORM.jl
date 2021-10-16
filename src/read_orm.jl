default_value_of(::Type{String}) = ""
default_value_of(::Type{Bool}) = false
default_value_of(::Type{<:Number}) = 0

filter_attributes(a::Vector{<:AbstractAttribute}) = a
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

function define_conversation(concept_or_attribute)
    dict_convers = Dict{Symbol,Any}()
    attr_filter = filter_attributes(concept_or_attribute)
    for attr in attr_filter
        dict_convers[Symbol(attr.type.label.name)] = attr.type.label.name
    end
    return dict_convers
end

function concept_to_struct(concept_or_attributes, inp_struct::Type{<:Any})
    attributes = values_of_attributes(filter_attributes(concept_or_attributes))
    conversation_attributes = define_conversation(concept_or_attributes)
    values = Vector{Any}()

    for field in fieldnames(inp_struct)
        if haskey(conversation_attributes, field) && haskey(attributes, conversation_attributes[field])
            push!(values, attributes[conversation_attributes[field]])
        else
            push!(values, default_value_of(fieldtype(inp_struct, field)))
        end
    end

    return inp_struct(values...)
end

function read_concept_from_struct(transaction::AbstractCoreTransaction, inp_struct_type, type::Type{<:AbstractThingType})
    thing_type = get(ConceptManager(transaction), type, string(inp_struct_type))
    instances_typ = get_instances(as_remote(thing_type, transaction))

    thing_attributs = []
    for instance in instances_typ
        push!(thing_attributs, get_has(transaction, instance))
    end

    result = inp_struct_type[]
    for attributes in thing_attributs
        push!(result, concept_to_struct(attributes, inp_struct_type))
    end
    return result
end
