using Printf

file = open("C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom.vspaero")

content = read("C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom.vspaero", String)

lines = readlines("C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom.vspaero")

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
    write("C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/test.txt", join(lines, "\n"))
end


vspaero_dir = "C:/Users/kizan/OneDrive/Documents/__Aves_Nova/FlightDynamics/openvsp/A2M6/A2M6_DegenGeom.vspaero"
updates = Dict(
    "AoA" => 12.12,
    "Flaps" => 69.69,
)

change_flight_parameters(vspaero_dir, updates)