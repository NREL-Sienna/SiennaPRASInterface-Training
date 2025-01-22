###########################################
# Add Required Packages
###########################################
import SiennaPRASInterface
import PowerSystems

const SPI = SiennaPRASInterface
const PSY = PowerSystems

rts_sys = PSY.System("System_Data/RTS_GMLC_DA_with_static_outage_data.json", time_series_directory = "System_Data/ts_temp", time_series_in_memory = true);

supp_attr = first(
    PSY.get_supplemental_attributes(
        PSY.GeometricDistributionForcedOutage,
        first(PSY.get_available_components(PSY.ThermalGen, rts_sys)),
    ),
)
# Run RA analysis using SPI on RTS System with Static Outage Data
num_samples = 100
sequential_monte_carlo =
    SPI.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy = SPI.assess(
    rts_sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.Shortfall(),
    SPI.Surplus(),
    SPI.StorageEnergy(),
)

# Access Results
SPI.EUE(shortfall)
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean

# Run RA analysis using SPI on RTS System with time series of λ and μ
rts_ts_sys = PSY.System(
    "System_Data/RTS_GMLC_DA_with_outage_ts_data.json",
    time_series_directory="System_Data/ts_temp",
    time_series_in_memory = true
);

supp_attr = first(
    PSY.get_supplemental_attributes(
        PSY.GeometricDistributionForcedOutage,
        first(PSY.get_available_components(PSY.ThermalGen, rts_ts_sys)),
    ),
)

PSY.get_time_series_array(PSY.SingleTimeSeries, supp_attr, "outage_probability")
# Run RA analysis using SPI
num_samples = 100
sequential_monte_carlo =
    SPI.SequentialMonteCarlo(samples=num_samples, threaded=true, verbose=false, seed=1)
shortfall, surplus, storage_energy = SPI.assess(
    rts_ts_sys,
    PSY.Area,
    sequential_monte_carlo,
    SPI.Shortfall(),
    SPI.Surplus(),
    SPI.StorageEnergy(),
)

# Access Results
SPI.EUE(shortfall)
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean
