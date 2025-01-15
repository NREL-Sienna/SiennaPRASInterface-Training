###########################################
# Add Required Packages
###########################################
import PowerSystems
import PowerSystemCaseBuilder
import CSV
import DataFrames
import TimeSeries: TimeArray
import Dates: DateTime, Hour, TimePeriod
import TypeTree: tt 

const PSY = PowerSystems
const PSCB = PowerSystemCaseBuilder

##############################################
# Converting FOR and MTTR to λ and μ
##############################################
function rate_to_probability(for_gen::Float64, mttr::Int64)
    if (for_gen > 1.0)
        for_gen = for_gen / 100
    end

    if ~(mttr == 0)
        μ = 1 / mttr
    else # MTTR of 0.0 doesn't make much sense.
        μ = 1.0
    end
    λ = (μ * for_gen) / (1 - for_gen)

    return (λ=λ, μ=μ)
end

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
    λ, μ = rate_to_probability(row.FOR, row["MTTR Hr"])
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

PSY.to_json(rts_da_sys, "System_data/RTS_GMLC_DA_with_static_outage_data.json", pretty = true)