# Zig + Raylib + ZPhysics Example

<img width="912" height="944" alt="V2 Screenshot 2569-02-15" src="https://github.com/user-attachments/assets/7143fd82-c18c-4126-9830-a0c42e8fd6d0" />

<img width="912" height="594" alt="V1 Screenshot 2569-02-12" src="https://github.com/user-attachments/assets/1eddcafa-cc04-4dc8-aff8-68d48d93becb" />

- [branch v2 - shadowmap + charactor physic](https://github.com/krist7599555/example-zig-raylib-zphysics/tree/v2)
- [branch v1 - manual control](https://github.com/krist7599555/example-zig-raylib-zphysics/tree/v1)

A high-performance 3D physics demonstration built with **Zig**, **Raylib**, and **ZPhysics** (Jolt Physics).

![Demo Concept](https://img.shields.io/badge/Zig-0.15.2-orange.svg)
![Raylib](https://img.shields.io/badge/Raylib-5.5+-blue.svg)
![zphysics](https://img.shields.io/badge/Physics-Jolt-green.svg)

## 🚀 Features

- **Custom Physics Controller**: A red box player with precise movement and jumping.
- **Gravity Scaling**: Professional "Game Feel" with smooth rising and fast-falling physics.
- **Third-Person Camera**: Follow-cam that rotates with the player's 3D orientation.
- **Dynamic Simulation**: Interactive boxes and a grid-based ground plane.
- **Optimized Math**: Uses Zig's `@Vector` SIMD instructions via a custom `vec.zig` helper.
- **Shader Support**: Basic GLSL integration for player and object rendering.

## 🛠️ Prerequisites

- [Zig 0.15.2](https://ziglang.org/download/) (or compatible latest dev build)
- All dependencies are managed via Zig's package manager.

## 🏃 How to Run

Clone the repository and run:

```bash
zig build run
```

## 🎮 Controls

| Key | Action |
|-----|--------|
| **W / S** | Move Forward / Backward |
| **A / D** | Turn Left / Right |
| **Space** | Jump (Hold for high jump, tap for short hop) |
| **ESC** | Exit |

## 📂 Project Structure

- `src/main.zig`: Entry point and main game loop.
- `src/zphy_helper.zig`: Boilerplate for Jolt Physics initialization and shape creation.
- `src/vec.zig`: SIMD-powered vector utility functions (`vec3`, `vec4`).
- `src/shaders/`: GLSL vertex and fragment shaders.

## 📦 Libraries Used

- [raylib-zig](https://github.com/Not-Cyrus/raylib-zig)
- [zphysics](https://github.com/zig-gamedev/zphysics) (Jolt Physics wrapper)
