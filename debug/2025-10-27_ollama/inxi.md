System:
  Kernel: 6.17.4-200.fc42.x86_64 arch: x86_64 bits: 64 compiler: gcc v: 15.2.1
  Desktop: KDE Plasma v: 6.4.5 tk: Qt v: N/A wm: kwin_wayland dm: SDDM
    Distro: Fedora Linux 42 (KDE Plasma Desktop Edition)
Machine:
  Type: Desktop System: ASUS product: N/A v: N/A serial: <superuser required>
  Mobo: ASUSTeK model: ROG STRIX X470-I GAMING v: Rev 1.xx
    serial: <superuser required> part-nu: SKU BIOS: American Megatrends v: 5602
    date: 01/13/2025
CPU:
  Info: 8-core model: AMD Ryzen 7 5800X3D bits: 64 type: MT MCP arch: Zen 3+
    rev: 2 cache: L1: 512 KiB L2: 4 MiB L3: 96 MiB
  Speed (MHz): avg: 3367 min/max: 576/4553 boost: enabled cores: 1: 3367
    2: 3367 3: 3367 4: 3367 5: 3367 6: 3367 7: 3367 8: 3367 9: 3367 10: 3367
    11: 3367 12: 3367 13: 3367 14: 3367 15: 3367 16: 3367 bogomips: 108805
  Flags-basic: avx avx2 ht lm nx pae sse sse2 sse3 sse4_1 sse4_2 sse4a
    ssse3 svm
Graphics:
  Device-1: Advanced Micro Devices [AMD/ATI] Navi 48 [Radeon RX 9070/9070
    XT/9070 GRE] vendor: Tul / PowerColor Reaper driver: amdgpu v: kernel
    arch: RDNA-4 pcie: speed: 32 GT/s lanes: 16 ports: active: DP-3
    empty: DP-1, DP-2, HDMI-A-1, Writeback-1 bus-ID: 0b:00.0
    chip-ID: 1002:7550
  Display: wayland server: Xwayland v: 24.1.8 compositor: kwin_wayland
    driver: gpu: amdgpu display-ID: 0
  Monitor-1: DP-3 model: AOC AG493US3R4 res: 5120x1440 hz: 120 dpi: 82
    diag: 1238mm (48.7")
  API: EGL v: 1.5 platforms: device: 0 drv: radeonsi device: 1 drv: swrast
    gbm: drv: kms_swrast surfaceless: drv: radeonsi wayland: drv: radeonsi x11:
    drv: radeonsi
  API: OpenGL v: 4.6 compat-v: 4.5 vendor: amd mesa v: 25.1.9 glx-v: 1.4
    direct-render: yes renderer: AMD Radeon RX 9070 XT (radeonsi gfx1201 LLVM
    20.1.8 DRM 3.64 6.17.4-200.fc42.x86_64) device-ID: 1002:7550
    display-ID: :0.0
  API: Vulkan v: 1.4.313 surfaces: N/A device: 0 type: discrete-gpu
    driver: mesa radv device-ID: 1002:7550 device: 1 type: cpu
    driver: mesa llvmpipe device-ID: 10005:0000
  Info: Tools: api: clinfo, eglinfo, glxinfo, vulkaninfo
    de: kscreen-console,kscreen-doctor gpu: amd-smi wl: wayland-info
    x11: xdriinfo, xdpyinfo, xprop, xrandr
Audio:
  Device-1: Advanced Micro Devices [AMD/ATI] Navi 48 HDMI/DP Audio
    driver: snd_hda_intel v: kernel pcie: speed: 32 GT/s lanes: 16
    bus-ID: 0b:00.1 chip-ID: 1002:ab40
  Device-2: Advanced Micro Devices [AMD] Starship/Matisse HD Audio
    vendor: ASUSTeK driver: snd_hda_intel v: kernel pcie: speed: 16 GT/s
    lanes: 16 bus-ID: 0d:00.4 chip-ID: 1022:1487
  API: ALSA v: k6.17.4-200.fc42.x86_64 status: kernel-api
  Server-1: PipeWire v: 1.4.9 status: active with: 1: pipewire-pulse
    status: active 2: wireplumber status: active 3: pipewire-alsa type: plugin
    4: pw-jack type: plugin
Network:
  Device-1: Intel I211 Gigabit Network vendor: ASUSTeK driver: igb v: kernel
    pcie: speed: 2.5 GT/s lanes: 1 port: d000 bus-ID: 04:00.0 chip-ID: 8086:1539
  IF: enp4s0 state: up speed: 1000 Mbps duplex: full mac: <filter>
  Device-2: Realtek RTL8822BE 802.11a/b/g/n/ac WiFi adapter vendor: ASUSTeK
    driver: rtw88_8822be v: kernel pcie: speed: 2.5 GT/s lanes: 1 port: c000
    bus-ID: 05:00.0 chip-ID: 10ec:b822
  IF: wlp5s0 state: down mac: <filter>
  IF-ID-1: docker0 state: down mac: <filter>
Bluetooth:
  Device-1: ASUSTek Bluetooth Radio driver: btusb v: 0.8 type: USB rev: 1.1
    speed: 12 Mb/s lanes: 1 bus-ID: 1-12:5 chip-ID: 0b05:185c
  Report: btmgmt ID: hci0 rfk-id: 0 state: up address: <filter> bt-v: 4.2
    lmp-v: 8
Drives:
  Local Storage: total: 3.64 TiB used: 1.85 TiB (51.0%)
  ID-1: /dev/nvme0n1 vendor: Western Digital model: WD BLACK SN7100 2TB
    size: 1.82 TiB speed: 63.2 Gb/s lanes: 4 serial: <filter> temp: 36.9 C
  ID-2: /dev/sda vendor: Samsung model: SSD 870 QVO 2TB size: 1.82 TiB
    speed: 6.0 Gb/s serial: <filter>
Partition:
  ID-1: / size: 1.82 TiB used: 399.59 GiB (21.5%) fs: btrfs
    dev: /dev/nvme0n1p3
  ID-2: /boot size: 973.4 MiB used: 566.7 MiB (58.2%) fs: ext4
    dev: /dev/nvme0n1p2
  ID-3: /home size: 1.82 TiB used: 399.59 GiB (21.5%) fs: btrfs
    dev: /dev/nvme0n1p3
Swap:
  ID-1: swap-1 type: zram size: 8 GiB used: 0 KiB (0.0%) priority: 100
    dev: /dev/zram0
Sensors:
  System Temperatures: cpu: 50.0 C mobo: 40.0 C gpu: amdgpu temp: 55.0 C
    mem: 56.0 C
  Fan Speeds (rpm): cpu: 1490 case-1: 0 gpu: amdgpu fan: 0
  Power: 12v: 9.97 5v: N/A 3.3v: N/A vbat: 3.18
Info:
  Memory: total: 32 GiB available: 30.98 GiB used: 6.51 GiB (21.0%)
  Processes: 577 Power: uptime: 51m wakeups: 0 Init: systemd v: 257
    target: graphical (5) default: graphical
  Packages: 40 pm: rpm pkgs: N/A note: see --rpm pm: flatpak pkgs: 28
    pm: snap pkgs: 12 Compilers: gcc: 15.2.1 Shell: Bash v: 5.2.37
    running-in: zed-editor inxi: 3.3.39
