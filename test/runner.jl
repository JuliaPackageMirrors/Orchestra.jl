# Run all tests.
module TestRunner
  using FactCheck
  using Orchestra.System

  include("test_abstractlearner.jl")
  include("test_util.jl")
  include(joinpath("julia", "test_decisiontree.jl"))
  include(joinpath("orchestra", "test_ensemble.jl"))
  if HAS_SKL
    include(joinpath("python", "test_scikit_learn.jl"))
  else
    info("Skipping scikit-learn tests.")
  end
  if HAS_CRT
    include(joinpath("r", "test_caret.jl"))
  else
    info("Skipping CARET tests.")
  end
  include("test_system.jl")

  exitstatus()
end # module
