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
will be in the schema

```
define
    street sub attribute, value string;
    town sub attribute, value string;

    Address sub entity,
        owns street,
        owns town;
```

If you seen above there is one thing you have to add into the struct besides the fields you want store. You must add an id field of type DbId to your struct. This is needed to identify if the struct is stored (the iid will be stored inside the DbId) or get the corresponding data structure from TypeDBClient.jl.

The **DbId** can be build for a new object with **DbId()**. This marks the struct as new and it will be stored if you write this to the database.

Beside the Types
