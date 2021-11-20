Optional{T} = Union{Nothing,T}

mutable struct Address
    street::String
    house_nr::String
    zip_code::String
    town::String
    iid::DbId
end

function Address()
    return Address("","","","",DbId())
end

mutable struct Employee
    name::String
    contact_person_first::String
    contact_person_second::String
    job_title::String
    salutation::String
    call_text::String
    done::Bool
    address_rel::Optional{Address}
    callback_date::Optional{DateTime}
    iid::DbId
end
