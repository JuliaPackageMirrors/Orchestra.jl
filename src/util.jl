# Various functions that work with learners.
module Util

importall Orchestra.Structures
importall Orchestra.Types
import MLBase: Kfold
import DataFrames: isna, NA

export holdout,
       kfold,
       score,
       infer_eltype,
       infer_var_type,
       orchestra_isna,
       nested_dict_to_tuples,
       nested_dict_set!,
       nested_dict_merge,
       create_transformer

# Holdout method that partitions a collection
# into two partitions.
#
# @param n Size of collection to partition.
# @param right_prop Percentage of collection placed in right partition.
# @return Two partitions of indices, left and right.
function holdout(n, right_prop)
  shuffled_indices = randperm(n)
  partition_pivot = int(right_prop * n)
  right = shuffled_indices[1:partition_pivot]
  left = shuffled_indices[partition_pivot+1:end]
  return (left, right)
end

# Returns k-fold partitions.
#
# @param num_instances Total number of instances.
# @param num_partitions Number of partitions required.
# @return Returns training set partition.
function kfold(num_instances, num_partitions)
  return collect(Kfold(num_instances, num_partitions))
end

# Score learner predictions against ground truth values.
#
# Available metrics:
# - :accuracy
#
# @param metric Metric to assess with.
# @param actual Ground truth values.
# @param predicted Predicted values.
# @return Score of learner.
function score(metric::Symbol, actual, predicted)
  if metric == :accuracy
    mean(actual .== predicted) * 100.0
  else
    error("Metric $metric not implemented for score.")
  end
end

# Returns inferred element type of array.
# If it cannot be determined, will return collection's element type.
#
# @param ar Array to infer element type on.
# @return Inferred element type.
function infer_eltype(ar::Array)
  el_type = None
  for el in ar
    el_type = typejoin(el_type, typeof(el))
  end
  if el_type == None
    el_type = eltype(ar)
  end
  return el_type
end

# Returns inferred variable type of array.
#
# @param ar Array to infer variable type on.
# @return Inferred variable type.
function infer_var_type(ar::AbstractArray)
  na_mask = orchestra_isna(ar)
  na_less_ar = ar[!na_mask]
  el_type = infer_eltype(na_less_ar)
  if el_type <: None
    error("Cannot infer variable type for empty array")
  elseif el_type <: Real
    return NumericVar()
  elseif el_type <: Symbol || el_type <: String
    return NominalVar(unique(na_less_ar))
  else
    error("Cannot infer variable type for: $(el_type)")
  end
end
# Returns if elements are NA or NaN.
orchestra_isna(ar::AbstractArray) = Bool[orchestra_isna(x) for x in ar]
orchestra_isna(x) = isna(x) || typeof(x) <: FloatingPoint && isnan(x)

# Converts nested dictionary to set of tuples
#
# @param dict Dictionary that can have other dictionaries as values.
# @return Set where elements are ([outer-key, inner-key, ...], value).
function nested_dict_to_tuples(dict::Dict)
  set = Set()
  for (entry_id, entry_val) in dict
    if typeof(entry_val) <: Dict
      inner_set = nested_dict_to_tuples(entry_val)
      for (inner_entry_id, inner_entry_val) in inner_set
        new_entry = (vcat([entry_id], inner_entry_id), inner_entry_val)
        push!(set, new_entry)
      end
    else
      new_entry = ([entry_id], entry_val)
      push!(set, new_entry)
    end
  end
  return set
end

# Set value in a nested dictionary.
#
# @param dict Nested dictionary to assign value.
# @param keys Keys to access nested dictionaries in sequence.
# @param value Value to assign.
function nested_dict_set!{T}(dict::Dict, keys::Array{T, 1}, value)
  inner_dict = dict
  for key in keys[1:end-1]
    inner_dict = inner_dict[key]
  end
  inner_dict[keys[end]] = value
end

# Second nested dictionary is merged into first.
# 
# If a second dictionary's value as well as the first
# are both dictionaries, then a merge is conducted between
# the two inner dictionaries. 
# Otherwise the second's value overrides the first.
#
# @param first First nested dictionary.
# @param second Second nested dictionary.
# @return Merged nested dictionary.
function nested_dict_merge(first::Dict, second::Dict)
  target = copy(first)
  for (second_key, second_value) in second
    values_both_dict = 
      typeof(second_value) <: Dict && 
      typeof(get(target, second_key, nothing)) <: Dict
    if values_both_dict
      target[second_key] = nested_dict_merge(target[second_key], second_value)
    else
      target[second_key] = second_value
    end
  end
  return target
end

# Create transformer
# 
# @param prototype Prototype transformer to base new transformer on.
# @param options Additional options to override prototype's options.
# @return New transformer.
function create_transformer(prototype::Transformer, options=nothing)
  new_options = copy(prototype.options)
  if options != nothing
    new_options = nested_dict_merge(new_options, options)
  end

  prototype_type = typeof(prototype)
  return prototype_type(new_options)
end

end # module
