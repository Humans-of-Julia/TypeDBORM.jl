default_value_of(::Type{String}) = ""
default_value_of(::Type{Bool}) = false
default_value_of(::Type{<:Number}) = 0
default_value_of(::Type{DbId}) = DbId()

function filter_attributes(a::Vector{<:Any}, struct_type::Type{<:Any})
    # Secure that all elements of a are of type Build_Types
    @assert all(typeof.(a).<: Build_Types)

    attr_rel_names = [x.type.label.name for x in a]
    names_of_fields = string.(fieldnames(struct_type))
    result_names = intersect(attr_rel_names, names_of_fields)
    attribs = filter(x->in(x.type.label.name, result_names), a)

    return attribs
end

function filter_attributes(concept::ConceptMap)
    return filter(x->typeof(x.type) <: Filter_Types, collect(values(concept.data)))
end

function _get_value(::AbstractCoreTransaction, inp::AbstractAttribute, ::Type{<:Any}, ::AbstractThing)
    return inp.value
end

function _get_value(transaction::AbstractCoreTransaction,
    inp_relation::AbstractRelation,
    inp_struct_type::Type{<:Any},
    thing::AbstractThing)

    result = nothing
    # get the fieldtype of the relation struct
    field_type = _resulting_fieldtype(inp_struct_type, Symbol(inp_relation.type.label.name))
    # get all players for the given relation
    rel_player = filter(x->string(field_type) == x.type.label.name, get_players(transaction, inp_relation))
    # process the right struct_type for a given iid to a struct
    if length(rel_player) == 1
        read_result = read_concept_from_struct(transaction, field_type, typeof(rel_player[1].type), rel_player[1].iid)
        result = !isempty(read_result) ? read_result[1] : nothing
    else
        throw("get_value of relations for iid: $(thing.iid) went wrong")
    end
    return result
end

function values_of_attributes(transaction::AbstractCoreTransaction ,
    attributes::Vector,
    inp_type_struct::Type{<:Any},
    thing::AbstractThing)

    attribute_values = Dict{String,Any}()
    for attribute in attributes
        attribute_values[attribute.type.label.name] = _get_value(transaction, attribute, inp_type_struct, thing)
    end
    return attribute_values
end

function define_conversation(concept_or_attribute, struct_type::Type{<:Any})
    dict_convers = Dict{Symbol,Any}()
    attr_filter = filter_attributes(concept_or_attribute, struct_type)
    for attr in attr_filter
        dict_convers[Symbol(attr.type.label.name)] = attr.type.label.name
    end
    return dict_convers
end

function concept_to_struct(transaction::AbstractCoreTransaction,
    concept_or_attributes,
    inp_struct_type::Type{<:Any},
    id_field::Tuple{Symbol, DataType},
    thing::AbstractThing)

    filtered_attributes = filter_attributes(concept_or_attributes, inp_struct_type)

    attributes = values_of_attributes(transaction, filtered_attributes, inp_struct_type, thing)
    conversation_attributes = define_conversation(concept_or_attributes, inp_struct_type)
    # add iid to the attributes
    conversation_attributes[id_field[1]] = DbId(thing.iid)

    values = Vector{Any}()
    for field in fieldnames(inp_struct_type)
        if haskey(conversation_attributes, field) && haskey(attributes, conversation_attributes[field])
            push!(values, attributes[conversation_attributes[field]])
        else
            push!(values, default_value_of(fieldtype(inp_struct_type, field)))
        end
    end

    result = inp_struct_type(values...)
    # set the id rigth
    setfield!(result, id_field[1], DbId(thing.iid))

    return result
end

function read_concept_from_struct(transaction::AbstractCoreTransaction,
    inp_struct_type::Type{<:Any},
    type::Type{<:AbstractThingType},
    iid::String = "")


    if iid == ""
        thing_type = get(ConceptManager(transaction), type, string(inp_struct_type))
        instances_of_type = get_instances(as_remote(thing_type, transaction))
    else
        instances_of_type = [get(ConceptManager(transaction), iid)]
    end

    # detect the id field inside the given struct type
    tuple_id_field = tuple_field_id(inp_struct_type)
    @assert(tuple_id_field !== nothing,
        "Please ensure that one field in your struct has filedtype DbId")

    thing_attributs = Dict()
    for instance in instances_of_type
        # get attributes
        thing_attributs[instance] = Build_Types[]
        thing_attributs[instance] = vcat(thing_attributs[instance], get_has(transaction, instance))
        # get relations
        thing_attributs[instance] = vcat(thing_attributs[instance], get_relations(transaction, instance))
    end

    result = inp_struct_type[]
    for (instance,attributes) in thing_attributs
        push!(result, concept_to_struct(transaction,attributes, inp_struct_type, tuple_id_field, instance))
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
        @error "not empty relations have to be implemented"
    end

    relates = nothing
    if rel_have_to_be_new
        rel_type = get(ConceptManager(transaction), RelationType, relation_name)
        rel_type === nothing && throw("relation: $relation_name isn't defined in schema")
        # relation = create(as_remote(rel_type, transaction))
        relates_to = get_plays(as_remote(rel_type, transaction))
        #TODO: Workout relates and get it work if more than one item is meant.
    end
    @info relates_to
    return relates
end

function _set_attributes_of_entity!(transaction::AbstractCoreTransaction,
    obj::AbstractThing,
    save_struct)

    for field in fieldnames(typeof(save_struct))
        value = getproperty(save_struct,Symbol(field))

        if (typeof(value) <: Direct_Storables) && value !== nothing
            attr_type = get(ConceptManager(transaction), AttributeType, string(field))
            attr_old = get_has(transaction, obj, attr_type)
            attr = _create_or_load_attribute(transaction, field, value)

            if !(isempty(attr_old))
                if attr.value != attr_old[1].value
                    unset_has(transaction, obj, attr_old[1])
                end
            end

            set_has(transaction, obj, attr)
        elseif (typeof(value) <: Any) && value !== nothing
            _create_or_load_relation(transaction, obj, save_struct, string(field), value)
        end
    end
    return obj
end

function value(save_struct::Any)
    return values(save_struct)
end

function _resulting_fieldtype(inp_struct_type::Type{<:Any}, field::Symbol)
    field_type = fieldtype(inp_struct_type, field)
    type_of_field_type = typeof(field_type)

    inside_types = nothing
    if type_of_field_type == Union
        types = filter(x->x !== Nothing, Base.uniontypes(field_type))
        length(types) != 1 && throw("
        Not correct count of Types inside $inp_struct_type of field: $(string(field)). \n
        For now only a kind of formulation like Union{Nothing, String} is possible")
        inside_types = types[1]
    else
        inside_types = fieldtype(inp_struct_type, field)
    end
    return inside_types
end
