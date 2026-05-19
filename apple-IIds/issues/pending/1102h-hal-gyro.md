---
name: HAL — gyroscope (six-axis)
phase: 11
status: pending
blockedBy: [1101]
parent: 1102
---

# 1102h — HAL: gyroscope

ARM-assembly driver for the RG DS's six-axis gyroscope. Provides
angular velocity (three axes) and linear acceleration (three axes).

## current behavior

Linux's IIO subsystem exposes the gyro. On bare metal, direct I2C
reads of the gyro chip.

## intended behavior

- Initialize the gyro chip via I2C: set sample rate, sensitivity
  range, FIFO mode.
- Sample at a configurable rate (default 100 Hz, max 1 kHz).
- Provide a query API: `gyro_read() → {gx, gy, gz, ax, ay, az}`.

## API surface

- `gyro_init`
- `gyro_read() → {gx, gy, gz, ax, ay, az}`
- (poll-based; consumer reads at its own rate)

## suggested implementation steps

1. Identify the gyro chip. Common parts: BMI160, ICM-20602, etc.
   Read its datasheet.
2. Implement I2C transactions to configure the chip.
3. Implement the read path.
4. Test: hold the device still (small values), then rotate it
   gently (larger values on the corresponding axes).

## related documents

- `issues/1102-hardware-abstraction-layer.md` — parent issue
- `issues/803-native-gyro-input.md` — fine cursor mode

## notes

- Optional driver for game-input enrichment. Without it the device
  works fine; with it the fine-cursor mode (issue 803) is more
  pleasant.
