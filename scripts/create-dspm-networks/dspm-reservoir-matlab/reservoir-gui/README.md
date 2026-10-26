# Reservoir Programming GUI

A modern, interactive GUI for programming reservoir computers using the Dynamic Neural Programming framework.

## Overview

This GUI allows users to:
- **Visually design** reservoir network topology (inputs, outputs, recurrent connections)
- **Define dynamics** using symbolic equations with live LaTeX rendering
- **Configure parameters** (N neurons, γ, time constants, custom parameters)
- **Compile** equations into the reservoir
- **Export** programmed reservoirs to MATLAB workspace

## Architecture

```
reservoir-gui/
├── frontend/          # React + TypeScript + Tailwind app
│   ├── src/
│   │   ├── components/    # UI components
│   │   ├── hooks/         # React hooks (MATLAB bridge)
│   │   ├── stores/        # Zustand state management
│   │   ├── types/         # TypeScript types
│   │   └── utils/         # Utility functions
│   └── dist/          # Built app (served by MATLAB)
│
├── matlab/            # MATLAB integration
│   ├── programming_gui.m      # Entry point
│   └── buildProgramMatrix.m   # Equation → P matrix
│
└── dist/              # Built React app
```

## Quick Start

### Prerequisites

- MATLAB R2020a+ (with App Designer / uifigure support)
- Node.js 18+ and npm

### Building the Frontend

```bash
cd frontend
npm install
npm run build
```

This builds the React app to `dist/index.html`.

### Using in MATLAB

```matlab
% Add to path
addpath('matlab');

% Standalone mode - create new reservoir
programming_gui();

% Edit existing reservoir
res = Reservoir_v2(500, 100, 0.01, 3, 0);
programming_gui(res);
```

## Development

### Frontend Development

```bash
cd frontend
npm install
npm run dev
```

This starts a development server at `http://localhost:5173` with hot reload.

The app works standalone (with mock MATLAB responses) for UI development.

### Key Components

- **NetworkSchematic**: SVG visualization of network topology
- **DynamicsEditor**: Equation input rows with τ controls
- **EquationRenderer**: Live KaTeX rendering of equations
- **ConfigPanel**: Network parameters and presets
- **ControlBar**: Compile, save, export actions

### State Management

Uses Zustand stores:
- `reservoirStore`: Network config, equations, parameters, compile state
- `uiStore`: UI state (open/closed loop, status messages)

### MATLAB Communication

The `useMatlabBridge` hook handles bidirectional communication:
- **JS → MATLAB**: `window.parent.postMessage({ action, payload })`
- **MATLAB → JS**: `html.Data = struct('action', ..., 'payload', ...)`

## Built-in Presets

- **Lorenz Attractor**: Classic 3D chaotic system
- **Van der Pol Oscillator**: Relaxation oscillator
- **SR Latch**: Bistable memory from cross-coupled NOR gates
- **Collision Detector**: Fast bistable switch for boundary detection

## Color Scheme

| Port Type | Color | Position |
|-----------|-------|----------|
| External Inputs | Maroon (#7f1d1d) | Upper Left |
| External Outputs | Teal (#0d9488) | Upper Right |
| Recurrent Inputs | Navy (#1e3a5f) | Lower Left |
| Recurrent Outputs | Gold (#ca8a04) | Lower Right |

## License

MIT License - See LICENSE file.
