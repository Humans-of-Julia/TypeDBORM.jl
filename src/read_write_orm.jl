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

    thing_attributs = Dict()
    for instance in instances_typ
        thing_attributs[instance.iid] = get_has(transaction, instance)
    end

    result = Dict{Any,inp_struct_type}()
    for (iid, attributes) in thing_attributs
        result[iid] =  concept_to_struct(attributes, inp_struct_type)
    end
    return result
end

function write_struct_new(transaction::AbstractCoreTransaction,
    save_struct,
    type::Type{<:AbstractThingType})

    # get type of the struct and create an object in the database
    type = _get_type(transaction, save_struct, type)
    obj = _create_obj_from_type(transaction, type, save_struct)

    # take all fields of the struct and set attributes to the object
    obj = _set_attributes_of_entity!(transaction, obj, save_struct)

    return obj
end

function write_struct_update(transaction::AbstractCoreTransaction,
    write_struct,
    iid::String)

    # get the thing from the database
    obj = get(ConceptManager(transaction), iid)

    # take all fields of the struct and set attributes to the object
    obj = _set_attributes_of_entity!(transaction, obj, write_struct)

    return obj
end

function write_struct(transaction::AbstractCoreTransaction,
    write_struct,
    type::Type{<:AbstractThingType},
    iid::String = "")

    if isempty(iid)
        write_struct_new(transaction, write_struct, type)
    else
        write_struct_update(transaction, write_struct, iid)
    end
end

# Utility function
function _get_type(transaction::AbstractCoreTransaction, obj::Any, type::Type{<:AbstractThingType})
    thing_type = get(ConceptManager(transaction), type, string(typeof(obj)))
    return thing_type
end

function _get_type(transaction::AbstractCoreTransaction, obj::Type{<:Any}, type::Type{<:AbstractThingType})
    thing_type = get(ConceptManager(transaction), type, string(obj))
    return thing_type
end

function _create_obj_from_type(transaction::AbstractCoreTransaction, type::AbstractThingType, save_struct )
    obj = nothing
    if typeof(type) <: EntityType
        obj = create(as_remote(type, transaction))
    elseif typeof(type)<:AbstractAttributeType
        obj = put(as_remote(type, transaction), value(save_struct))
    else
        throw("Type requested not supported yet")
    end

    return obj
end

function _create_or_load_attribute(transaction::AbstractCoreTransaction, attribute_name::Symbol, value)
    result = nothing
    attr_type =  get(ConceptManager(transaction), AttributeType, string(attribute_name))
    attr = get(as_remote(attr_type, transaction), value)
    if attr === nothing
        result = put(as_remote(attr_type, transaction), value)
    else
        result = attr
    end
    return result
end

function _create_or_load_relation(transaction::AbstractCoreTransaction,
    thing::AbstractThing,
    owner_struct,
    relation_name::AbstractString,
    relation_struct)

    #get all relations of the thing stored yet
    rels = get_relations(transaction, thing)
    rel_have_to_be_new = true
    if !isempty(rels)
        @error "not empty realtions have to be implemented"
    end

    if rel_have_to_be_new
        rel_type = get(ConceptManager(transaction), RelationType, relation_name)
        # relation = create(as_remote(rel_type, transaction))
        relates_to = get_plays(as_remote(rel_type, transaction))
        #TODO: Workout relates and get it work if more than one item is meant.
    end

end

function _set_attributes_of_entity!(transaction::AbstractCoreTransaction,
    obj::AbstractThing,
    save_struct)

    for field in fieldnames(typeof(save_struct))
        value = getproperty(save_struct,Symbol(field))

        if !(typeof(value) <: Direct_Storables) && value !== nothing
            attr_type = get(ConceptManager(transaction), AttributeType, string(field))
            attr_old = get_has(transaction, obj, attr_type)
            attr = _create_or_load_attribute(transaction, field, value)

            if attr_old !== nothing
                if attr.value != attr_old[1].value
                    unset_has(transaction, obj, attr_old[1])
                end
            end

            set_has(transaction, obj, attr)
        elseif (typeof(value) <: Any)
            _create_or_load_relation(transaction, obj, save_struct, string(field), value)
        end
    end
    return obj
end

function value(save_struct::Any)
    return values(save_struct)
end
