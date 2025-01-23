# qNVX - Q-Sys to Crestron NVX Control Module

This Q-Sys module enables seamless control integration between Q-Sys Core processors and Crestron NVX devices. It allows Q-Sys systems to control and manage Crestron NVX endpoints for AV-over-IP applications.

## Overview

- **Q-Sys Integration**: Compatible with Q-Sys Core processors ([Core Feature Comparison](https://www.qscaudio.com/resource-files/productresources/dn/dsp_cores/q_dn_core_comparison_chart.pdf))
- **Crestron Control**: Enables control of [Crestron DM-NVX Series](https://www.crestron.com/Products/Featured-Solutions/DigitalMedia-NVX-Series) devices
- **Easy Installation**: Deployable as a .quc module in Q-Sys Designer

## Quick Start

1. Download the `.quc` module file from the root directory of this repository
2. Import the module into Q-Sys Designer
3. Add the module to your Q-Sys design

## Development Environment Setup

To set up the development environment:

1. Ensure Node.js is installed on your system
2. Clone this repository
3. Install dependencies:
   ```bash
   npm install
   ```
4. Build the module:
   ```bash
   node index.js
   ```

The build process lets you alter the code from you IDE, if you want to make an edit (suggest a PR if so!)

## Module Usage

1. Import the `.quc` module into Q-Sys Designer
2. Configure the NVX device IP address and credentials
3. Use the provided controls to manage your NVX endpoints:
   - Stream routing
   - Device configuration
   - Status monitoring

## Support

For issues, questions, or contributions, please use the GitHub issues section of this repository.
