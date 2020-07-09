using Random

"""
    make_random_network(layer_sizes::Vector{Int}, [min_weight = -1.0], [max_weight = 1.0], [min_bias = -1.0], [max_bias = 1.0], [rng = 1.0])
    read_layer(output_dim::Int, f::IOStream, [act = ReLU()])

Generate a network with random weights and bias. The first layer is treated as the input.
The values for the weights and bias will be uniformly drawn from the range between min_weight
and max_weight and min_bias and max_bias respectively. The last layer will have an ID()
activation function and the rest will have ReLU() activation functions. Allow a random number
generator(rng) to be passed in. This allows for seeded random network generation.
"""
function make_random_network(layer_sizes::Vector{Int}, min_weight = -1.0, max_weight = 1.0, min_bias = -1.0, max_bias = 1.0, rng=MersenneTwister())
    # Create each layer based on the layer_size
    layers = []
    for index in 1:(length(layer_sizes)-1)
        cur_size = layer_sizes[index]
        next_size = layer_sizes[index+1]
        # Use Id activation for the last layer - otherwise use ReLU activation
        if index == (length(layer_sizes)-1)
            cur_activation = NeuralVerification.Id()
        else
            cur_activation = NeuralVerification.ReLU()
        end

        # Dimension: num_out x num_in
        cur_weights = min_weight .+ (max_weight - min_weight) * rand(rng, Float64, (next_size, cur_size))
        cur_weights = reshape(cur_weights, (next_size, cur_size)) # for edge case where 1 dimension is equal to 1 this keeps it from being a 1-d vector

        # Dimension: num_out x 1
        cur_bias = min_bias .+ (max_bias - min_bias) * rand(rng, Float64, (next_size))
        push!(layers, NeuralVerification.Layer(cur_weights, cur_bias, cur_activation))
    end

    return Network(layers)
end


"""
    function make_random_query_file(num_networks_for_size::Array{Int, 1},
                                layer_sizes::Array{Array{Int, 1}},
                                network_dir,
                                input_set_dir,
                                output_set_dir,
                                query_file
                                ; [min_weight = -1.0],
                                [max_weight = 1.0],
                                [min_bias = -1.0],
                                [max_bias = 1.0],
                                [rng=MersenneTwister()])


Generates a random query file. num_networks_for_size gives the number of networks
to make for each shape. The network_dir, input_set_dir, output_set_dir, and query_file
variables give the location to write out the files - these will be written relative
to where the function is called from. These relative paths will be stored in the query_file.

An example call would look like:
NeuralVerification.make_random_query_file([3, 3], [[1, 3, 1], [2, 5, 2]], "test_rand/networks", "test_rand/input_sets", "test_rand/output_sets", "test_rand/query_file.txt")

Which will make 3 networks with shape [1, 3, 1] and 3 networks with shape [2, 5, 2].
"""
function make_random_query_file(num_networks_for_size::Array{Int, 1},
                                layer_sizes::Array{Array{Int, 1}},
                                network_dir,
                                input_set_dir,
                                output_set_dir,
                                query_file
                                ; min_weight = -1.0,
                                max_weight = 1.0,
                                min_bias = -1.0,
                                max_bias = 1.0,
                                rng=MersenneTwister())

    for (num_networks, layer_sizes) in zip(num_networks_for_size, layer_sizes)
        index = 0
        for i = 1:num_networks
            index = index + 1
            # Create a random network
            network = make_random_network(layer_sizes, min_weight, max_weight, min_bias, max_bias, rng)
            num_inputs = layer_sizes[1]
            num_outputs = layer_sizes[end]

            # Create several input sets and a variety of corresponding output sets.
            halfspace_output = HalfSpace(rand(num_outputs) .- 0.5, rand() - 0.5)

            hyperrectangle_input_center = rand(num_inputs) .- 0.5
            hyperrectangle_input_radius = rand(num_inputs)
            hyperrectangle_input = Hyperrectangle(hyperrectangle_input_center, hyperrectangle_input_radius)

            hyperrcube_input_radius = rand() * ones(num_inputs)
            hypercube_input = Hyperrectangle(hyperrectangle_input_center, hyperrcube_input_radius)

            hyperrectangle_output_center = rand(num_outputs) .- 0.5
            hyperrectangle_output_radius = rand(num_outputs)
            hyperrectangle_output = Hyperrectangle(hyperrectangle_output_center, hyperrectangle_output_radius)

            hpolytope_in_one  = convert(HPolytope, hyperrectangle_input)
            hpolytope_out_one = convert(HPolytope, hyperrectangle_output)

            polytopecomplement_in_one = PolytopeComplement(hpolytope_in_one)
            polytopecomplement_out_one = PolytopeComplement(hpolytope_out_one)

            # Add rotated hyperrectangle as well

            # Ignore zonotopes for now

            # Create a problem with HP/HP, HR/PC, HR(uniform)/HS, HR/HS, HR/HR, HR/PC
            hp_hp_problem = Problem(network, hpolytope_in_one, hpolytope_out_one)
            hr_pc_problem = Problem(network, hyperrectangle_input, polytopecomplement_out_one)
            hr_uniform_hs_problem = Problem(network, hypercube_input, halfspace_output)
            hr_hs_problem = Problem(network, hyperrectangle_input, halfspace_output)
            hr_hr_problem = Problem(network, hyperrectangle_input, hyperrectangle_output)
            hr_pc_problem = Problem(network, hyperrectangle_input, polytopecomplement_out_one)

            problems = [hp_hp_problem, hr_pc_problem, hr_uniform_hs_problem, hr_hs_problem, hr_hr_problem, hr_pc_problem]
            identifier_string = replace(string(layer_sizes, "_", index), " "=>"") # remove all spaces

            base_filenames = string.(["hp_hp_", "hr_pc_", "hr_uniform_hs", "hr_hs_", "hr_hr_", "hr_pc_"], identifier_string)
            network_filenames = joinpath.(network_dir, fill("rand_"*identifier_string*".nnet", length(problems))) # all use the same network
            input_filenames = joinpath.(input_set_dir, base_filenames.*"_inputset.json")
            output_filenames = joinpath.(output_set_dir, base_filenames.*"_outputset.json")

            println(network_filenames)
            println(input_filenames)
            println(output_filenames)

            write_problem.(network_filenames, input_filenames, output_filenames, problems; query_file=query_file)
        end

    end
end


"""
    function make_random_test_set()

A function that generates the set of random query files to be used in testing.
"""
function make_random_test_sets()
    NeuralVerification.make_random_query_file([3, 3],
                                              [[1, 3, 1], [2, 5, 2]],
                                              "test/test_sets/random/small/networks",
                                              "test/test_sets/random/small/input_sets",
                                              "test/test_sets/random/small/output_sets",
                                              "test/test_sets/random/small/query_file_small.txt")

    NeuralVerification.make_random_query_file([5, 5, 5],
                                              [[1, 8, 1], [4, 8, 4], [1, 10, 4, 1]],
                                              "test/test_sets/random/medium/networks",
                                              "test/test_sets/random/medium/input_sets",
                                              "test/test_sets/random/medium/output_sets",
                                              "test/test_sets/random/medium/query_file_medium.txt")

    NeuralVerification.make_random_query_file([5, 5, 5, 5, 5],
                                              [[1, 10, 12, 10, 1], [3, 8, 12, 10, 5], [10, 3, 2], [3, 4, 3], [6, 8, 1]],
                                              "test/test_sets/random/large/networks",
                                              "test/test_sets/random/large/input_sets",
                                              "test/test_sets/random/large/output_sets",
                                              "test/test_sets/random/large/query_file_large.txt")



end

function write_to_query_file(network_file::String, input_file::String, output_file::String, query_file::String)
    mkpath(dirname(query_file))
    open(query_file, "a") do f
        println(f, string(network_file, " ", input_file, " ", output_file))
    end
end

"""
    write_problem(network_file::String, input_file::String, output_file::String, problem::Problem; [query_file = ""])

Write a the information from a problem to files. The input set, output set, and network will
each be written to a separate file. If a query file is given it will append this test to the corresponding query file
"""
function write_problem(network_file::String, input_file::String, output_file::String, problem::Problem; query_file="")
    write_nnet(network_file, problem.network)
    write_set(input_file, problem.input)
    write_set(output_file, problem.output)

    # If a query file is given, append this problem to the file by writing out
    # the network file, input file, and output file names
    if query_file != ""
        write_to_query_file(network_file, input_file, output_file, query_file)
    end
end


"""
    get_set_type_string(set::Union{PolytopeComplement, LazySet})

Return a string corresponding to the object's type. This will be used to store
these sets to file.
"""
function get_set_type_string(set::Union{PolytopeComplement, LazySet})
    if set isa HalfSpace
        return "HalfSpace"
    elseif set isa Hyperrectangle
        return "Hyperrectangle"
    elseif set isa HPolytope
        return "HPolytope"
    elseif set isa PolytopeComplement
        return "PolytopeComplement"
    elseif set isa Zonotope
        return "Zonotope"
    else
        return ""
    end
end

"""
    write_set(filename::String, set::Union{PolytopeComplement, LazySet})

Write a set in JSON format to a file along with its type. This supports HalfSpace, Hyperrectangle,
HPolytope, PolytopeComplement, and Zonotope objects.
"""
function write_set(filename::String, set::Union{PolytopeComplement, LazySet})
    # Only support hyperrectangle, hyperpolytope, zonotope, polytope complement, and halfspace
    type_string = get_set_type_string(set)
    @assert type_string != ""

    # Save the type and the object itself
    output_dict = Dict()
    output_dict["type"] = type_string
    output_dict["set"] = set

    # Write to file
    mkpath(dirname(filename))
    open(filename, "w") do f
        JSON2.write(f, output_dict)
    end
end


"""
    read_problem(network_file::String, input_file::String, output_file::String)

Take in a network, input set, and output set and return the corresponding problem.
"""
function read_problem(network_file::String, input_file::String, output_file::String)
    network = read_nnet(network_file)
    input_set = read_set(input_file)
    output_set = read_set(output_file)
    return Problem(network, input_set, output_set)
end

"""
    read_set(filename::String)

Read in a set from a file. This supports HalfSpace, Hyperrectangle,
HPolytope, PolytopeComplement, and Zonotope objects.
"""
function read_set(filename::String)
    json_string = read(filename, String)
    dict = JSON2.read(json_string)
    type = dict[:type]
    set = dict[:set]

    # helper function to convert from Any arrays to Float arrays
    function convert_float(elem)
        if elem isa Array
            return convert(Array{Float64}, elem)
        else
            return convert(Float64, elem)
        end
    end

    if type == "HalfSpace"
        return HalfSpace(convert_float(set[:a]), convert_float(set[:b]))
    elseif type == "Hyperrectangle"
        return Hyperrectangle(convert_float(set[:center]), convert_float(set[:radius]))
    elseif type == "HPolytope"
        constraints = set[:constraints]
        half_spaces = [HalfSpace(convert_float(constraints[i][:a]), convert_float(constraints[i][:b])) for i = 1:length(constraints)]
        return HPolytope(half_spaces)
    elseif type == "PolytopeComplement"
        constraints = set[:P][:constraints]
        half_spaces = [HalfSpace(convert_float(constraints[i][:a]), convert_float(constraints[i][:b])) for i = 1:length(constraints)]
        return PolytopeComplement(HPolytope(half_spaces))
    elseif type == "Zonotope"
        center = set[:center]
        generator_list = set[:generators]
        generator_matrix = reshape(generator_list, (length(center), :)) # Check the reshape here
        return Zonotope(convert_float(center), convert_float(generator_matrix))
    else
        @assert false
    end
end


"""
function query_line_to_problem(line::String)

Take in a line from a query file and read in then return the corresponding problem.
This line will be in the format:
some/path/network.nnet other/path/input_set.json third/path/output_set.json

It splits it apart by spaces then reads in the problem.
"""
function query_line_to_problem(line::String; base_dir="")
    network_file, input_file, output_file = string.(split(line, " "))
    return read_problem(joinpath(base_dir, network_file), joinpath(base_dir, input_file), joinpath(base_dir, output_file))
end

"""
    get_valid_solvers(problem::Problem, solvers = get_all_solvers_to_test())

Return a list of valid instantitated solvers for a particular problem. This will depend
on compatibility with the input set, output set, and network.

If a list of solvers is given, it filters that list. Otherwise, it gets a default list
from get_all_solvers_to_test() and uses that list of solvers.
"""
function get_valid_solvers(problem::Problem, solvers = get_all_solvers_to_test())
    # Get all solvers, then filter out those that don't work
    # with the input set, output set, or network
    return filter(solver->solver_works_with_input_set(solver, problem.input)
            && solver_works_with_output_set(solver, problem.output)
            && solver_works_with_network(solver, problem.network), solvers)
end

"""
    solver_works_with_input_set(solver, input_set)

Return true if the solver can handle the input given by input_set.
Return false otherwise.
"""
function solver_works_with_input_set(solver, input_set)
    half_space_solver_types = Union{}
    hyperrectangle_solver_types = Union{NSVerify, MIPVerify, ILP, Duality, ConvDual, Certify, FastLin, FastLip, ReluVal, DLV, Sherlock, BaB, Planet, Reluplex}
    hyperpolytope_solver_types = Union{ExactReach, Ai2, MaxSens}
    polytope_complement_solver_types = Union{}
    zonotope_solver_types = Union{}

    if input_set isa HalfSpace
        return solver isa half_space_solver_types
    elseif input_set isa Hyperrectangle
        # Duality and ConvDual require uniform HR (hypercube) input set
        if (solver isa Union{Duality, ConvDual})
            return all(iszero.(input_set.radius .- input_set.radius[1]))
        else
            return solver isa hyperrectangle_solver_types
        end
    elseif input_set isa HPolytope
        return solver isa hyperpolytope_solver_types
    elseif input_set isa PolytopeComplement
        return solver isa polytope_complement_solver_types
    elseif input_set isa Zonotope
        return solver isa zonotope_solver_types
    else
        println("Unsupported input set")
        @assert false
    end
end

"""
    solver_works_with_output_set(solver, output_set)

Return true if the solver can handle the output given by output_set.
Return false otherwise.
"""
function solver_works_with_output_set(solver, output_set)
    half_space_solver_types = Union{Duality, ConvDual, Certify, FastLin, FastLip}
    hyperrectangle_solver_types = Union{ReluVal, DLV, Sherlock, BaB}
    hyperpolytope_solver_types = Union{ExactReach, Ai2, MaxSens}
    polytope_complement_solver_types = Union{NSVerify, MIPVerify, ILP, Planet, Reluplex}
    zonotope_solver_types = Union{}

    if output_set isa HalfSpace
        return solver isa half_space_solver_types
    elseif output_set isa Hyperrectangle
        # For DLV, Sherlock, and BaB it must be 1-D
        if (solver isa Union{DLV, Sherlock, BaB})
            return length(output_set.center) == 1
        else
            return solver isa hyperrectangle_solver_types
        end
    elseif output_set isa HPolytope
        # We will assume that the polytope is bounded
        return solver isa hyperpolytope_solver_types
    elseif output_set isa PolytopeComplement
        return solver isa polytope_complement_solver_types
    elseif output_set isa Zonotope
        return solver isa zonotope_solver_types
    else
        println("Unsupported output set")
        @assert false
    end
end

"""
    solver_work_with_network(solver, network)

Return true if the solver can handle the network given by network.
Return false otherwise.
"""
function solver_works_with_network(solver, network)
    if (solver isa Certify)
        return length(network.layers) == 2 # certify only works with 1 hidden layer
    else
        return true
    end
end

"""
    get_all_solvers_to_test()

Return all solver configurations that we'd like to test
"""
function get_all_solvers_to_test()
    return [
            ExactReach(),
            Ai2(),
            MaxSens(resolution = 0.6),
            NSVerify(),
            MIPVerify(),
            ILP(),
            Duality(),
            ConvDual(),
            Certify(),
            FastLin(),
            FastLip(),
            ReluVal(max_iter = 10),
            DLV(),
            Sherlock(ϵ = 0.5),
            BaB(),
            Planet(),
            Reluplex()
            ]
end

"""
    is_complete(solver)

Return whether a solver is complete or not.
"""
function is_complete(solver)
    complete_solvers = Union{ExactReach, NSVerify, MIPVerify, ReluVal, DLV, Planet, Reluplex}
    return solver isa complete_solvers
end
