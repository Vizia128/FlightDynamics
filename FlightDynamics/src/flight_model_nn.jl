using Flux, CUDA, ProgressMeter, JLD2, Plots, Statistics, LinearAlgebra

function load_data()
    @load "training_data_20_deg_radius.jld2" training_data

    filter!(row -> row[:CMx] .|> abs .|> log10 < -1, training_data)
    filter!(row -> row[:CMy] .|> abs .|> log10 < 0, training_data)
    filter!(row -> row[:CMz] .|> abs .|> log10 < -1.5, training_data)
    training_data.ReCref = log10.(training_data.ReCref)
    
    inputs = Matrix{Float32}(training_data[:, [:AoA, :Beta, :ReCref, :Ailerons, :Rudder, :Elevator, :Flaps]]) / 20 |> transpose
    outputs = Matrix{Float32}(training_data[:, [:CFx, :CFy, :CFz, :CMx, :CMy, :CMz]]) |> transpose
    
    split = Int(floor(0.8*size(inputs, 2)))
    
    train_data = Flux.DataLoader((inputs[:,1:split], outputs[:,1:split]) |> gpu, batchsize=256, shuffle=true)
    
    test_data = (inputs[:,split:end], outputs[:,split:end])

    return train_data, test_data
end

@load "training_data_20_deg_radius.jld2" training_data

filter!(row -> row[:CMx] .|> abs .|> log10 < -1, training_data)
filter!(row -> row[:CMy] .|> abs .|> log10 < 0, training_data)
filter!(row -> row[:CMz] .|> abs .|> log10 < -1.5, training_data)
training_data.ReCref = log10.(training_data.ReCref)

inputs = Matrix{Float32}(training_data[:, [:AoA, :Beta, :ReCref, :Ailerons, :Rudder, :Elevator, :Flaps]]) / 20 |> transpose
outputs = Matrix{Float32}(training_data[:, [:CFx, :CFy, :CFz, :CMx, :CMy, :CMz]]) |> transpose

split = Int(floor(0.8*size(inputs, 2)))

train_data = Flux.DataLoader((inputs[:,1:split], outputs[:,1:split]), batchsize=1024, shuffle=true)

test_data_in = inputs[:,split:end]
test_data_out = outputs[:,split:end]

model = Chain(
    Dense(7 => 256, leakyrelu),
    Dense(256 => 128, leakyrelu),
    Dense(128 => 64, leakyrelu),
    Dense(64 => 6),
) |> gpu

optim = Flux.setup(Flux.Adam(0.0001), model)# will store optimiser momentum, etc.

# Training loop, using the whole data set 1000 times:
losses = []
@showprogress for epoch in 1:10_000
    for (x, y) in train_data
        loss, grads = Flux.withgradient(model) do m
            # Evaluate model and loss inside gradient context:
            y_hat = m(x)
            # Flux.mse(y_hat, y)
            (y_hat .- y)  ./ y .|> abs |> mean
        end
        Flux.update!(optim, model, grads[1])
        push!(losses, loss)  # logging, outside gradient context
    end
end

# optim # parameters, momenta and output have all changed
model_data_out = model(test_data_in)  # first row is prob. of true, second row p(false)

(model_data_out .- test_data_out)  ./ test_data_out .|> abs |> mean
((model_data_out .- test_data_out) ./ test_data_out).^2 |> mean
(model_data_out .- test_data_out)  ./ test_data_out |> norm
Flux.mse(model_data_out, test_data_out)

plot(losses .|> log10)