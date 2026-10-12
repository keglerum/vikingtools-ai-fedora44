#!/usr/bin/env python3
"""Read-only PCI/GPU report; works even when a mining card has no display output."""
import json
import shutil
import subprocess
from pathlib import Path


def read(path):
    try:
        return path.read_text().strip()
    except OSError:
        return None


def command(args):
    if not shutil.which(args[0]):
        return {'available': False}
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=30, check=False)
        return {'exit': p.returncode, 'output': p.stdout[:20000], 'errors': p.stderr[:2000]}
    except subprocess.TimeoutExpired:
        return {'error': 'Timed out'}


cards = []
for device in sorted(Path('/sys/bus/pci/devices').glob('*')):
    cls = read(device / 'class') or ''
    # Display / 3D class, plus known vendor processing accelerators where visible.
    vendor = read(device / 'vendor')
    if not (cls.startswith('0x03') or (cls.startswith('0x12') and vendor in ('0x1002', '0x10de', '0x8086'))):
        continue
    card = {'pci_address': device.name, 'vendor_id': vendor,
            'device_id': read(device / 'device'), 'class': cls,
            'subsystem_vendor': read(device / 'subsystem_vendor'),
            'subsystem_device': read(device / 'subsystem_device'),
            'driver': (device / 'driver').resolve().name if (device / 'driver').exists() else None}
    for attr in ('mem_info_vram_total', 'mem_info_vram_used', 'mem_info_gtt_total'):
        value = read(device / attr)
        if value is not None:
            card[attr + '_bytes'] = value
    card['description'] = command(['lspci', '-nnk', '-s', device.name])
    cards.append(card)
report = {'cards': cards, 'nvidia': command(['nvidia-smi', '--query-gpu=name,pci.bus_id,memory.total,driver_version', '--format=csv']),
          'vulkan': command(['vulkaninfo', '--summary']), 'secure_boot': command(['mokutil', '--sb-state']),
          'note': 'PCI IDs identify the chipset. No card compatibility, VRAM pooling, or acceleration is assumed.'}
print(json.dumps(report, indent=2))
