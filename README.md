# Godot Runner Game

A 3D infinite runner game built using the Godot Engine. This project features dynamic player mechanics, engaging levels, and integration capabilities for web deployment.

## Features

- **Dynamic Player Mechanics**: Smooth movement controls including a sliding mechanic with procedural squashing effects.
- **Level Progression**: Dynamic level generation and transitions.
- **Collectibles**: Coin collection system with UI feedback.
- **Menu System**: Fully functional main menu and game UI.
- **Web Export Support**: Includes scripts and configuration for building and serving the game as a web application (`build_web_local.sh`, `serve.py`).

## Getting Started

### Prerequisites
- **Godot Engine**: Ensure you have Godot Engine installed. (Check `project.godot` for the exact version requirements).

### Running the Game locally
1. Clone the repository to your local machine.
2. Open Godot Engine and click on **Import**.
3. Navigate to the cloned directory and select the `project.godot` file.
4. Click **Import & Edit**.
5. Press the **Play** button (or `F5`) in the Godot Editor to start the game.

### Web Deployment
This project includes configurations for building and deploying to the web.
- You can build the web export locally using the provided `build_web_local.sh` script.
- A local python server script `serve.py` is included to quickly test the web build on your localhost.
- For detailed information on integrating the exported Godot game into a separate web frontend, please refer to the documentation in `docs/godot-web-frontend-integration.md`.

## Project Structure

```text
Godot-Runner-Game/
├── assets/             # Game assets (textures, materials, etc.)
├── docs/               # Documentation files
├── models/             # 3D models and meshes
├── scenes/             # Godot scene files (.tscn)
├── scripts/            # GDScript files for game logic
├── shaders/            # Custom Godot shaders
├── sounds/             # Audio files
├── build_web_local.sh  # Web build script
├── serve.py            # Local test server for web builds
└── project.godot       # Godot project configuration
```

## License
This project is licensed under the terms specified in the `LICENSE` file.
