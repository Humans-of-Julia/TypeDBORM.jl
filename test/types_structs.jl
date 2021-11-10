Optional{T} = Union{Nothing,T}

struct Address
    street::String
    town::String
end

struct TestTypeStruct
    address_rel::Optional{Address}
end
