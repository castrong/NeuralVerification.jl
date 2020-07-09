"""
    Run a set of benchmarks on a variety of query files
"""
function test_query_file(file_name::String)
    path, file = splitdir(file_name)
    @testset "Correctness Tests on $(file)" begin
        queries = readlines(file_name)
        for (index, line) in enumerate(queries)
            println("Testing on line: ", line)
            @testset "Test on line: $index" begin
                cur_problem = NeuralVerification.query_line_to_problem(line; base_dir="$(@__DIR__)/../")
                solvers = NeuralVerification.get_valid_solvers(cur_problem)

                # Solve the problem with each solver that applies for the problem, then compare the results
                results = []
                for solver in solvers
                    println("Solving on: ", typeof(solver))
                    if ((solver isa NeuralVerification.ConvDual || solver isa NeuralVerification.FastLip)) && cur_problem.output isa NeuralVerification.HalfSpace
                        println("output is: ", typeof(cur_problem.output))
                        cur_problem = Problem(cur_problem.network, cur_problem.input, HPolytope([cur_problem.output])) # convert to a HPolytope b/c ConvDual takes in a HalfSpace as a HPolytope for now
                    end
                    push!(results, NeuralVerification.solve(solver, cur_problem))
                    println("Result: ", results[end])
                end

                # Just sees if each pair agrees
                # if one or both return unknown then we can't make a comparison
                println("Starting comparisons")
                for (i, j) in [(i, j) for i = 1:length(solvers) for j = (i+1):length(solvers)]
                    @testset "Comparing $(typeof(solvers[i])) with $(typeof(solvers[j]))" begin
                        solver_one_complete = NeuralVerification.is_complete(solvers[i])
                        solver_two_complete = NeuralVerification.is_complete(solvers[j])
                        println("Comparing ", i, " to ", j)
                        # Both complete
                        if (solver_one_complete && solver_two_complete)
                            # Results match
                            @test results[i].status == results[j].status
                        # Solver one complete, solver two incomplete
                        elseif (solver_one_complete && !solver_two_complete)
                            # Results match or solver two unknown or solver one holds solver two violated (bc incomplete)
                            @test ((results[i].status == results[j].status) || (results[j].status == :unknown) || (results[i].status == :holds && results[j].status == :violated))
                        # Solver one incomplete, solver two complete
                        elseif (!solver_one_complete && solver_two_complete)
                            # Results match or solver one unknown or solver two holds solver one violated (bc incomplete)
                            @test ((results[i].status == results[j].status) || (results[i].status == :unknown) || ((results[i].status == :violated) && (results[j].status == :holds)))
                        # Neither are complete
                        else
                            # Results match or solver one unknown or solver two unknown or
                            # no test since any mix of outcomes could be justified with two incomplete ones
                        end
                    end
                end
            end
        end
    end
end

file_name_small = "$(@__DIR__)/../test/test_sets/random/small/query_file_small.txt"
file_name_medium = "$(@__DIR__)/../test/test_sets/random/small/query_file_medium.txt"
file_name_large = "$(@__DIR__)/../test/test_sets/random/small/query_file_large.txt"

println("Starting test on small")
test_query_file(file_name_small)
println("Starting test on medium")
test_query_file(file_name_medium)
println("Starting test on large")
test_query_file(file_name_large)
