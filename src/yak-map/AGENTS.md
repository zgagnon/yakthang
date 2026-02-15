# yak-map

Zellij plugin for visualizing yak task state.

## Development

### Prerequisites
- Rust toolchain with `wasm32-wasip1` target:
  ```bash
  rustup target add wasm32-wasip1
  ```

### Build
```bash
cd src/yak-map
cargo build --release --target wasm32-wasip1
```

### Install
Copy to the bin folder:
```bash
cp target/wasm32-wasip1/release/yak-map.wasm ../../bin/yak-map.wasm
```

### Run in Zellij
The plugin reads from `/host/.yaks` directory.