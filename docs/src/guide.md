## Getting Started

To build a schema according the struct you want store there are some guidelines.

The names of the structs an the Entities have to be the same e.g.

```julia
struct Address
    street::String
    town::String,
    addr_id::DbId
end
```


#### a simple translation into a schema


```
define
    street sub attribute, value string;
    town sub attribute, value string;

    Address sub entity,
        owns street,
        owns town;
```

If you seen above there is one thing you have to add into the struct besides the fields you want store.
You must add an id field of type DbId to your struct. This is needed to identify if the struct is stored
(the iid will be stored inside the DbId) or get the corresponding data structure from TypeDBClient.jl.

The **DbId** can be build for a new object with **DbId()**. This marks the struct as new and it will
be stored if you write this to the database.

The types String, Number, Date, DateTime and Boolean will be stored directly as attributes.
If you use another struct inside a struct the corresponding object will be stored as a relation.
This relation has to be modelled inside the schema. An example struct and schema will looks like the
following:

```julia
struct Address
    street::String
    town::String,
    addr_id::DbId
end
```

```julia
mutable struct Employee
    name::String
    address_rel::Address
    empl_id::DbId
end
```

```
define
    street sub attribute, value string;
    town sub attribute, value string;
    name sub attribute, value string;

    Address sub entity,
        owns street,
        owns town.
        play address_rel:address;


    Employee sub entity,
        owns name,
        plays address_rel:employee;

    adress_rel sub relation,
        relates address,
        relates employee;
```

Please note that the roles **relates address** has to be written with the same naming as the structs.
In this case address => Address. The naming isn't case sensitiv so you can follow the naming conventions
in Julia that the names of structs begins with a uppercase Letter.
