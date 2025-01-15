###########################################
# Add Required Packages
###########################################
import PowerSystems
import PowerSystemCaseBuilder
import CSV
import DataFrames
import TimeSeries
import Dates
import TypeTree: tt
import SiennaPRASInterface

const PSY = PowerSystems
const PSCB = PowerSystemCaseBuilder
const TS = TimeSeries
const SPI = SiennaPRASInterface
##############################################
# SupplementalAttributes and Sienna\Data way 
# of handling outage data
##############################################
docs_dir = joinpath(pkgdir(PowerSystems), "docs", "src", "tutorials", "utils");
include(joinpath(docs_dir, "docs_utils.jl"));
print(join(tt(PSY.SupplementalAttribute), ""))

###########################################
# Augment RTS-GMLC System with outage data so
# we can use SiennaPRASInterface.jl to run RA
# analysis
# Step 1: Build RTS-GMLC System using PSCB
###########################################
rts_da_sys = PSCB.build_system(PSCB.PSISystems, "RTS_GMLC_DA_sys");
PSY.set_units_base_system!(rts_da_sys, "natural_units")

###########################################
# Step 2: Parse the gen.csv and add OutageData 
# SupplementalAttribute to components for 
# which we have this data 
###########################################
gen_for_data = CSV.read("gen.csv", DataFrames.DataFrame);

for row in DataFrames.eachrow(gen_for_data)
    λ, μ = SPI.rate_to_probability(row.FOR, row["MTTR Hr"])
    transition_data = PSY.GeometricDistributionForcedOutage(;
        mean_time_to_recovery=row["MTTR Hr"],
        outage_transition_probability=λ,
    )
    comp = PSY.get_component(PSY.Generator, rts_da_sys, row["GEN UID"])

    if ~(isnothing(comp))
        PSY.add_supplemental_attribute!(rts_da_sys, comp, transition_data)
        @info "Added outage data supplemental attribute to $(row["GEN UID"]) generator"
    else
        @warn "$(row["GEN UID"]) generator doesn't exist in the System."
    end
end

# Show SupplementalAttribute
first(
    PSY.get_supplemental_attributes(
        PSY.GeometricDistributionForcedOutage,
        first(PSY.get_available_components(PSY.ThermalGen, rts_da_sys)),
    ),
)

PSY.to_json(rts_da_sys, "System_data/RTS_GMLC_DA_with_static_outage_data.json", pretty=true)

# Adding time series of to RTS System
#rts_sys = PSY.System("System_Data/RTS_GMLC_DA_with_static_outage_data.json", time_series_directory = "System_Data/ts_temp/");
rts_test_outage_ts_data =
    CSV.read("RTS_Test_Outage_Time_Series_Data.csv", DataFrames.DataFrame);

# Time series timestamps
filter_func = x -> (typeof(x) <: PSY.StaticTimeSeries)
all_ts = PSY.get_time_series_multiple(rts_da_sys, filter_func)
ts_timestamps = TS.timestamp(first(all_ts).data)
first_timestamp = first(ts_timestamps)

# Add λ and μ time series 
for row in DataFrames.eachrow(rts_test_outage_ts_data)
    comp = PSY.get_component(PSY.Generator, rts_da_sys, row.Unit)
    λ_vals = Float64[]
    μ_vals = Float64[]
    for i in range(0, length=12)
        next_timestamp = first_timestamp + Dates.Month(i)
        λ, μ = SPI.rate_to_probability(row[3 + i], 48)
        append!(λ_vals, fill(λ, (Dates.daysinmonth(next_timestamp) * 24)))
        append!(μ_vals, fill(μ, (Dates.daysinmonth(next_timestamp) * 24)))
    end
    PSY.add_time_series!(
        rts_da_sys,
        first(PSY.get_supplemental_attributes(PSY.GeometricDistributionForcedOutage, comp)),
        PSY.SingleTimeSeries(
            "outage_probability",
            TimeSeries.TimeArray(ts_timestamps, λ_vals),
        ),
    )
    PSY.add_time_series!(
        rts_da_sys,
        first(PSY.get_supplemental_attributes(PSY.GeometricDistributionForcedOutage, comp)),
        PSY.SingleTimeSeries(
            "recovery_probability",
            TimeSeries.TimeArray(ts_timestamps, μ_vals),
        ),
    )
    @info "Added outage probability and recovery probability time series to supplemental attribute of $(row["Unit"]) generator"
end

# Show SupplementalAttribute
supp_attr = first(
    PSY.get_supplemental_attributes(
        PSY.GeometricDistributionForcedOutage,
        first(PSY.get_available_components(PSY.ThermalGen, rts_da_sys)),
    ),
)
PSY.get_time_series_array(PSY.SingleTimeSeries, supp_attr, "outage_probability")

PSY.to_json(rts_da_sys, "System_data/RTS_GMLC_DA_with_outage_ts_data.json", pretty=true)
