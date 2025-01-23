# NOTE: Make sure you activate JULIA_NUM_THREADS before you start the repl
# Add Required Packages
import SiennaPRASInterface
import PowerSystems
import StatsBase

const SPI = SiennaPRASInterface
const SPI_CC = SPI.PRAS.CapacityCredit
const PSY = PowerSystems
const SB = StatsBase

sys = PSY.System(
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_Static_FOR.json",
    runchecks=false,
)
# Static FOR Data from Four-Year Average
# Run PRAS using SPI
num_samples = 100000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy = SPI.PRAS.assess(
    sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.PRAS.Shortfall(),
    SPI.PRAS.Surplus(),
    SPI.PRAS.StorageEnergy(),
)
# Access Results
SPI.EUE(shortfall)
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean

# Monthly FOR time series data from Four-Year Monthly Average
sys = PSY.System(
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_FOR_ts_4yearAvg.json",
    runchecks=false,
);

# Run PRAS using SPI
num_samples = 100000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy = SPI.PRAS.assess(
    sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.PRAS.Shortfall(),
    SPI.PRAS.Surplus(),
    SPI.PRAS.StorageEnergy(),
)

# Access Results
SPI.EUE(shortfall)
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean

# Static FOR and MTTR from Three-Year Monthly Average
# Using 48 hr MTTR

sys = PSY.System(
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_Static_FOR_3.json",
    runchecks=false,
);

# Run PRAS using SPI
num_samples = 100000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy = SPI.PRAS.assess(
    sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.PRAS.Shortfall(),
    SPI.PRAS.Surplus(),
    SPI.PRAS.StorageEnergy(),
)
# Access Results
SPI.EUE(shortfall)
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean

#  Monthly FOR time series data from Three-Year Monthly Average
# Load G100 Latest System from disk
sys = PSY.System(
    "GUAM_Gens_Stor_PV_20241104_182442/GUAM_Gens_Stor_PV_20241104_182442_FOR_ts_3yearAvg.json",
    runchecks=false,
);

# Run PRAS using SPI
num_samples = 100000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy = SPI.PRAS.assess(
    sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.PRAS.Shortfall(),
    SPI.PRAS.Surplus(),
    SPI.PRAS.StorageEnergy(),
)

# Access Results
SPI.EUE(shortfall)
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean

# GeneratorAvailability
# Run PRAS analysis and get generator availability for every sample
# Only getting generator availability because storages don't have any outage data
num_samples = 10000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy, shortfall_samples, gen_availability = SPI.PRAS.assess(
    sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.PRAS.Shortfall(),
    SPI.PRAS.Surplus(),
    SPI.PRAS.StorageEnergy(),
    SPI.PRAS.ShortfallSamples(),
    SPI.PRAS.GeneratorAvailability(),
)

sample_idx = sortperm(shortfall_samples[], rev=true)
gen_avail_for_worst_EUE_sample = gen_availability.available[:, :, sample_idx[1]]
gen_names = getfield(gen_availability, :generators)

for (j, gen_name) in enumerate(gen_names)
    @show gen_name, 1.0 - SB.mean(gen_avail_for_worst_EUE_sample[j, :])
end
# Capacity Credit - Kepco_PV1
# Marginal CC of Kepco_PV1 - EFC 
augmented_pras_sys = SPI.generate_pras_system(sys, PSY.Area);

# Remove Kepco_PV1 from Sienna System
kepco_pv_1_gen = PSY.get_component(PSY.Generator, sys, "Kepco_PV1")
PSY.set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)
kepco_pv_1_gen_cap = round(Int, PSY.get_rating(kepco_pv_1_gen))
PSY.remove_component!(sys, kepco_pv_1_gen)
base_pras_sys = SPI.generate_pras_system(sys, PSY.Area);

# EFC
num_samples = 10000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=true, seed=1)
cc = SPI.PRAS.assess(
    base_pras_sys,
    augmented_pras_sys,
    SPI_CC.EFC{SPI.PRAS.EUE}(
        kepco_pv_1_gen_cap,
        "Region",
        p_value=0.01,
        capacity_gap=1,
        verbose=true,
    ),
    sequential_monte_carlo,
)
cc_lower, cc_upper = extrema(cc)

# ELCC
num_samples = 10000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=true, seed=1)
cc = SPI.PRAS.assess(
    base_pras_sys,
    augmented_pras_sys,
    SPI_CC.ELCC{SPI.PRAS.EUE}(
        kepco_pv_1_gen_cap,
        "Region",
        p_value=0.01,
        capacity_gap=1,
        verbose=true,
    ),
    sequential_monte_carlo,
)
cc_lower, cc_upper = extrema(cc)

# Capacity Credit - PV in Guam System
# Average CC of PV resource in Guam System
augmented_pras_sys = SPI.generate_pras_system(sys, PSY.Area);

# Remove Kepco_PV1 from Sienna System
guam_pv_gens = PSY.get_components(
    x -> (PSY.get_available(x) && PSY.get_prime_mover_type(x) == PSY.PrimeMovers.PVe),
    PSY.RenewableDispatch,
    sys,
)
PSY.set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)
guam_pv_gen_cap = round(Int, sum(PSY.get_rating.(guam_pv_gens)))
for gen in guam_pv_gens
    PSY.remove_component!(sys, gen)
end
base_pras_sys = SPI.generate_pras_system(sys, PSY.Area);

# EFC
num_samples = 10000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=true, seed=1)
cc = SPI.PRAS.assess(
    base_pras_sys,
    augmented_pras_sys,
    SPI_CC.EFC{SPI.PRAS.EUE}(
        guam_pv_gen_cap,
        "Region",
        p_value=0.01,
        capacity_gap=1,
        verbose=true,
    ),
    sequential_monte_carlo,
)
cc_lower, cc_upper = extrema(cc)

# ELCC
num_samples = 10000
sequential_monte_carlo =
    SPI.PRAS.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=true, seed=1)
cc = SPI.PRAS.assess(
    base_pras_sys,
    augmented_pras_sys,
    SPI_CC.ELCC{SPI.PRAS.EUE}(
        guam_pv_gen_cap,
        "Region",
        p_value=0.01,
        capacity_gap=1,
        verbose=true,
    ),
    sequential_monte_carlo,
)
cc_lower, cc_upper = extrema(cc)
