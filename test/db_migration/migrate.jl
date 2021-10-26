file_name_default = joinpath(dirname(@__FILE__), "type_db_default.tql")
file_name_schema = joinpath(dirname(@__FILE__), "type_db_schema.tql")
file_name = joinpath(dirname(@__FILE__), "type_db.tql")

if !ispath(file_name)
    # customize the runscript to the environment
    text = read(open(file_name_default), String)
    text = replace(text, "\$file_path"=>file_name_schema)
    write(file_name, text)
    # run the customized script
    run(Cmd(`typedb console --script=$file_name`))
    # remove the line of the creation of the database
    lines = readlines(file_name)
    text = join(deleteat!(lines, 1),"\n")
    write(file_name, text)
end
# run the schema script
run(Cmd(`typedb console --script=$file_name`))
