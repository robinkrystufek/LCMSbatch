[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# Batch LCMS Processing Tool for [Mnova MSChrom](https://mestrelab.com/main-product/mschrom)

This repository provides a simple QtScript tool for batch quantitation of LCMS data using [Mnova MSChrom](https://mestrelab.com/main-product/mschrom). The tool automates processing large sets of chromatographic data and outputs tables detailing target compound content based on quantitation channels, with peaks selected by target mass.

## Features
- Detect peaks in the quantitation channel (e.g., UV / ELSD) corresponding to EIC MS peaks of the target mass.
- Generate individual compound reports with target peaks highlighted.
- Produce bulk reports with target percentage quantification, total isomer content, and other QC metrics.
- Tested with MNova 14.3.3 (requires the MSChrom plugin).

## Installation and Usage

1. Copy the `processLCMSbatch.qs` file to:
   ```
   %homepath%\AppData\Roaming\Mestrelab Research S.L\MestReNova\scripts
   ```
2. Restart MNova.
3. Access the script via:
   - Shortcut: `Ctrl+2`
   - Menu: `Tools` -> `Legacy Scripts` -> `Process LCMS (batch)`

### File Structure Requirements
The directory selected for processing must have the following structure:
- **raw**: Folder which contains `.D` chromatogram files for analysis.
- **export**: Folder where processed results will be saved.
- **masses.csv**: File containing information about the processed chromatogram files with the following format:
  ```
  Data file name,Display name,Mass1,Mass2,Mass3
  ```
  - `Mass1` is used for tracking the quantified peak in the quantitation channel.

## License
The tool provided here is offered "as-is" without warranty of any kind, and its use is subject to the terms of the [MIT License](https://opensource.org/licenses/MIT).

[Mnova MSChrom](https://mestrelab.com/main-product/mschrom) is a commercial software product developed and maintained by [Mestrelab](https://mestrelab.com/end-user-software-license-agreements). This repository is an independent project and is not affiliated with, endorsed by, or sponsored by Mestrelab. Users must ensure they have the necessary licenses to use Mnova MSChrom and its associated plugins. 

