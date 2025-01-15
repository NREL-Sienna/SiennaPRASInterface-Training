###########################################
# Add Required Packages
###########################################
import SiennaPRASInterface
import PowerSystems

const SPI = SiennaPRASInterface
const PSY = PowerSystems

rts_sys = PSY.System("/Users/sdhulipa/Old Mac Backup/Desktop/OneDrive-Backup/NREL-Github/SiennaPRASInterface-Training/System_Data/RTS_GMLC_DA_with_static_outage_data.json");

# Run RA analysis using SPI
num_samples = 100
sequential_monte_carlo = SPI.SequentialMonteCarlo(samples=num_samples, threaded = true, verbose = false, seed = 1)
shortfall,surplus,storage_energy  = SPI.assess(rts_sys, PSY.Area, sequential_monte_carlo,
                                                     SPI.Shortfall(), SPI.Surplus(), SPI.StorageEnergy())

# Access Results
SPI.EUE(shortfall) 
SPI.LOLE(shortfall)
surplus.surplus_mean
storage_energy.energy_mean

