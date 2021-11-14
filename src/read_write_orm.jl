default_value_of(::Type{String}) = ""
default_value_of(::Type{Bool}) = false
default_value_of(::Type{<:Number}) = 0
default_value_of(::Type{DbId}) = DbId()

#### read section ###########################

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
    return filter(x->typeof(x.type) <: Build_Types, collect(values(concept.data)))
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
    id_field::FieldName_Type,
    thing::AbstractThing)

    filtered_attributes = filter_attributes(concept_or_attributes, inp_struct_type)

    attributes = values_of_attributes(transaction, filtered_attributes, inp_struct_type, thing)
    conversation_attributes = define_conversation(concept_or_attributes, inp_struct_type)
    # add iid to the attributes
    conversation_attributes[id_field.fieldname] = DbId(thing.iid)

    values = Vector{Any}()
    for field in fieldnames(inp_struct_type)
        if haskey(conversation_attributes, field) && haskey(attributes, conversation_attributes[field])
            push!(values, attributes[conversation_attributes[field]])
        else
            push!(values, default_value_of(fieldtype(inp_struct_type, field)))
        end
    end

    result = inp_struct_type(values...)
    # set the id right
    setfield!(result, id_field.fieldname, DbId(thing.iid))

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

####### write section contains new and update ##############
function write_struct_new(transaction::AbstractCoreTransaction,
    save_struct,
    type::Type{<:AbstractThingType})

    # get type of the struct and create an object in the database
    type = _get_type(transaction, save_struct, type)
    obj = _create_obj_from_type(transaction, type, save_struct)

    # take all fields of the struct and set attributes to the object
    thing = _set_attributes_of_entity!(transaction, obj, save_struct)

    return thing
end

function write_struct_update(transaction::AbstractCoreTransaction,
    write_struct,
    db_iid::DbId)

    # get the thing from the database
    obj = get(ConceptManager(transaction), db_iid.iid)

    # take all fields of the struct and set attributes to the object
    obj = _set_attributes_of_entity!(transaction, obj, write_struct)

    return obj
end

function write_struct(transaction::AbstractCoreTransaction,
    write_struct,
    type::Type{<:AbstractThingType} = EntityType)

    iid_field_tupel = tuple_field_id(typeof(write_struct))
    db_iid = getproperty(write_struct, iid_field_tupel.fieldname)

    thing = nothing

    if isempty(db_iid.iid)
        thing = write_struct_new(transaction, write_struct, type)
    else
        thing = write_struct_update(transaction, write_struct, db_iid)
    end

    return thing
end

####### delete functionality #####################
function delete!(transaction::AbstractCoreTransaction, inp_struct::Any)
    struct_iid = _get_struct_iid(inp_struct)
    isempty(struct_iid.iid) && throw("Please provide the iid inside the struct type $(typeof(inp_struct))")
    thing = get(ConceptManager(transaction), struct_iid.iid)
    try
        delete(as_remote(thing,transaction))
    catch ex
        @info ex
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

    # make the relation type
    rel_type = RelationType(Label("", relation_name), false)
    # get the roles associated with the relation
    roles = get_relates(as_remote(rel_type, transaction))
    # filter the roles for the relation struct name
    role_for_relation_struct = filter(x-> lowercase(x.label.name) ==
                                        lowercase(string(typeof(relation_struct))), roles)

    role_for_owner_struct = filter(x-> lowercase(x.label.name) ==
                                        lowercase(string(typeof(owner_struct))), roles)

    # getting the thingtype of the relation_struct for writing it to the database
    relation_struct_type = _get_thingtype_for_role(transaction,
                                role_for_relation_struct[1],
                                relation_struct)

    # write relation struct to the databse
    rel_thing = write_struct(transaction, relation_struct, relation_struct_type)

    # get the relations according the roles selected. For now there should be only one relation
    # for a struct which will be stored.
    # TODO: build the ability to store more then one struct aka Vector of structs
    rels = Relation[]
    try
        rels = get_relations(transaction, thing, roles)
    catch ex
        occursin("Concept does not exist", ex.error_message) && throw("Please check your relation
        name $relation_name in your struct $owner_struct against the definition in the schema")
    end

    if !isempty(rels)
        @assert length(rels) == 1 "For now only one struct per relation $relation_name
                                    in $(string(owner_struct)) is supported"

        player_rel = get_players(transaction, rels[1], role_for_relation_struct)
        if length(player_rel) == 1
            if player_rel[1].iid != rel_thing.iid
                remove_player(transaction, rels[1], role_for_relation_struct[1], player_rel[1])
                add_player(transaction, rels[1], role_for_relation_struct[1], rel_thing)
            end
        else
            throw("something went wrong in updating the relation $relation_name
            for struct $(string(owner_struct))")
        end
    else
        # build new relations
        relation = create(as_remote(rel_type, transaction))
        # adding the relation struct to the give relation
        add_player(transaction, relation, role_for_relation_struct[1], rel_thing)
        # adding the owner struct to the give relation
        add_player(transaction, relation, role_for_owner_struct[1], thing)
        #TODO: Workout relates and get it work if more than one item is meant.
    end

    return nothing
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
        elseif (typeof(value) <: Any) && typeof(value) != DbId && value !== nothing
            _create_or_load_relation(transaction, obj, save_struct, string(field), value)
        end
    end
    return obj
end

function value(save_struct::Any)
    return values(save_struct)
end

## The needed function should return the type of a Union type structure
## which is not Nothing but Nothing has to be there.
function _get_union_type(x::Union)
    typeof(x.b) == Union && throw("The Union type $x contains too many types")
    Nothing <: x || throw("One Nothing in your Union definition $x has to be there")
    (x.a == Nothing) ? x.b : x.a
end

function _resulting_fieldtype(inp_struct_type::Type{<:Any}, field::Symbol)
    field_type = fieldtype(inp_struct_type, field)
    type_of_field_type = typeof(field_type)

    inside_types = nothing
    if type_of_field_type == Union
        inside_types = _get_union_type(field_type)
    else
        inside_types = fieldtype(inp_struct_type, field)
    end
    return inside_types
end

function _get_thingtype_for_role(transaction::AbstractCoreTransaction,
    role::RoleType,
    inp_struct::Any)

   players = get_players(transaction, Label(role.label.scope, role.label.name))
   filter!(x->lowercase(x.label.name) == lowercase(string(typeof(inp_struct))), players)
   length(players) != 1 && throw("something went wrong detecting the ThingType from the role $role")
   return typeof(players[1])
end
