
"""
    mult_chan_pattern_detector_probability_meanfilter(erp_data::Array{Float64, 3}, stat_function::Function, events::DataFrame; n_permutations = 10)

Pattern detector.\\
Method:\\
- For each channel permute data `n_permutations` of times.\\
- For each permuted data use filter for smearing.\\
- Use pattern dection function.\\
- Average all this datasets in one. That how we get random data with no pattern: noerp\\_data.\\
- Take the the data where we expect to find a pattern: erp\\_data. Sort its trials by experimental condition.\\
- Smear and use pattern detection function.\\
- Find absolute difference of values between erp\\_data and noerp\\_data.\\
- Do it for each channel and each variable.\\

## Arguments

- `erp_data::Array{Float64, 3}`\\
    3-dimensional Array of voltages of Event-related potentials. Dimensions: channels, time of recording, trials. 
- `stat_function::Function`\\
    Function used for pattern detection.\\
    For instance, `Images.entropy` form `Images.jl`.
- `events::DataFrame`\\
    DataFrame with columns of experimental events and rows with trials. Each value is an event value in a trial.
- `kwargs...`\\
    Additional styling behavior. \\

## Keyword arguments (kwargs)
- `n_permutations::Number = 10` \\
    Number fo permutations of the algorithm.

**Return Value:** DataFrame with pattern detection values. Dimensions: experimental events, trials.
"""
function mult_chan_pattern_detector_probability_meanfilter(
    erp_data::Array{Float64,3},
    stat_function::Function,
    events::DataFrame;
    n_permutations = 10,
)
    row = Dict()
    @debug "starting"

    dat_permuted = permutedims(erp_data, (1, 3, 2))
    dat_filtered = similar(erp_data, 20, size(dat_permuted, 3))
    d_perm = similar(erp_data, size(erp_data, 1), n_permutations)
    @debug "starting permutation loop"
    # We permute data for all events in advance
    pbar = ProgressBar(total = size(erp_data, 1))
    Threads.@threads for ch = 1:size(erp_data, 1)
        for perm = 1:n_permutations
            sortix = shuffle(1:size(dat_permuted, 2)) # a vector of indecies
            d_perm[ch, perm] = stat_function(
                mean_filter!(dat_filtered, @view(dat_permuted[ch, sortix, :])),
            )
        end
        update(pbar)
    end
    mean_d_perm = mean(d_perm, dims = 2)[:, 1]

    pbar = ProgressBar(total = length(names(events)))
    Threads.@threads for n in names(events)
        sortix = sortperm(events[!, n])
        col = fill(NaN, size(erp_data, 1))
        for ch = 1:size(erp_data, 1)
            mean_filter!(dat_filtered, @view(dat_permuted[ch, sortix, :]))
            d_emp = stat_function(dat_filtered)
            col[ch] = abs(d_emp - mean_d_perm[ch])
        end
        row[n] = get(row, n, col) # add new key in dict
        update(pbar)
    end
    return DataFrame(row)
end

function mean_filter(dat; output_dim = 20)
    mean_filter!(similar(dat, output_dim, size(dat, 2)), dat)
end

function mean_filter!(dat_filtered, dat)
    n_out = size(dat_filtered, 1)
    dat_nrows = size(dat, 1)
    bins = Int.(round.(collect(range(1, stop = dat_nrows, length = n_out + 1))))
    bins[1] = 1
    bins[end] = dat_nrows
    for b = 1:length(bins)-1
        bin_start = bins[b]
        bin_stop = bins[b+1]
        dat_filtered[b, :] .= mean(@view(dat[bin_start:bin_stop, :]), dims = 1)[1, :]
    end
    return dat_filtered
end
