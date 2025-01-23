# Add Required Packages
import SiennaPRASInterface
import PowerSystems
import XLSX
import DataFrames
import StringDistances
import StatsBase
import TimeSeries
import Dates

const SPI = SiennaPRASInterface
const SPI_CC = SPI.PRAS.CapacityCredit
const PSY = PowerSystems
const DF = DataFrames
const SD = StringDistances
const SB = StatsBase
const TS = TimeSeries

# Stop function to stop parsing the XLSX sheet
function stop_function(r)
    v = r[:Unit]
    return ismissing(v)
end

# Load G100 Latest System from disk
sys = PSY.System(
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442.json",
    runchecks=false,
);

# Add static FOR and MTTR as SupplementalAttributes to G100 System
# Use average of monthly FOR's of Guam generators and 48 hours as MTTR
outage_data_1 = DataFrames.DataFrame(
    XLSX.readtable(
        "Gen_data/EFOR Analysis and Charts (RM).xlsx",
        "EFOR Summaries",
        infer_eltypes=true,
        first_row=3,
        stop_in_row_function=stop_function,
    ),
);
outage_data_2 = DataFrames.DataFrame(
    XLSX.readtable(
        "Gen_data/EFOR Analysis and Charts (RM).xlsx",
        "EFOR Summaries",
        infer_eltypes=true,
        first_row=27,
        stop_in_row_function=stop_function,
    ),
);

thermal_gens = PSY.get_components(PSY.get_available, PSY.ThermalGen, sys)

thermal_gen_mapping = Dict{String, String}()

for row in DataFrames.eachrow(outage_data_1)
    gen_name = row.Unit
    matching_gen_name =
        if (
            gen_name ∈
            ["Piti (MEC) Unit #9", "Piti Unit #7 (TEMES) CT", "Yigo (Aggreko) Diesels"]
        )
            if (gen_name == "Piti (MEC) Unit #9")
                "MEC #9"
            elseif (gen_name == "Piti Unit #7 (TEMES) CT")
                "TEMES"
            else
                "Aggreko"
            end
        else
            SD.findnearest(
                gen_name,
                PSY.get_name.(thermal_gens),
                StringDistances.TokenSet(StringDistances.Levenshtein()),
            )[1]
        end

    push!(thermal_gen_mapping, gen_name => matching_gen_name)
end

# Adding static FOR and MTTR from Four-Year Monthly Average
# Using 48 hr MTTR
for row in DataFrames.eachrow(outage_data_1)
    λ, μ = SPI.rate_to_probability(SB.mean(row[3:end]), 48)
    transition_data = PSY.GeometricDistributionForcedOutage(;
        mean_time_to_recovery=48,
        outage_transition_probability=λ,
    )
    comp = PSY.get_component(PSY.Generator, sys, thermal_gen_mapping[row.Unit])

    if ~(isnothing(comp))
        PSY.add_supplemental_attribute!(sys, comp, transition_data)
        @info "Added outage data supplemental attribute to $(row["Unit"]) generator"
    else
        @warn "$(row["Unit"]) generator doesn't exist in the System."
    end
end

PSY.to_json(
    sys,
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_Static_FOR.json",
    pretty=true,
)

# Adding Monthly FOR time series data from Four-Year Monthly Average
# First, we need to add static FOR and MTTR from Four-Year Monthly Average
# Using 48 hr MTTR
# Time series timestamps
filter_func = x -> (typeof(x) <: PSY.StaticTimeSeries)
all_ts = PSY.get_time_series_multiple(sys, filter_func)
ts_timestamps = TS.timestamp(first(all_ts).data)
first_timestamp = first(ts_timestamps)

# Add outage_probability and recovery_probability time series 
for row in DataFrames.eachrow(outage_data_1)
    comp = PSY.get_component(PSY.Generator, sys, thermal_gen_mapping[row.Unit])
    λ_vals = Float64[]
    μ_vals = Float64[]
    for i in range(0, length=12)
        next_timestamp = first_timestamp + Dates.Month(i)
        λ, μ = SPI.rate_to_probability(row[3 + i], 48)
        append!(λ_vals, fill(λ, (Dates.daysinmonth(next_timestamp) * 24 * 4)))
        append!(μ_vals, fill(μ, (Dates.daysinmonth(next_timestamp) * 24 * 4)))
    end
    PSY.add_time_series!(
        sys,
        first(PSY.get_supplemental_attributes(PSY.GeometricDistributionForcedOutage, comp)),
        PSY.SingleTimeSeries(
            "outage_probability",
            TimeSeries.TimeArray(ts_timestamps, λ_vals),
        ),
    )
    PSY.add_time_series!(
        sys,
        first(PSY.get_supplemental_attributes(PSY.GeometricDistributionForcedOutage, comp)),
        PSY.SingleTimeSeries(
            "recovery_probability",
            TimeSeries.TimeArray(ts_timestamps, μ_vals),
        ),
    )
    @info "Added outage probability and recovery probability time series to supplemental attribute of $(row["Unit"]) generator"
end

PSY.to_json(
    sys,
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_FOR_ts_4yearAvg.json",
    pretty=true,
)

# Adding static FOR and MTTR from Three-Year Monthly Average
# Using 48 hr MTTR

# Load G100 Latest System from disk
sys = PSY.System(
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442.json",
    runchecks=false,
);

for row in DataFrames.eachrow(outage_data_2)
    λ, μ = SPI.rate_to_probability(SB.mean(row[3:end]), 48)
    transition_data = PSY.GeometricDistributionForcedOutage(;
        mean_time_to_recovery=48,
        outage_transition_probability=λ,
    )
    comp = PSY.get_component(PSY.Generator, sys, thermal_gen_mapping[row.Unit])

    if ~(isnothing(comp))
        PSY.add_supplemental_attribute!(sys, comp, transition_data)
        @info "Added outage data supplemental attribute to $(row["Unit"]) generator"
    else
        @warn "$(row["Unit"]) generator doesn't exist in the System."
    end
end

PSY.to_json(
    sys,
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_Static_FOR_3.json",
    pretty=true,
)

# Adding Monthly FOR time series data from Three-Year Monthly Average
# First, we need to add static FOR and MTTR from Three-Year Monthly Average
# Using 48 hr MTTR

# Time series timestamps
filter_func = x -> (typeof(x) <: PSY.StaticTimeSeries)
all_ts = PSY.get_time_series_multiple(sys, filter_func)
ts_timestamps = TS.timestamp(first(all_ts).data)
first_timestamp = first(ts_timestamps)

# Add outage_probability and recovery_probability time series 
for row in DataFrames.eachrow(outage_data_2)
    comp = PSY.get_component(PSY.Generator, sys, thermal_gen_mapping[row.Unit])
    λ_vals = Float64[]
    μ_vals = Float64[]
    for i in range(0, length=12)
        next_timestamp = first_timestamp + Dates.Month(i)
        λ, μ = SPI.rate_to_probability(row[3 + i], 48)
        append!(λ_vals, fill(λ, (Dates.daysinmonth(next_timestamp) * 24 * 4)))
        append!(μ_vals, fill(μ, (Dates.daysinmonth(next_timestamp) * 24 * 4)))
    end
    PSY.add_time_series!(
        sys,
        first(PSY.get_supplemental_attributes(PSY.GeometricDistributionForcedOutage, comp)),
        PSY.SingleTimeSeries(
            "outage_probability",
            TimeSeries.TimeArray(ts_timestamps, λ_vals),
        ),
    )
    PSY.add_time_series!(
        sys,
        first(PSY.get_supplemental_attributes(PSY.GeometricDistributionForcedOutage, comp)),
        PSY.SingleTimeSeries(
            "recovery_probability",
            TimeSeries.TimeArray(ts_timestamps, μ_vals),
        ),
    )
    @info "Added outage probability and recovery probability time series to supplemental attribute of $(row["Unit"]) generator"
end

PSY.to_json(
    sys,
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_FOR_ts_3yearAvg.json",
    pretty=true,
)
