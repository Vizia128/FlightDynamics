using Printf, DataFrames, CSV, Random, JLD2


function update_parameters(lines::Vector{String}, updates::Dict{String, Float64})
    for (i, line) in enumerate(lines)
        for (param, new_value) in updates
            if occursin("$param =", line)
                # Extract and modify the value
                value = split(line, "=")[2] |> strip
                value = parse(Float64, value)
                lines[i] = "$param = $((@sprintf("%.6f", new_value)))"
            elseif line == param
                # Special handling for Flaps
                # The Flaps value is three lines down from the "Flaps" line
                value = lines[i + 3] |> strip
                value = parse(Float64, value)
                lines[i + 3] = @sprintf("%.2f", new_value)
            end
        end
    end
    return lines
end

function change_flight_parameters(vspaero_dir::String, updates::Dict{String, Float64})
    lines = readlines(vspaero_dir)
    lines = update_parameters(lines, updates)
    write(vspaero_dir, join(lines, "\n"))
end

function read_polars_to_dataframe(filename::String)
    # Read all lines from the file
    lines = readlines(filename)
    
    # Get headers and data
    header_line = lines[1]
    data_line = lines[2]
    
    # Split and strip both headers and data
    headers = strip.(split(header_line, r"\s+"))
    data_str = strip.(split(data_line, r"\s+"))
    
    # Remove any empty strings
    headers = filter(x -> x != "", headers)
    data_str = filter(x -> x != "", data_str)
    
    # Parse data strings to Float64
    data = parse.(Float64, data_str)
    
    # Create DataFrame
    df = DataFrame()
    for (header, value) in zip(headers, data)
        df[!, Symbol(header)] = [value]
    end
    
    return df
end

function get_parameters()::Dict
    return Dict(
        "AoA" => 40rand() - 20,
        "Beta" => 40rand() - 20,
        "ReCref" => 10^(3rand() + 4),
        "Ailerons" => 40rand() - 20,
        "Rudder" => 40rand() - 20,
        "Elevator" => 40rand() - 20,
        "Flaps" => 40rand() - 20,
    )
end

function run_vspaero_and_wait(command::Cmd)
    cmd = pipeline(command, stdout=IOBuffer())
    process = run(cmd, wait=false)  # run asynchronously

    while process.exitcode === nothing
        sleep(1)  # or a more suitable duration
        output = String(take!(cmd.stdout))
        
        if occursin("Total setup and solve time:", output)
            break
        end
    end

    wait(process)  # Ensure the process is completely done

    return process.exitcode
end

function create_vspaero_training_data(
    num_data_points;
    vspaero_config_dir::String = "C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom.vspaero", 
    vspaero_results_dir::String = "C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom.polar", 
    training_data_dir::String = "C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/training_data.csv",
    command::Cmd = `C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/OpenVSP-3.35.3-win64/vspaero.exe -omp 16 C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom`,
)
    training_data::DataFrame = DataFrame()

    for iter in 1:num_data_points
        parameters = get_parameters()
        change_flight_parameters(vspaero_config_dir, parameters)
    
        exitcode = run_vspaero_and_wait(command)
        if exitcode != 0
            @warn "vspaero failed with exit code $exitcode"
            return
        end
    
        params = DataFrame(parameters)
        polars = read_polars_to_dataframe(vspaero_results_dir)

        df_local::DataFrame = hcat(params, polars; makeunique=true)
        training_data = vcat(training_data, df_local)

        CSV.write(training_data_dir, training_data)
        jldsave("training_data_20_deg_radius.jld2"; training_data)
        println("Finished simulation run $iter")
    end
end

create_vspaero_training_data(4096)
