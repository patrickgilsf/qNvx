# qNVX - Q-Sys to Crestron NVX Control Module

This is Crestron control module for Q-Sys. There is also a build and deploy environment for modificatin with your IDE. OR, simply download the .quc file and enjoy!

## Overview

- **Q-Sys Integration**: Compatible with Q-Sys Core processors
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

## Development Setup

If you want to use the build environment for development:

1. Create a `.env` file in the root directory with the following structure:
```
qUsername=<your username>
qPassword=<your password>
```
Replace `<your username>` and `<your password>` with your actual credentials.

Note: The `.env` file is only required if you plan to use the build environment. If you're just using the .quc file directly in Q-Sys Designer, you can skip this step.

## Module Usage

1. Import the `.quc` module into Q-Sys Designer
2. Configure the NVX device IP address and credentials
3. Use the provided controls to manage your NVX endpoints:
   - Stream routing
   - Device configuration
   - Status monitoring

## Support

For issues, questions, or contributions, please use the GitHub issues section of this repository.
