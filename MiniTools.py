#!/usr/bin/env python3
"""
Mini Tools - PyQt6 Version
A modern, professional GUI application for system information and maintenance
"""

__app_name__ = "Mini Tools"
__version__ = "1.0.3"
__author__ = "Ezra"

import os
import sys
import subprocess
import platform
import threading
import re
import shutil
import tempfile
from pathlib import Path
from typing import Optional, List, Tuple, Callable
from enum import Enum

class LogLevel(Enum):
    """Log level enumeration"""
    INFO = "info"
    SUCCESS = "success"
    WARNING = "warning"
    ERROR = "error"
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QFileDialog, QMessageBox, QTextEdit, QFrame,
    QProgressBar, QGroupBox, QScrollArea, QDialog, QDialogButtonBox,
    QButtonGroup, QRadioButton, QInputDialog, QSlider, QLineEdit, QSizePolicy, QTextBrowser
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize, QTimer, QDateTime
from PyQt6.QtGui import QFont, QColor, QPalette, QIcon, QPixmap, QShortcut, QKeySequence, QPainter, QPen


class Platform(Enum):
    """Platform enumeration"""
    LINUX = "linux"
    WINDOWS = "windows"
    MACOS = "macos"
    UNKNOWN = "unknown"


class PlatformHelper:
    """Cross-platform helper for system-specific operations"""
    
    @staticmethod
    def get_platform() -> Platform:
        """Detect current platform"""
        system = platform.system().lower()
        if system == "linux":
            return Platform.LINUX
        elif system == "windows":
            return Platform.WINDOWS
        elif system == "darwin":
            return Platform.MACOS
        return Platform.UNKNOWN
    
    @staticmethod
    def is_windows() -> bool:
        """Check if running on Windows"""
        return PlatformHelper.get_platform() == Platform.WINDOWS
    
    @staticmethod
    def is_linux() -> bool:
        """Check if running on Linux"""
        return PlatformHelper.get_platform() == Platform.LINUX
    
    @staticmethod
    def is_macos() -> bool:
        """Check if running on macOS"""
        return PlatformHelper.get_platform() == Platform.MACOS
    
    @staticmethod
    def get_extensions_dir() -> str:
        """Get the extensions directory path for current platform"""
        if PlatformHelper.is_windows():
            # Windows: %APPDATA%\hotodogo\minitools\extensions
            appdata = os.environ.get('APPDATA')
            if not appdata:
                # Fallback to user home + AppData\Roaming
                home = os.path.expanduser('~')
                appdata = os.path.join(home, 'AppData', 'Roaming')
            # Build extensions path using pathlib for better cross-platform handling
            from pathlib import Path
            extensions_dir = Path(appdata) / 'hotodogo' / 'minitools' / 'extensions'
            return str(extensions_dir)
        elif PlatformHelper.is_macos():
            # macOS: ~/Library/Application Support/hotodogo/minitools/extensions
            home = os.path.expanduser('~')
            return os.path.join(home, 'Library', 'Application Support', 'hotodogo', 'minitools', 'extensions')
        else:
            # Linux: ~/.config/hotodogo/minitools/extensions
            return os.path.expanduser('~/.config/hotodogo/minitools/extensions')


class ShellCommandHelper:
    """Helper class for executing shell commands"""
    
    @staticmethod
    def run_command(command: List[str], capture_output: bool = True, 
                   silent: bool = True) -> Tuple[int, str, str]:
        """
        Execute a shell command and return (exit_code, stdout, stderr)
        
        Args:
            command: List of command arguments
            capture_output: Whether to capture stdout and stderr
            silent: Whether to suppress stderr output
            
        Returns:
            Tuple of (exit_code, stdout, stderr)
        """
        try:
            stderr_target = subprocess.DEVNULL if silent else subprocess.PIPE
            stdout_target = subprocess.PIPE if capture_output else None
            
            # On Windows, use shell=True for some commands
            shell = PlatformHelper.is_windows() and command[0] in ['cmd', 'powershell']
            
            result = subprocess.run(
                command,
                stdout=stdout_target,
                stderr=stderr_target,
                text=True,
                check=False,
                shell=shell
            )
            
            stdout = result.stdout if capture_output else ""
            stderr = result.stderr if not silent else ""
            
            return result.returncode, stdout, stderr
        except Exception as e:
            return -1, "", str(e)
    
    @staticmethod
    def get_command_output(command: List[str], silent: bool = True) -> str:
        """
        Execute a command and return stdout, or empty string on failure
        
        Args:
            command: List of command arguments
            silent: Whether to suppress stderr output
            
        Returns:
            Command stdout or empty string
        """
        exit_code, stdout, stderr = ShellCommandHelper.run_command(command, silent=silent)
        return stdout if exit_code == 0 else ""
    
    @staticmethod
    def read_file_lines(file_path: str) -> List[str]:
        """Read all lines from a file, return empty list on failure"""
        try:
            with open(file_path, "r") as f:
                return f.read().splitlines()
        except Exception:
            return []
    
    @staticmethod
    def parse_key_value_lines(lines: List[str], separator: str = ":") -> dict:
        """
        Parse lines in format "key: value" into a dictionary
        
        Args:
            lines: List of strings to parse
            separator: Separator between key and value
            
        Returns:
            Dictionary of key-value pairs
        """
        result = {}
        for line in lines:
            if separator in line:
                key, value = line.split(separator, 1)
                result[key.strip()] = value.strip()
        return result


class Config:
    """Application configuration constants"""
    
    # Font settings
    DEFAULT_LOG_FONT_SIZE = 11
    MIN_LOG_FONT_SIZE = 6
    MAX_LOG_FONT_SIZE = 32
    LOG_FONT_FAMILY = "Consolas"
    
    # Window sizing
    MIN_WINDOW_WIDTH = 640
    MIN_WINDOW_HEIGHT = 480
    DEFAULT_WINDOW_WIDTH = 1200
    DEFAULT_WINDOW_HEIGHT = 900
    
    # Extensions
    EXTENSIONS_DIR = "~/.config/hotodogo/minitools/extensions"
    
    # Use PlatformHelper to get actual extensions directory
    @staticmethod
    def get_extensions_dir() -> str:
        """Get the absolute path to the extensions directory"""
        return PlatformHelper.get_extensions_dir()
    
    # Colors for dark theme
    DARK_COLORS = {
        "info": "#d4d4d4",
        "success": "#4ec9b0",
        "warning": "#ffcc00",
        "error": "#f48771",
        "timestamp": "#888888"
    }
    
    # Colors for light theme
    LIGHT_COLORS = {
        "info": "#1d1d1f",
        "success": "#2e7d32",
        "warning": "#f57c00",
        "error": "#c62828",
        "timestamp": "#6c757d"
    }
    
    # Log levels
    LOG_LEVELS = [LogLevel.INFO.value, LogLevel.SUCCESS.value, LogLevel.WARNING.value, LogLevel.ERROR.value]
    
    # Supported script extensions
    SUPPORTED_SCRIPT_EXTENSIONS = ['.sh', '.py']
    
    # Supported package managers
    SUPPORTED_DISTROS = {
        "apt": ["ubuntu", "debian", "mint", "pop", "zorin", "elementary"],
        "dnf": ["fedora", "nobara", "rhel", "centos"],
        "pacman": ["arch", "cachyos", "manjaro", "endeavouros", "xerolinux", "garuda"],
        "zypper": ["opensuse", "suse"]
    }
    
    @staticmethod
    def get_extensions_dir() -> str:
        """Get the absolute path to the extensions directory"""
        return os.path.expanduser(Config.EXTENSIONS_DIR)


class SystemInfoWorker(QThread):
    """Worker thread for collecting system information"""
    data_ready = pyqtSignal(str, str)
    error_signal = pyqtSignal(str)
    
    # Map info types to handler methods
    INFO_HANDLERS = {}
    
    def __init__(self, info_type: str):
        super().__init__()
        self.info_type = info_type
        self._register_handlers()
    
    def _register_handlers(self):
        """Register info type handlers"""
        self.INFO_HANDLERS = {
            "cpu": self.get_cpu_info,
            "memory": self.get_memory_info,
            "kernel": self.get_kernel_info,
            "swap": self.get_swap_info,
            "disk": self.get_disk_info,
            "update": self.get_update_info,
            "flatpak": self.get_flatpak_update_info
        }
        
        # Register Windows-specific handlers
        if PlatformHelper.is_windows():
            self.INFO_HANDLERS.update({
                "cpu_windows": self.get_cpu_info_windows,
                "memory_windows": self.get_memory_info_windows,
                "kernel_windows": self.get_kernel_info_windows,
                "swap_windows": self.get_swap_info_windows,
                "disk_windows": self.get_disk_info_windows
            })
    
    def run(self):
        """Execute the appropriate info handler based on info_type"""
        # Check platform support
        if PlatformHelper.is_windows() and self.info_type in ["update", "flatpak"]:
            self.error_signal.emit("This feature is not supported on Windows")
            return
        if PlatformHelper.is_windows() and self.info_type in ["cpu", "memory", "kernel", "swap", "disk"]:
            handler = self.INFO_HANDLERS.get(f"{self.info_type}_windows")
            if handler:
                try:
                    handler()
                except Exception as e:
                    self.error_signal.emit(f"Error: {str(e)}")
            else:
                self.error_signal.emit(f"Windows support for {self.info_type} is not yet implemented")
            return
        
        handler = self.INFO_HANDLERS.get(self.info_type)
        if handler:
            try:
                handler()
            except Exception as e:
                self.error_signal.emit(f"Error: {str(e)}")
        else:
            self.error_signal.emit(f"Unknown info type: {self.info_type}")
    
    def _emit_result(self, title: str, data: List[str]):
        """Emit data_ready signal with formatted result"""
        output = "\n".join(data)
        self.data_ready.emit(title, output)
    
    def get_cpu_info(self):
        super().__init__()
        self.info_type = info_type
    
    def get_cpu_info(self):
        """Get CPU information"""
        result = []
        
        try:
            # Parse /proc/cpuinfo
            cpuinfo_lines = ShellCommandHelper.read_file_lines("/proc/cpuinfo")
            cpuinfo_data = ShellCommandHelper.parse_key_value_lines(cpuinfo_lines)
            
            model_name = cpuinfo_data.get("model name")
            processors = sum(1 for line in cpuinfo_lines if line.startswith("processor"))
            cores = int(cpuinfo_data.get("cpu cores", 0))
            siblings = int(cpuinfo_data.get("siblings", 0))
            threads_per_core = siblings // cores if siblings > 0 and cores > 0 else 1
            
            if model_name:
                result.append(f"Model: {model_name}")
            result.append(f"Processors: {processors}")
            result.append(f"Physical Cores: {cores}")
            result.append(f"Threads per Core: {threads_per_core}")
            
            # Get current frequency
            cpu_freq = ShellCommandHelper.get_command_output(["cat", "/proc/cpuinfo"])
            freq_match = re.search(r'cpu MHz\s*:\s*([\d.]+)', cpu_freq)
            if freq_match:
                result.append(f"Current Frequency: {float(freq_match.group(1)):.2f} MHz")
            
            # Get max/min frequency
            for freq_type, label in [("cpuinfo_max_freq", "Max"), ("cpuinfo_min_freq", "Min")]:
                freq_path = f"/sys/devices/system/cpu/cpu0/cpufreq/{freq_type}"
                if os.path.exists(freq_path):
                    freq_content = ShellCommandHelper.read_file_lines(freq_path)
                    if freq_content:
                        freq_khz = int(freq_content[0].strip())
                        result.append(f"{label} Frequency: {freq_khz / 1000:.2f} MHz")
            
            # Get CPU usage
            stat_output = ShellCommandHelper.get_command_output(["grep", "cpu", "/proc/stat"])
            if stat_output:
                lines = stat_output.strip().split("\n")
                if len(lines) > 1:
                    cpu_usage = self._calculate_cpu_usage(lines[0])
                    result.append(f"CPU Usage: {cpu_usage:.1f}%")
            
            # Get cache info
            cache_info = ShellCommandHelper.get_command_output(["lscpu"])
            for line in cache_info.split("\n"):
                if any(cache in line for cache in ["L1d cache", "L1i cache", "L2 cache", "L3 cache"]):
                    result.append(line.strip())
                    
        except Exception as e:
            result.append(f"Error reading CPU info: {str(e)}")
        
        self._emit_result("CPU Information", result)
    
    def _calculate_cpu_usage(self, cpu_line: str) -> float:
        """Calculate CPU usage from /proc/stat line"""
        values = list(map(int, cpu_line.split()[1:]))
        idle = values[3]
        total = sum(values)
        return 100 * (1 - idle / total) if total > 0 else 0
    
    def get_memory_info(self):
        """Get memory information"""
        result = []
        
        try:
            meminfo_lines = ShellCommandHelper.read_file_lines("/proc/meminfo")
            mem_data = {}
            
            for line in meminfo_lines:
                if ":" in line:
                    key, value = line.split(":", 1)
                    key = key.strip()
                    value = value.strip().split()[0]
                    try:
                        mem_data[key] = int(value)
                    except ValueError:
                        continue
            
            def to_mb(value_kb: int) -> int:
                return value_kb // 1024
            
            total_mb = to_mb(mem_data.get("MemTotal", 0))
            free_mb = to_mb(mem_data.get("MemFree", 0))
            available_mb = to_mb(mem_data.get("MemAvailable", mem_data.get("MemFree", 0)))
            buffers_mb = to_mb(mem_data.get("Buffers", 0))
            cached_mb = to_mb(mem_data.get("Cached", 0))
            shmem_mb = to_mb(mem_data.get("Shmem", 0))
            slab_mb = to_mb(mem_data.get("SReclaimable", 0))
            
            used_mb = total_mb - available_mb
            usage_percent = (used_mb / total_mb * 100) if total_mb > 0 else 0
            
            result.append(f"Total Memory: {total_mb} MB ({total_mb // 1024} GB)")
            result.append(f"Used Memory: {used_mb} MB ({used_mb // 1024} GB)")
            result.append(f"Free Memory: {free_mb} MB ({free_mb // 1024} GB)")
            result.append(f"Available Memory: {available_mb} MB ({available_mb // 1024} GB)")
            result.append(f"Memory Usage: {usage_percent:.1f}%")
            result.append("")
            result.append(f"Buffers: {buffers_mb} MB")
            result.append(f"Cached: {cached_mb} MB")
            result.append(f"Shared Memory: {shmem_mb} MB")
            result.append(f"Slab Reclaimable: {slab_mb} MB")
            
            active_mb = to_mb(mem_data.get("Active", 0))
            inactive_mb = to_mb(mem_data.get("Inactive", 0))
            if active_mb or inactive_mb:
                result.append("")
                result.append(f"Active: {active_mb} MB")
                result.append(f"Inactive: {inactive_mb} MB")
                    
        except Exception as e:
            result.append(f"Error reading memory info: {str(e)}")
        
        self._emit_result("Memory Information", result)
    
    def get_kernel_info(self):
        """Get kernel information"""
        result = []
        
        try:
            uname_info = os.uname()
            result.append(f"Kernel Release: {uname_info.release}")
            result.append(f"Kernel Version: {uname_info.version}")
            result.append(f"Architecture: {uname_info.machine}")
            result.append(f"Hostname: {uname_info.nodename}")
            
            # Parse /etc/os-release
            os_release_lines = ShellCommandHelper.read_file_lines("/etc/os-release")
            distro_info = {}
            for line in os_release_lines:
                if "=" in line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    distro_info[key.strip()] = value.strip().strip('"')
            
            if distro_info:
                result.append("")
                result.append(f"Distribution: {distro_info.get('NAME', 'Unknown')}")
                result.append(f"Distribution ID: {distro_info.get('ID', 'Unknown')}")
                result.append(f"Version: {distro_info.get('VERSION', 'Unknown')}")
                result.append(f"Version ID: {distro_info.get('VERSION_ID', 'Unknown')}")
                result.append(f"Pretty Name: {distro_info.get('PRETTY_NAME', 'Unknown')}")
        except:
            pass
        
        try:
            uptime = ShellCommandHelper.get_command_output(["cat", "/proc/uptime"])
            if uptime:
                uptime_seconds = float(uptime.split()[0])
                uptime_days = int(uptime_seconds // 86400)
                uptime_hours = int((uptime_seconds % 86400) // 3600)
                uptime_minutes = int((uptime_seconds % 3600) // 60)
                result.append("")
                result.append(f"System Uptime: {uptime_days}d {uptime_hours}h {uptime_minutes}m")
        except:
            pass
        
        try:
            boot_time = ShellCommandHelper.get_command_output(["cat", "/proc/stat"])
            if boot_time:
                btime_match = re.search(r'btime (\d+)', boot_time)
                if btime_match:
                    import datetime
                    boot_timestamp = int(btime_match.group(1))
                    boot_datetime = datetime.datetime.fromtimestamp(boot_timestamp)
                    result.append(f"Boot Time: {boot_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
        except Exception as e:
            result.append(f"Error reading kernel info: {str(e)}")
        
        self._emit_result("Kernel Information", result)
    
    def get_swap_info(self):
        """Get swap information"""
        result = []
        
        try:
            meminfo_lines = ShellCommandHelper.read_file_lines("/proc/meminfo")
            mem_data = {}
            
            for line in meminfo_lines:
                if ":" in line:
                    key, value = line.split(":", 1)
                    key = key.strip()
                    value = value.strip().split()[0]
                    try:
                        mem_data[key] = int(value)
                    except ValueError:
                        continue
            
            def to_mb(value_kb: int) -> int:
                return value_kb // 1024
            
            swap_total = to_mb(mem_data.get("SwapTotal", 0))
            swap_free = to_mb(mem_data.get("SwapFree", 0))
            swap_cached = to_mb(mem_data.get("SwapCached", 0))
            
            swap_used = swap_total - swap_free
            usage_percent = (swap_used / swap_total * 100) if swap_total > 0 else 0
            
            result.append(f"Total Swap: {swap_total} MB ({swap_total // 1024} GB)")
            result.append(f"Used Swap: {swap_used} MB ({swap_used // 1024} GB)")
            result.append(f"Free Swap: {swap_free} MB ({swap_free // 1024} GB)")
            result.append(f"Cached Swap: {swap_cached} MB")
            result.append(f"Swap Usage: {usage_percent:.1f}%")
            
            swap_output = ShellCommandHelper.get_command_output(["swapon", "--show"])
            if swap_output.strip():
                result.append("")
                result.append("Swap Devices:")
                result.append(swap_output)
            
            swappiness = ShellCommandHelper.get_command_output(["cat", "/proc/sys/vm/swappiness"])
            if swappiness:
                result.append("")
                result.append(f"Swappiness: {swappiness.strip()}")
                    
        except Exception as e:
            result.append(f"Error reading swap info: {str(e)}")
        
        self._emit_result("Swap Information", result)
    
    def get_disk_info(self):
        """Get disk information"""
        result = []
        
        try:
            # Get disk usage
            df_output = ShellCommandHelper.get_command_output(["df", "-h"])
            result.append("━━━━━━ Disk Usage ━━━━━━")
            result.append("")
            for line in df_output.strip().split("\n"):
                result.append(line)
            result.append("")
            
            # Get block devices
            lsblk_output = ShellCommandHelper.get_command_output(["lsblk", "-f"])
            result.append("━━━━━━ Block Devices ━━━━━━")
            result.append("")
            for line in lsblk_output.strip().split("\n"):
                result.append(line)
            result.append("")
            
            # Get mounted filesystems
            with open("/proc/mounts", "r") as f:
                mounts = f.read()
            result.append("━━━━━━ Mounted Filesystems ━━━━━━")
            result.append("")
            for line in mounts.split("\n"):
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 3:
                        result.append(f"{parts[0]} on {parts[1]} type {parts[2]}")
                        if len(parts) > 3:
                            result.append(f"  Options: {' '.join(parts[3:])}")
            result.append("")
            
            # Get disk UUIDs
            try:
                uuids = subprocess.check_output(
                    ["blkid"], 
                    stderr=subprocess.DEVNULL, 
                    text=True
                )
                result.append("━━━━━━ Disk UUIDs ━━━━━━")
                result.append("")
                for line in uuids.split("\n"):
                    if line.strip():
                        result.append(line)
            except:
                pass
            
        except Exception as e:
            result.append(f"Error reading disk info: {str(e)}")
        
        output = "\n".join(result)
        self.data_ready.emit("Disk Information", output)
    
    def get_cpu_info_windows(self):
        """Get CPU information on Windows"""
        result = []
        
        try:
            import platform
            import wmi
            
            c = wmi.WMI()
            
            # Get CPU info
            for cpu in c.Win32_Processor():
                result.append(f"Model: {cpu.Name}")
                result.append(f"Manufacturer: {cpu.Manufacturer}")
                result.append(f"Max Clock Speed: {cpu.MaxClockSpeed / 1000:.2f} GHz")
                result.append(f"Number of Cores: {cpu.NumberOfCores}")
                result.append(f"Number of Logical Processors: {cpu.NumberOfLogicalProcessors}")
                break
            
            result.append("")
            result.append(f"System: {platform.system()} {platform.release()}")
            result.append(f"Architecture: {platform.machine()}")
            
            # Get CPU usage
            import psutil
            cpu_percent = psutil.cpu_percent(interval=1)
            result.append(f"CPU Usage: {cpu_percent:.1f}%")
            
            # CPU frequency
            freq = psutil.cpu_freq()
            if freq:
                result.append(f"Current Frequency: {freq.current / 1000:.2f} GHz")
                result.append(f"Max Frequency: {freq.max / 1000:.2f} GHz")
                
        except ImportError:
            result.append("Error: Required libraries not installed")
            result.append("Please install: pip install wmi psutil")
        except Exception as e:
            result.append(f"Error reading CPU info: {str(e)}")
        
        self._emit_result("CPU Information", result)
    
    def get_memory_info_windows(self):
        """Get memory information on Windows"""
        result = []
        
        try:
            import psutil
            
            mem = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            total_mb = mem.total // (1024 * 1024)
            available_mb = mem.available // (1024 * 1024)
            used_mb = mem.used // (1024 * 1024)
            free_mb = mem.free // (1024 * 1024)
            
            result.append(f"Total Memory: {total_mb} MB ({total_mb // 1024} GB)")
            result.append(f"Used Memory: {used_mb} MB ({used_mb // 1024} GB)")
            result.append(f"Available Memory: {available_mb} MB ({available_mb // 1024} GB)")
            result.append(f"Free Memory: {free_mb} MB ({free_mb // 1024} GB)")
            result.append(f"Memory Usage: {mem.percent:.1f}%")
            result.append("")
            
            # Swap info
            swap_total_mb = swap.total // (1024 * 1024)
            swap_used_mb = swap.used // (1024 * 1024)
            swap_free_mb = swap.free // (1024 * 1024)
            
            result.append(f"Total Swap: {swap_total_mb} MB ({swap_total_mb // 1024} GB)")
            result.append(f"Used Swap: {swap_used_mb} MB ({swap_used_mb // 1024} GB)")
            result.append(f"Free Swap: {swap_free_mb} MB ({swap_free_mb // 1024} GB)")
            result.append(f"Swap Usage: {swap.percent:.1f}%")
            
        except ImportError:
            result.append("Error: Required library not installed")
            result.append("Please install: pip install psutil")
        except Exception as e:
            result.append(f"Error reading memory info: {str(e)}")
        
        self._emit_result("Memory Information", result)
    
    def get_kernel_info_windows(self):
        """Get kernel information on Windows"""
        result = []
        
        try:
            import platform
            import psutil
            
            result.append(f"System: {platform.system()}")
            result.append(f"Release: {platform.release()}")
            result.append(f"Version: {platform.version()}")
            result.append(f"Architecture: {platform.machine()}")
            result.append(f"Hostname: {platform.node()}")
            result.append(f"Processor: {platform.processor()}")
            
            # Get boot time
            boot_time = psutil.boot_time()
            import datetime
            boot_datetime = datetime.datetime.fromtimestamp(boot_time)
            result.append(f"Boot Time: {boot_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
            
            # Calculate uptime
            uptime_seconds = datetime.datetime.now().timestamp() - boot_time
            uptime_days = int(uptime_seconds // 86400)
            uptime_hours = int((uptime_seconds % 86400) // 3600)
            uptime_minutes = int((uptime_seconds % 3600) // 60)
            result.append(f"System Uptime: {uptime_days}d {uptime_hours}h {uptime_minutes}m")
            
        except Exception as e:
            result.append(f"Error reading kernel info: {str(e)}")
        
        self._emit_result("Kernel Information", result)
    
    def get_swap_info_windows(self):
        """Get swap information on Windows"""
        result = []
        
        try:
            import psutil
            
            swap = psutil.swap_memory()
            
            swap_total_mb = swap.total // (1024 * 1024)
            swap_used_mb = swap.used // (1024 * 1024)
            swap_free_mb = swap.free // (1024 * 1024)
            
            result.append(f"Total Swap: {swap_total_mb} MB ({swap_total_mb // 1024} GB)")
            result.append(f"Used Swap: {swap_used_mb} MB ({swap_used_mb // 1024} GB)")
            result.append(f"Free Swap: {swap_free_mb} MB ({swap_free_mb // 1024} GB)")
            result.append(f"Swap Usage: {swap.percent:.1f}%")
            
            # Get swap file info
            import wmi
            c = wmi.WMI()
            for pagefile in c.Win32_PageFileUsage():
                result.append("")
                result.append(f"Swap File: {pagefile.Name}")
                result.append(f"Allocated Size: {pagefile.AllocatedBaseSize} MB")
                result.append(f"Current Usage: {pagefile.CurrentUsage} MB")
                break
                
        except ImportError:
            result.append("Error: Required library not installed")
            result.append("Please install: pip install psutil wmi")
        except Exception as e:
            result.append(f"Error reading swap info: {str(e)}")
        
        self._emit_result("Swap Information", result)
    
    def get_disk_info_windows(self):
        """Get disk information on Windows"""
        result = []
        
        try:
            import psutil
            
            # Get disk usage
            result.append("━━━━━━ Disk Usage ━━━━━━")
            result.append("")
            for partition in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    result.append(f"Device: {partition.device}")
                    result.append(f"Mountpoint: {partition.mountpoint}")
                    result.append(f"File system: {partition.fstype}")
                    result.append(f"Total: {usage.total // (1024**3)} GB")
                    result.append(f"Used: {usage.used // (1024**3)} GB")
                    result.append(f"Free: {usage.free // (1024**3)} GB")
                    result.append(f"Usage: {usage.percent:.1f}%")
                    result.append("")
                except PermissionError:
                    continue
            
            # Get disk drives using WMI
            try:
                import wmi
                c = wmi.WMI()
                result.append("━━━━━━ Disk Drives ━━━━━━")
                result.append("")
                for disk in c.Win32_DiskDrive():
                    result.append(f"Model: {disk.Model}")
                    result.append(f"Size: {int(disk.Size) // (1024**3)} GB")
                    result.append(f"Interface: {disk.InterfaceType}")
                    result.append("")
            except ImportError:
                pass
                
        except ImportError:
            result.append("Error: Required library not installed")
            result.append("Please install: pip install psutil")
        except Exception as e:
            result.append(f"Error reading disk info: {str(e)}")
        
        output = "\n".join(result)
        self.data_ready.emit("Disk Information", output)
    
    def get_update_info(self):
        result = []
        
        distro = self._detect_distro()
        
        if distro in ["ubuntu", "debian", "mint", "pop", "zorin", "elementary"]:
            result = self._get_apt_updates()
        elif distro in ["fedora", "nobara", "rhel", "centos"]:
            result = self._get_dnf_updates()
        elif distro in ["arch", "cachyos", "manjaro", "endeavouros", "xerolinux", "garuda"]:
            result = self._get_pacman_updates()
        elif distro in ["opensuse", "suse"]:
            result = self._get_zypper_updates()
        else:
            result.append(f"Unsupported distribution: {distro}")
            result.append("Supported package managers: apt (Debian/Ubuntu), dnf (Fedora), pacman (Arch), zypper (openSUSE)")
        
        output = "\n".join(result)
        self.data_ready.emit("System Updates", output)
    
    def get_flatpak_update_info(self):
        """Get Flatpak update information"""
        result = []
        
        try:
            # Check if flatpak is installed
            result.append("Checking for Flatpak updates...")
            result.append("")
            
            check_cmd = subprocess.run(
                ["flatpak", "remote-ls", "--updates"],
                capture_output=True,
                text=True
            )
            
            if check_cmd.returncode == 0:
                updates = check_cmd.stdout.strip()
                if updates:
                    packages = [line for line in updates.split("\n") if line.strip()]
                    result.append(f"Available Flatpak updates: {len(packages)}")
                    result.append("")
                    for pkg in packages[:50]:
                        result.append(pkg)
                    if len(packages) > 50:
                        result.append(f"... and {len(packages) - 50} more packages")
                    result.append("")
                    result.append("")
                    result.append("To update Flatpak apps, run:")
                    result.append("  flatpak update")
                else:
                    result.append("No Flatpak updates available.")
            else:
                result.append("No Flatpak updates available.")
                
        except FileNotFoundError:
            result.append("Flatpak is not installed.")
            result.append("")
            result.append("To install Flatpak:")
            result.append("  sudo apt install flatpak  # Debian/Ubuntu")
            result.append("  sudo dnf install flatpak  # Fedora/RHEL")
            result.append("  sudo pacman -S flatpak    # Arch")
        except Exception as e:
            result.append(f"Error checking Flatpak updates: {str(e)}")
        
        output = "\n".join(result)
        self.data_ready.emit("Flatpak Updates", output)
    
    def _detect_distro(self):
        """Detect the Linux distribution"""
        if PlatformHelper.is_windows():
            return "windows"
        if PlatformHelper.is_macos():
            return "macos"
        
        try:
            with open("/etc/os-release", "r") as f:
                content = f.read()
            for line in content.split("\n"):
                if line.startswith("ID="):
                    distro = line.split("=", 1)[1].strip().strip('"').lower()
                    if distro == "pika":
                        distro = "pikaos"
                    return distro
        except (IOError, FileNotFoundError):
            pass
        return "unknown"
    
    def _get_apt_updates(self):
        """Get updates for apt-based systems"""
        result = []
        
        try:
            result.append("Checking for updates (apt)...")
            result.append("")
            
            output = subprocess.check_output(
                ["apt", "list", "--upgradable"], 
                stderr=subprocess.DEVNULL, 
                text=True
            )
            
            packages = []
            for line in output.split("\n"):
                if "/" in line and line.strip():
                    packages.append(line.strip())
            
            if packages:
                result.append(f"Upgradable packages: {len(packages)}")
                result.append("")
                for pkg in packages[:50]:
                    result.append(pkg)
                if len(packages) > 50:
                    result.append(f"... and {len(packages) - 50} more packages")
                result.append("")
                result.append("")
                result.append("To update, run:")
                result.append("  sudo apt update && sudo apt upgrade")
            else:
                result.append("No updates available.")
            
            try:
                security_output = subprocess.check_output(
                    ["apt", "list", "--upgradable"],
                    stderr=subprocess.DEVNULL,
                    text=True
                )
                security_packages = [line for line in security_output.split("\n") if "security" in line.lower()]
                if security_packages:
                    result.append("")
                    result.append(f"Security updates: {len(security_packages)}")
            except:
                pass
            
        except subprocess.CalledProcessError:
            result.append("Error: Unable to check for updates.")
        except Exception as e:
            result.append(f"Error: {str(e)}")
        
        return result
    
    def _get_dnf_updates(self):
        """Get updates for dnf-based systems"""
        result = []
        
        try:
            result.append("Checking for updates (dnf)...")
            result.append("")
            
            output = subprocess.check_output(
                ["dnf", "check-update", "--quiet"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            
            packages = []
            for line in output.split("\n"):
                if line.strip() and not line.startswith(("Last metadata", "Upgraded Packages", "Obsoleting")):
                    packages.append(line.strip())
            
            if packages:
                result.append(f"Upgradable packages: {len(packages)}")
                result.append("")
                for pkg in packages[:50]:
                    result.append(pkg)
                if len(packages) > 50:
                    result.append(f"... and {len(packages) - 50} more packages")
                result.append("")
                result.append("")
                result.append("To update, run:")
                result.append("  sudo dnf upgrade")
            else:
                result.append("No updates available.")
            
        except subprocess.CalledProcessError as e:
            if e.returncode == 100:
                result.append("Updates available, but unable to list details.")
                result.append("")
                result.append("To update, run:")
                result.append("  sudo dnf upgrade")
            else:
                result.append("Error: Unable to check for updates.")
        except Exception as e:
            result.append(f"Error: {str(e)}")
        
        return result
    
    def _get_pacman_updates(self):
        """Get updates for pacman-based systems"""
        result = []
        
        try:
            result.append("Checking for updates (pacman)...")
            result.append("")
            
            output = subprocess.check_output(
                ["checkupdates"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            
            packages = []
            for line in output.split("\n"):
                if line.strip():
                    packages.append(line.strip())
            
            if packages:
                result.append(f"Upgradable packages: {len(packages)}")
                result.append("")
                for pkg in packages[:50]:
                    result.append(pkg)
                if len(packages) > 50:
                    result.append(f"... and {len(packages) - 50} more packages")
                result.append("")
                result.append("")
                result.append("To update, run:")
                result.append("  sudo pacman -Syu")
            else:
                result.append("No updates available.")
            
        except subprocess.CalledProcessError as e:
            if e.returncode == 2:
                result.append("Updates available.")
                result.append("")
                result.append("To update, run:")
                result.append("  sudo pacman -Syu")
            else:
                result.append("Error: Unable to check for updates.")
        except FileNotFoundError:
            result.append("Error: checkupdates command not found.")
            result.append("Make sure 'pacman-contrib' is installed:")
            result.append("  sudo pacman -S pacman-contrib")
        except Exception as e:
            result.append(f"Error: {str(e)}")
        
        return result
    
    def _get_zypper_updates(self):
        """Get updates for zypper-based systems"""
        result = []
        
        try:
            result.append("Checking for updates (zypper)...")
            result.append("")
            
            output = subprocess.check_output(
                ["zypper", "list-updates", "--type", "patch"],
                stderr=subprocess.DEVNULL,
                text=True
            )
            
            patches = [line for line in output.split("\n") if line.strip() and not line.startswith(("S", "|", "-", "+"))]
            
            if patches:
                result.append(f"Available patches: {len(patches)}")
                result.append("")
                for patch in patches[:50]:
                    result.append(patch)
                if len(patches) > 50:
                    result.append(f"... and {len(patches) - 50} more patches")
                result.append("")
                result.append("")
                result.append("To update, run:")
                result.append("  sudo zypper patch")
            else:
                result.append("No updates available.")
            
        except subprocess.CalledProcessError:
            result.append("Error: Unable to check for updates.")
        except Exception as e:
            result.append(f"Error: {str(e)}")
        
        return result


class MiniToolsGUI(QMainWindow):
    data_ready_signal = pyqtSignal(str, str)
    error_signal = pyqtSignal(str)
    
    def __init__(self):
        super().__init__()
        
        self.setWindowTitle(__app_name__)
        
        # Set window icon
        self._set_window_icon()
        
        screen = self.screen().availableGeometry()
        screen_width = screen.width()
        screen_height = screen.height()
        
        min_width = max(Config.MIN_WINDOW_WIDTH, int(screen_width * 0.7))
        min_height = max(Config.MIN_WINDOW_HEIGHT, int(screen_height * 0.7))
        self.setMinimumSize(min_width, min_height)
        
        default_width = min(Config.DEFAULT_WINDOW_WIDTH, int(screen_width * 0.8))
        default_height = min(Config.DEFAULT_WINDOW_HEIGHT, int(screen_height * 0.8))
        self.resize(default_width, default_height)
        
        self.dark_mode = True
        self.log_font_size = Config.DEFAULT_LOG_FONT_SIZE
        self.info_worker = None
        self.log_history = []  # Store log messages for theme refresh
        
        self.create_ui()
        self.apply_theme()
        self.center_window()
        
        self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", LogLevel.INFO)
        self.log(f"{__app_name__} - Ready", LogLevel.INFO)
        self.log(f"Version: {__version__}", LogLevel.INFO)
        self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
        self.log("Welcome! Click any button to use the tools.", LogLevel.INFO)
        
        # Auto-detect and run fastfetch/neofetch on startup
        QTimer.singleShot(500, self._auto_run_fetch_tool)
    
    def _show_system_overview(self):
        """Show quick system overview on startup"""
        self.log("Loading system overview...", LogLevel.INFO)
        self.show_cpu_info()
    
    def _auto_run_fetch_tool(self):
        """Auto-detect and run fastfetch/neofetch on startup"""
        # On Windows, use built-in fastfetch
        if PlatformHelper.is_windows():
            self._run_builtin_fastfetch()
        # On Linux/macOS, check for fastfetch first
        elif shutil.which("fastfetch"):
            self.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", LogLevel.INFO)
            self.log("Running fastfetch", LogLevel.SUCCESS)
            self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
            self._run_fetch_command("fastfetch", "--logo", "none", "--color", "none", "--structure", "title:separator:os:kernel:uptime:packages:shell:resolution:de:wm:theme:terminal:cpu:gpu:memory")
        # Check for neofetch as fallback
        elif shutil.which("neofetch"):
            self.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", LogLevel.INFO)
            self.log("Running neofetch", LogLevel.SUCCESS)
            self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
            self._run_fetch_command("neofetch", "--config", "none", "--disable", "logo", "color", "cpu", "gpu")
        else:
            self.log("\nNote: fastfetch or neofetch not installed.", LogLevel.INFO)
            self.log("Install one of them for better system overview.", LogLevel.INFO)
            self.log("  Debian/Ubuntu: sudo apt install fastfetch")
            self.log("  Fedora/RHEL: sudo dnf install fastfetch")
            self.log("  Arch: sudo pacman -S fastfetch\n", LogLevel.INFO)
    
    def _run_fetch_command(self, command, *args):
        """Run fetch command and display output"""
        try:
            cmd_list = [command] + list(args)
            process = subprocess.Popen(
                cmd_list,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            stdout, stderr = process.communicate()
            
            if process.returncode == 0:
                # Display output line by line
                for line in stdout.split('\n'):
                    if line.strip():
                        self.log(line, LogLevel.INFO)
                self.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
            else:
                self.log(f"Error running {command}: {stderr}", LogLevel.ERROR)
                
        except Exception as e:
            self.log(f"Error running {command}: {str(e)}", LogLevel.ERROR)
    
    def _run_builtin_fastfetch(self):
        """Run built-in fastfetch for Windows"""
        try:
            import platform
            import psutil
            import wmi
            import datetime
            
            self.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", LogLevel.INFO)
            self.log("System Overview", LogLevel.SUCCESS)
            self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
            
            # OS Info
            self.log(f"OS: {platform.system()} {platform.release()}", LogLevel.INFO)
            
            # Kernel/Version
            self.log(f"Kernel: {platform.version()}", LogLevel.INFO)
            
            # Uptime
            boot_time = psutil.boot_time()
            uptime_seconds = datetime.datetime.now().timestamp() - boot_time
            uptime_days = int(uptime_seconds // 86400)
            uptime_hours = int((uptime_seconds % 86400) // 3600)
            uptime_minutes = int((uptime_seconds % 3600) // 60)
            self.log(f"Uptime: {uptime_days}d {uptime_hours}h {uptime_minutes}m", LogLevel.INFO)
            
            # Hostname
            self.log(f"Host: {platform.node()}", LogLevel.INFO)
            
            # Shell
            self.log("Shell: Windows PowerShell / CMD", LogLevel.INFO)
            
            # Resolution
            try:
                import ctypes
                user32 = ctypes.windll.user32
                width = user32.GetSystemMetrics(0)
                height = user32.GetSystemMetrics(1)
                self.log(f"Resolution: {width}x{height}", LogLevel.INFO)
            except:
                pass
            
            # DE/WM
            self.log("DE/WM: Windows Desktop", LogLevel.INFO)
            
            # Theme
            try:
                import winreg
                key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")
                apps_use_light_theme = winreg.QueryValueEx(key, "AppsUseLightTheme")[0]
                theme = "Light" if apps_use_light_theme else "Dark"
                self.log(f"Theme: {theme}", LogLevel.INFO)
                winreg.CloseKey(key)
            except:
                pass
            
            # Terminal
            self.log("Terminal: Windows Terminal", LogLevel.INFO)
            
            # CPU
            c = wmi.WMI()
            for cpu in c.Win32_Processor():
                self.log(f"CPU: {cpu.Name}", LogLevel.INFO)
                self.log(f"     Cores: {cpu.NumberOfCores} | Threads: {cpu.NumberOfLogicalProcessors}", LogLevel.INFO)
                self.log(f"     Max Speed: {cpu.MaxClockSpeed / 1000:.2f} GHz", LogLevel.INFO)
                break
            
            # GPU
            for gpu in c.Win32_VideoController():
                self.log(f"GPU: {gpu.Name}", LogLevel.INFO)
                self.log(f"     VRAM: {int(gpu.AdapterRAM) // (1024**2)} MB", LogLevel.INFO)
                break
            
            # Memory
            mem = psutil.virtual_memory()
            self.log(f"Memory: {mem.total // (1024**3)} GB", LogLevel.INFO)
            self.log(f"       Used: {mem.used // (1024**3)} GB ({mem.percent:.1f}%)", LogLevel.INFO)
            self.log(f"       Available: {mem.available // (1024**3)} GB", LogLevel.INFO)
            
            self.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
            
        except ImportError as e:
            self.log(f"Error: Required library not installed: {str(e)}", LogLevel.ERROR)
            self.log("Please install: pip install psutil wmi", LogLevel.INFO)
        except Exception as e:
            self.log(f"Error running built-in fastfetch: {str(e)}", LogLevel.ERROR)
    
    def _set_window_icon(self):
        """Set window icon for the application"""
        try:
            # For development mode, load icon from file
            if not getattr(sys, 'frozen', False):
                script_dir = os.path.dirname(os.path.abspath(__file__))
                icon_path = None
                
                if PlatformHelper.is_windows():
                    icon_path = os.path.join(script_dir, "minitools.ico")
                elif PlatformHelper.is_macos():
                    icon_path = os.path.join(script_dir, "minitools.icns")
                else:
                    # Linux: try .png or .svg
                    if os.path.exists(os.path.join(script_dir, "minitools.png")):
                        icon_path = os.path.join(script_dir, "minitools.png")
                    elif os.path.exists(os.path.join(script_dir, "minitools.svg")):
                        icon_path = os.path.join(script_dir, "minitools.svg")
                
                if icon_path and os.path.exists(icon_path):
                    icon = QIcon(icon_path)
                    self.setWindowIcon(icon)
                    
                    # Also set the application icon for Windows taskbar
                    app = QApplication.instance()
                    if app:
                        app.setWindowIcon(icon)
            # For compiled EXE, icon is embedded in the executable by PyInstaller
            # No need to load it separately
        except Exception as e:
            # Fail silently - icon is not critical
            pass
    
    def center_window(self):
        """Center window on screen"""
        frame = self.frameGeometry()
        screen = self.screen().availableGeometry().center()
        frame.moveCenter(screen)
        self.move(frame.topLeft())
    
    def log(self, message: str, level: LogLevel = LogLevel.INFO) -> None:
        """Add a message to the log
        
        Args:
            message: The message to log
            level: Log level (INFO, SUCCESS, WARNING, ERROR)
        """
        if not hasattr(self, 'log_text'):
            return
        
        timestamp = QDateTime.currentDateTime().toString("HH:mm:ss")
        
        # Choose colors based on theme
        colors = Config.DARK_COLORS if self.dark_mode else Config.LIGHT_COLORS
        color = colors.get(level.value, colors[LogLevel.INFO.value])
        timestamp_color = colors["timestamp"]
        
        # Convert URLs to clickable links
        import re
        url_pattern = r'https?://[^\s<>"]+|www\.[^\s<>"]+'
        message_with_links = re.sub(
            url_pattern,
            lambda m: f'<a href="{m.group(0)}" style="color: #4da6ff; text-decoration: underline;">{m.group(0)}</a>',
            message
        )
        
        formatted_message = f'<span style="color: {timestamp_color};">[{timestamp}]</span> <span style="color: {color}; font-size: {self.log_font_size}pt;">{message_with_links}</span>'
        
        # Save to history
        self.log_history.append((message, level.value))
        
        self.log_text.append(formatted_message)
    
    def toggle_theme(self):
        """Toggle between dark and light themes"""
        self.dark_mode = not self.dark_mode
        self.apply_theme()
        
        if self.dark_mode:
            self.theme_toggle_btn.setText("☀")
            self.theme_toggle_btn.setToolTip("Switch to Light Mode")
        else:
            self.theme_toggle_btn.setText("🌙")
            self.theme_toggle_btn.setToolTip("Switch to Dark Mode")
        
        self._update_right_scroll_style()
        self._refresh_log_colors()  # Refresh log colors for new theme
    
    def _refresh_log_colors(self):
        """Refresh all log messages with new theme colors"""
        if not hasattr(self, 'log_text'):
            return
        
        self.log_text.clear()
        self._redisplay_log_messages(update_font=True)
    
    def _redisplay_log_messages(self, update_font: bool = False):
        """
        Re-display all log messages from history
        
        Args:
            update_font: Whether to update font size in the messages
        """
        colors = Config.DARK_COLORS if self.dark_mode else Config.LIGHT_COLORS
        
        for message, level in self.log_history:
            timestamp = QDateTime.currentDateTime().toString("HH:mm:ss")
            color = colors.get(level, colors["info"])
            timestamp_color = colors["timestamp"]
            
            if update_font:
                formatted_message = f'<span style="color: {timestamp_color};">[{timestamp}]</span> <span style="color: {color}; font-size: {self.log_font_size}pt;">{message}</span>'
            else:
                formatted_message = f'<span style="color: {timestamp_color};">[{timestamp}]</span> <span style="color: {color};">{message}</span>'
            
            self.log_text.append(formatted_message)
    
    def confirm_exit(self):
        """Confirm exit with dialog"""
        reply = QMessageBox.question(
            self,
            "Exit Mini Tools",
            "Are you sure you want to exit?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            self.close()
    
    def show_about(self):
        """Show about information"""
        about_text = f"""
MiniTools<br>
Version: {__version__}<br>
<br>
Dependencies:<br>
- Python 3.6+<br>
- PyQt6<br>
<br>
Author: {__author__}<br>
<br>
License: GNU General Public License v3.0 (GPL-3.0)<br>
<br>
This program is free software: you can redistribute it and/or modify<br>
it under the terms of the GNU General Public License as published by<br>
the Free Software Foundation, either version 3 of the License, or<br>
(at your option) any later version.<br>
<br>
This program is distributed in the hope that it will be useful,<br>
but WITHOUT ANY WARRANTY; without even the implied warranty of<br>
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the<br>
GNU General Public License for more details.<br>
<br>
You should have received a copy of the GNU General Public License<br>
along with this program.  If not, see &lt;<a href="https://www.gnu.org/licenses/">https://www.gnu.org/licenses/</a>&gt;.
"""
        
        msg_box = QMessageBox(self)
        msg_box.setWindowTitle("About MiniTools")
        msg_box.setTextFormat(Qt.TextFormat.RichText)
        msg_box.setText(about_text)
        msg_box.setInformativeText(
            'Repository: <a href="https://github.com/Perrolito/MiniTools.py">https://github.com/Perrolito/MiniTools.py</a>'
        )
        msg_box.exec()
    
    def change_partition_uuid(self):
        """Change partition UUID"""
        if PlatformHelper.is_windows():
            self.log("\n" + "="*80, LogLevel.INFO)
            self.log("Change Partition UUID - Not Available on Windows", LogLevel.WARNING)
            self.log("="*80 + "\n", LogLevel.INFO)
            self.log("This feature is not available on Windows.\n", LogLevel.INFO)
            self.log("On Windows, you can use diskpart to manage disk IDs:\n", LogLevel.INFO)
            self.log("1. Open Command Prompt as Administrator\n", LogLevel.INFO)
            self.log("2. Run: diskpart\n", LogLevel.INFO)
            self.log("3. Run: list disk\n", LogLevel.INFO)
            self.log("4. Run: select disk X (replace X with disk number)\n", LogLevel.INFO)
            self.log("5. Run: list partition\n", LogLevel.INFO)
            self.log("6. Run: select partition Y (replace Y with partition number)\n", LogLevel.INFO)
            self.log("7. Run: uniqueid disk\n", LogLevel.INFO)
            return
        
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log("Change Partition UUID", LogLevel.WARNING)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        # Get partition device
        partition_device, ok = QInputDialog.getText(
            self,
            "Change Partition UUID",
            "Enter partition device (e.g., /dev/sda1):",
            QLineEdit.EchoMode.Normal
        )
        
        if not ok or not partition_device:
            self.log("Operation cancelled.\n", LogLevel.INFO)
            return
        
        partition_device = partition_device.strip()
        
        # Validate partition device
        if not partition_device.startswith("/dev/"):
            self.log(f"Error: Invalid partition device '{partition_device}'. Must start with /dev/\n", LogLevel.ERROR)
            return
        
        self.log(f"Partition device: {partition_device}", LogLevel.INFO)
        
        # Detect partition filesystem type
        self.log("Detecting partition filesystem type...", LogLevel.INFO)
        try:
            result = subprocess.run(
                ["pkexec", "blkid", "-o", "value", "-s", "TYPE", partition_device],
                capture_output=True,
                text=True
            )
            filesystem = result.stdout.strip()
            returncode = result.returncode
            
            self.log(f"blkid return code: {returncode}", LogLevel.INFO)
            self.log(f"blkid stdout: '{filesystem}'", LogLevel.INFO)
            if result.stderr:
                self.log(f"blkid stderr: {result.stderr.strip()}", LogLevel.WARNING)
            
            if not filesystem:
                self.log(f"Error: Could not detect filesystem type for {partition_device}\n", LogLevel.ERROR)
                self.log("Possible reasons:", LogLevel.INFO)
                self.log("  - Device does not exist", LogLevel.INFO)
                self.log("  - Device is not a partition (may be a disk itself)", LogLevel.INFO)
                self.log("  - Device has no filesystem (not formatted)", LogLevel.INFO)
                self.log("  - Device is not accessible (permissions)\n", LogLevel.INFO)
                return
            
            self.log(f"Detected filesystem: {filesystem}\n", LogLevel.SUCCESS)
        except Exception as e:
            self.log(f"Error detecting filesystem: {str(e)}\n", LogLevel.ERROR)
            return
        
        # Show partition information
        self.log("Partition Information:", LogLevel.INFO)
        self.log(f"  Device: {partition_device}", LogLevel.INFO)
        self.log(f"  Filesystem: {filesystem}", LogLevel.INFO)
        
        try:
            result = subprocess.run(
                ["pkexec", "blkid", partition_device],
                capture_output=True,
                text=True
            )
            self.log(f"  Current info: {result.stdout.strip()}", LogLevel.INFO)
        except Exception as e:
            self.log(f"  Could not get current info: {str(e)}", LogLevel.WARNING)
        
        self.log("")
        
        # Generate new UUID
        import uuid
        new_uuid = str(uuid.uuid4())
        self.log(f"Generated new UUID: {new_uuid}\n", LogLevel.WARNING)
        
        # Show confirmation dialog with details
        confirmation_text = f"""
Are you sure you want to change the UUID for this partition?

Partition Device: {partition_device}
Filesystem: {filesystem}
New UUID: {new_uuid}

This operation will modify the partition's UUID.
This may affect boot configuration and fstab entries.

Please verify the information above is correct.
"""
        
        reply = QMessageBox.question(
            self,
            "Confirm UUID Change",
            confirmation_text,
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply != QMessageBox.StandardButton.Yes:
            self.log("Operation cancelled by user.\n", LogLevel.INFO)
            return
        
        self.log("Changing partition UUID...", LogLevel.WARNING)
        
        # Execute UUID change command
        try:
            if filesystem in ["ext2", "ext3", "ext4"]:
                command = ["pkexec", "tune2fs", "-U", new_uuid, partition_device]
            elif filesystem in ["xfs"]:
                command = ["pkexec", "xfs_admin", "-U", new_uuid, partition_device]
            elif filesystem in ["btrfs"]:
                command = ["pkexec", "btrfstune", "-u", new_uuid, partition_device]
            elif filesystem in ["vfat", "fat32"]:
                self.log("Warning: FAT32 filesystem does not support UUID change directly.\n", LogLevel.WARNING)
                self.log("You may need to reformat the partition.\n", LogLevel.WARNING)
                return
            elif filesystem in ["swap"]:
                command = ["pkexec", "mkswap", "-U", new_uuid, partition_device]
            else:
                self.log(f"Error: Unsupported filesystem '{filesystem}' for UUID change\n", LogLevel.ERROR)
                self.log("Supported filesystems: ext2, ext3, ext4, xfs, btrfs, swap\n", LogLevel.INFO)
                return
            
            self.log(f"Executing command: {' '.join(command)}\n", LogLevel.INFO)
            
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            def read_output():
                while True:
                    output = process.stdout.readline()
                    if output == '' and process.poll() is not None:
                        break
                    if output:
                        self.log(output.strip(), LogLevel.INFO)
                        QApplication.processEvents()
            
            import threading
            output_thread = threading.Thread(target=read_output)
            output_thread.daemon = True
            output_thread.start()
            
            return_code = process.wait()
            output_thread.join(timeout=2)
            
            if return_code == 0:
                self.log("\n✓ Partition UUID changed successfully!\n", LogLevel.SUCCESS)
                
                # Show new partition info
                try:
                    result = subprocess.run(
                        ["pkexec", "blkid", partition_device],
                        capture_output=True,
                        text=True
                    )
                    self.log("New partition info:", LogLevel.INFO)
                    self.log(f"  {result.stdout.strip()}\n", LogLevel.INFO)
                except Exception as e:
                    self.log(f"Could not get new partition info: {str(e)}\n", LogLevel.WARNING)
                
                self.log("Note: If this is a boot partition, you may need to update:", "warning")
                self.log("  - /etc/fstab entries", LogLevel.WARNING)
                self.log("  - GRUB configuration (run: sudo update-grub)", LogLevel.WARNING)
                self.log("  - Bootloader configuration\n", LogLevel.WARNING)
            else:
                self.log(f"\n✗ Failed to change partition UUID. Error code: {return_code}\n", LogLevel.ERROR)
                
        except Exception as e:
            self.log(f"\n✗ Error during UUID change: {str(e)}\n", LogLevel.ERROR)
    
    def execute_extension_script(self, script_path, script_name):
        """Execute extension script"""
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log(f"Execute Extension: {script_name}", LogLevel.WARNING)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        # Show confirmation dialog
        reply = QMessageBox.question(
            self,
            "Execute Extension Script",
            f"Are you sure you want to execute this extension script?\n\nScript: {script_name}\nPath: {script_path}\n\nThis script will run with your user permissions.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply != QMessageBox.StandardButton.Yes:
            self.log("Operation cancelled.\n", LogLevel.INFO)
            return
        
        self.log(f"Executing: {script_path}\n", LogLevel.WARNING)
        
        try:
            # Determine how to run the script
            if script_path.endswith('.sh'):
                command = ["bash", script_path]
            elif script_path.endswith('.py'):
                command = [sys.executable, script_path]
            else:
                self.log(f"Error: Unsupported script type\n", LogLevel.ERROR)
                return
            
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            def read_output():
                while True:
                    output = process.stdout.readline()
                    if output == '' and process.poll() is not None:
                        break
                    if output:
                        self.log(output.strip(), LogLevel.INFO)
                        QApplication.processEvents()
            
            import threading
            output_thread = threading.Thread(target=read_output)
            output_thread.daemon = True
            output_thread.start()
            
            return_code = process.wait()
            output_thread.join(timeout=2)
            
            if return_code == 0:
                self.log(f"\n✓ Extension script executed successfully!\n", LogLevel.SUCCESS)
            else:
                self.log(f"\n✗ Extension script failed with exit code: {return_code}\n", LogLevel.ERROR)
                
        except Exception as e:
            self.log(f"\n✗ Error executing extension script: {str(e)}\n", LogLevel.ERROR)
    
    def show_extensions_info(self):
        """Show extensions information"""
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log("Extensions Directory", LogLevel.INFO)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        self.log(f"Extensions path: {self.extensions_dir}", LogLevel.INFO)
        self.log("", LogLevel.INFO)
        
        if not os.path.exists(self.extensions_dir):
            self.log("Directory does not exist.", LogLevel.WARNING)
            if PlatformHelper.is_windows():
                self.log(f"Create it in File Explorer: {self.extensions_dir}", LogLevel.INFO)
            else:
                self.log(f"Create it with: mkdir -p {self.extensions_dir}", LogLevel.INFO)
        else:
            self.log("Directory exists.", LogLevel.SUCCESS)
        
        self.log("", LogLevel.INFO)
        self.log("How to add extensions:", LogLevel.INFO)
        self.log("1. Place .sh (shell) or .py (Python) scripts in the extensions directory", LogLevel.INFO)
        self.log("2. Restart MiniTools to see your extensions", LogLevel.INFO)
        self.log("3. Click an extension button to execute it", LogLevel.INFO)
        self.log("", LogLevel.INFO)
        self.log("Supported file types:", LogLevel.INFO)
        self.log("  - .sh - Shell scripts (executed with bash)", LogLevel.INFO)
        self.log("  - .py - Python scripts (executed with python3)", LogLevel.INFO)
        self.log("", LogLevel.INFO)
        self.log("Scripts will be executed with your user permissions.\n", LogLevel.WARNING)
    
    def zoom_in_log(self):
        """Increase log font size"""
        if not hasattr(self, 'log_text'):
            return
        
        new_size = min(self.log_font_size + 1, Config.MAX_LOG_FONT_SIZE)
        if new_size != self.log_font_size:
            self.log_font_size = new_size
            if hasattr(self, 'font_size_label'):
                self.font_size_label.setText(str(self.log_font_size))
            self._update_zoom_buttons()
            self._refresh_log_with_new_size()
    
    def zoom_out_log(self):
        """Decrease log font size"""
        if not hasattr(self, 'log_text'):
            return
        
        new_size = max(self.log_font_size - 1, Config.MIN_LOG_FONT_SIZE)
        if new_size != self.log_font_size:
            self.log_font_size = new_size
            if hasattr(self, 'font_size_label'):
                self.font_size_label.setText(str(self.log_font_size))
            self._update_zoom_buttons()
            self._refresh_log_with_new_size()
    
    def _refresh_log_with_new_size(self):
        """Refresh log with new font size"""
        if not hasattr(self, 'log_text'):
            return
        
        self.log_text.clear()
        self._redisplay_log_messages(update_font=True)
    
    def _update_zoom_buttons(self):
        """Update zoom button states"""
        if not hasattr(self, 'log_text') or not hasattr(self, 'zoom_in_btn') or not hasattr(self, 'zoom_out_btn'):
            return
        
        self.zoom_in_btn.setEnabled(self.log_font_size < Config.MAX_LOG_FONT_SIZE)
        self.zoom_out_btn.setEnabled(self.log_font_size > Config.MIN_LOG_FONT_SIZE)
    
    def apply_theme(self):
        """Apply current theme (dark or light)"""
        if self.dark_mode:
            self._apply_dark_theme()
        else:
            self._apply_light_theme()
    
    def _apply_dark_theme(self):
        """Apply modern dark theme"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #1a1a1a;
            }
            QWidget {
                background-color: #1a1a1a;
                color: #e0e0e0;
                font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
                font-size: 13px;
            }
            QFrame#topBar {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #2a2a2a, stop:1 #1f1f1f);
                border-bottom: 2px solid #333333;
            }
            QLabel#titleLabel {
                font-size: 20px;
                font-weight: 600;
                color: #ffffff;
                letter-spacing: -0.5px;
                background-color: transparent;
                border: none;
                padding: 0px;
            }
            QPushButton#themeToggle {
                background-color: #333333;
                color: #e0e0e0;
                border: 1px solid #444444;
                border-radius: 8px;
                font-size: 18px;
            }
            QPushButton#themeToggle:hover {
                background-color: #3d3d3d;
                border-color: #555555;
            }
            QPushButton#exitButton {
                background-color: #333333;
                color: #e0e0e0;
                border: 1px solid #444444;
                border-radius: 8px;
                font-size: 18px;
            }
            QPushButton#exitButton:hover {
                background-color: #d32f2f;
                border-color: #e53935;
                color: #ffffff;
            }
            QPushButton#exitButton:pressed {
                background-color: #b71c1c;
            }
            QWidget#contentArea {
                background-color: #1a1a1a;
            }
            QFrame#infoCard {
                background-color: #252525;
                border: 1px solid #333333;
                border-radius: 12px;
            }
            QLabel#sectionTitle {
                font-size: 16px;
                font-weight: 600;
                color: #ffffff;
                background-color: transparent;
                border: none;
                padding: 0px;
            }
            QFrame#logSection {
                background-color: #1e1e1e;
                border: 1px solid #2d2d2d;
                border-radius: 8px;
                padding: 12px;
            }
            QFrame#zoomToolbar {
                background-color: transparent;
                border: none;
            }
            QPushButton#zoomButton {
                background-color: #2d2d2d;
                color: #b0b0b0;
                border: 1px solid #3d3d3d;
                border-radius: 6px;
                font-size: 18px;
                font-weight: bold;
            }
            QPushButton#zoomButton:hover {
                background-color: #3a3a3a;
                border-color: #4a4a4a;
                color: #ffffff;
            }
            QPushButton#zoomButton:pressed {
                background-color: #252525;
            }
            QPushButton#zoomButton:disabled {
                background-color: #252525;
                color: #555555;
                border-color: #2d2d2d;
            }
            QLabel#fontSizeLabel {
                background-color: transparent;
                color: #888888;
                font-size: 12px;
                font-weight: bold;
                min-width: 24px;
            }
            QTextEdit#logText {
                background-color: #0d0d0d;
                color: #d4d4d4;
                border: 1px solid #2d2d2d;
                border-radius: 8px;
                font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
                padding: 12px;
                selection-background-color: #007acc;
            }
            QFrame#buttonCard {
                background-color: #252525;
                border: 1px solid #333333;
                border-radius: 12px;
            }
            QPushButton#actionButton {
                background-color: #2d2d2d;
                color: #e0e0e0;
                border: 1px solid #3d3d3d;
                padding: 12px 16px;
                border-radius: 8px;
                font-size: 13px;
                font-weight: 500;
                text-align: left;
                min-width: 200px;
            }
            QPushButton#actionButton:hover {
                background-color: #353535;
                border-color: #4d4d4d;
                color: #ffffff;
            }
            QPushButton#actionButton:pressed {
                background-color: #252525;
                border-color: #3d3d3d;
            }
            /* Dialog Styles */
            QDialog {
                background-color: #252526;
                color: #dcdcdc;
                border-radius: 12px;
            }
            QDialog QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #dcdcdc;
            }
            QDialog QLabel#titleLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                font-size: 18px;
                font-weight: 600;
                color: #ffffff;
            }
            QDialog QLabel#descriptionLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #999999;
            }
            QMessageBox {
                background-color: #252526;
                color: #dcdcdc;
                border-radius: 12px;
            }
            QMessageBox QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #dcdcdc;
                font-size: 13px;
                line-height: 1.4;
            }
            QMessageBox QPushButton {
                background-color: #3c3c3c;
                color: #f0f0f0;
                border: 1px solid #555555;
                border-radius: 8px;
                min-width: 100px;
                padding: 10px 20px;
                font-size: 13px;
                font-weight: 500;
            }
            QMessageBox QPushButton:hover {
                background-color: #4a4a4a;
                border-color: #6a6a6a;
            }
            QMessageBox QPushButton:pressed {
                background-color: #2d2d2d;
            }
            QMessageBox QPushButton[default="true"] {
                background-color: #4ec9b0;
                color: #1e1e1e;
                border: 1px solid #4ec9b0;
                font-weight: bold;
            }
            QMessageBox QPushButton[default="true"]:hover {
                background-color: #5dd9c0;
                border-color: #5dd9c0;
            }
            QMessageBox QPushButton[default="true"]:pressed {
                background-color: #3db9a0;
            }
            QInputDialog {
                background-color: #252526;
                color: #dcdcdc;
                border-radius: 12px;
            }
            QInputDialog QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #dcdcdc;
            }
            QInputDialog QLineEdit {
                background-color: #1a1a1a;
                color: #d4d4d4;
                border: 1px solid #3d3d3d;
                border-radius: 6px;
                padding: 8px 12px;
                font-size: 13px;
                selection-background-color: #4ec9b0;
            }
            QInputDialog QLineEdit:focus {
                border: 2px solid #4ec9b0;
            }
            /* All QDialog QPushButton styles */
            QDialog QPushButton {
                background-color: #3c3c3c;
                color: #f0f0f0;
                border: 1px solid #555555;
                border-radius: 8px;
                min-width: 100px;
                padding: 10px 20px;
                font-size: 13px;
                font-weight: 500;
            }
            QDialog QPushButton:hover {
                background-color: #4a4a4a;
                border-color: #6a6a6a;
            }
            QDialog QPushButton:pressed {
                background-color: #2d2d2d;
            }
            QDialog QPushButton[default="true"] {
                background-color: #4ec9b0;
                color: #1e1e1e;
                border: 1px solid #4ec9b0;
                font-weight: bold;
            }
            QDialog QPushButton[default="true"]:hover {
                background-color: #5dd9c0;
                border-color: #5dd9c0;
            }
            QDialog QPushButton[default="true"]:pressed {
                background-color: #3db9a0;
            }
            QFileDialog {
                background-color: #252526;
                color: #dcdcdc;
                border-radius: 12px;
            }
            QFileDialog QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #dcdcdc;
            }
            QFileDialog QLineEdit {
                background-color: #1a1a1a;
                color: #d4d4d4;
                border: 1px solid #3d3d3d;
                border-radius: 6px;
                padding: 8px 12px;
                font-size: 13px;
                selection-background-color: #4ec9b0;
            }
            QFileDialog QLineEdit:focus {
                border: 2px solid #4ec9b0;
            }
            QFileDialog QTreeView {
                background-color: #1a1a1a;
                color: #d4d4d4;
                alternate-background-color: #252526;
                border: 1px solid #3d3d3d;
                border-radius: 6px;
            }
            QFileDialog QTreeView::item {
                padding: 6px 8px;
            }
            QFileDialog QTreeView::item:selected {
                background-color: #4ec9b0;
                color: #1e1e1e;
            }
            QFileDialog QListView {
                background-color: #1a1a1a;
                color: #d4d4d4;
                alternate-background-color: #252526;
                border: 1px solid #3d3d3d;
                border-radius: 6px;
            }
            QFileDialog QListView::item {
                padding: 6px 8px;
            }
            QFileDialog QListView::item:selected {
                background-color: #4ec9b0;
                color: #1e1e1e;
            }
            QFileDialog QPushButton {
                background-color: #3c3c3c;
                color: #f0f0f0;
                border: 1px solid #555555;
                border-radius: 8px;
                min-width: 100px;
                padding: 10px 20px;
                font-size: 13px;
                font-weight: 500;
            }
            QFileDialog QPushButton:hover {
                background-color: #4a4a4a;
                border-color: #6a6a6a;
            }
            QFileDialog QPushButton:pressed {
                background-color: #2d2d2d;
            }
            QFileDialog QPushButton[default="true"] {
                background-color: #4ec9b0;
                color: #1e1e1e;
                border: 1px solid #4ec9b0;
                font-weight: bold;
            }
            QFileDialog QPushButton[default="true"]:hover {
                background-color: #5dd9c0;
                border-color: #5dd9c0;
            }
            QFileDialog QPushButton[default="true"]:pressed {
                background-color: #3db9a0;
            }
            QToolTip {
                background-color: #1d1d1f;
                color: #ffffff;
                border: 1px solid #2d2d2f;
                padding: 6px;
                border-radius: 6px;
                font-size: 11px;
            }
            QScrollArea#rightScroll {
                background-color: #1c1c1c;
                border: none;
            }
            QScrollBar:vertical {
                background-color: #1c1c1c;
                width: 12px;
                border-radius: 6px;
            }
            QScrollBar::handle:vertical {
                background-color: #3c3c3c;
                border-radius: 6px;
                min-height: 30px;
            }
            QScrollBar::handle:vertical:hover {
                background-color: #4a4a4a;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
        """)
    
    def _apply_light_theme(self):
        """Apply modern light theme"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f5f5f5;
            }
            QWidget {
                background-color: #f5f5f5;
                color: #1d1d1f;
                font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
                font-size: 13px;
            }
            QFrame#topBar {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #ffffff, stop:1 #f5f5f7);
                border-bottom: 2px solid #e5e5e7;
            }
            QLabel#titleLabel {
                font-size: 20px;
                font-weight: 600;
                color: #1d1d1f;
                letter-spacing: -0.5px;
                background-color: transparent;
                border: none;
                padding: 0px;
            }
            QPushButton#themeToggle {
                background-color: #e5e5e7;
                color: #1d1d1f;
                border: 1px solid #d0d0d0;
                border-radius: 8px;
                font-size: 18px;
            }
            QPushButton#themeToggle:hover {
                background-color: #d5d5d7;
                border-color: #c0c0c0;
            }
            QPushButton#exitButton {
                background-color: #e5e5e7;
                color: #1d1d1f;
                border: 1px solid #d0d0d0;
                border-radius: 8px;
                font-size: 18px;
            }
            QPushButton#exitButton:hover {
                background-color: #d32f2f;
                border-color: #e53935;
                color: #ffffff;
            }
            QPushButton#exitButton:pressed {
                background-color: #b71c1c;
            }
            QWidget#contentArea {
                background-color: #f5f5f5;
            }
            QFrame#infoCard {
                background-color: #ffffff;
                border: 1px solid #e0e0e0;
                border-radius: 12px;
            }
            QLabel#sectionTitle {
                font-size: 16px;
                font-weight: 600;
                color: #1d1d1f;
                background-color: transparent;
                border: none;
                padding: 0px;
            }
            QFrame#logSection {
                background-color: #ffffff;
                border: 1px solid #e5e5e7;
                border-radius: 8px;
                padding: 12px;
            }
            QFrame#zoomToolbar {
                background-color: transparent;
                border: none;
            }
            QPushButton#zoomButton {
                background-color: #e5e5e7;
                color: #1d1d1f;
                border: 1px solid #d0d0d0;
                border-radius: 6px;
                font-size: 18px;
                font-weight: bold;
            }
            QPushButton#zoomButton:hover {
                background-color: #d5d5d7;
                border-color: #c0c0c0;
            }
            QPushButton#zoomButton:pressed {
                background-color: #c5c5c7;
            }
            QPushButton#zoomButton:disabled {
                background-color: #f5f5f7;
                color: #86868b;
                border-color: #e0e0e0;
            }
            QLabel#fontSizeLabel {
                background-color: transparent;
                color: #6c757d;
                font-size: 12px;
                font-weight: bold;
                min-width: 24px;
            }
            QTextEdit#logText {
                background-color: #ffffff;
                color: #1d1d1f;
                border: 1px solid #e5e5e7;
                border-radius: 8px;
                font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
                padding: 12px;
                selection-background-color: #007aff;
            }
            QFrame#buttonCard {
                background-color: #ffffff;
                border: 1px solid #e0e0e0;
                border-radius: 12px;
            }
            QPushButton#actionButton {
                background-color: #f5f5f7;
                color: #1d1d1f;
                border: 1px solid #e5e5e7;
                padding: 12px 16px;
                border-radius: 8px;
                font-size: 13px;
                font-weight: 500;
                text-align: left;
                min-width: 200px;
            }
            QPushButton#actionButton:hover {
                background-color: #ffffff;
                border-color: #d0d0d0;
                color: #000000;
            }
            QPushButton#actionButton:pressed {
                background-color: #e5e5e7;
                border-color: #c0c0c0;
            }
            /* Dialog Styles */
            QDialog {
                background-color: #ffffff;
                color: #1d1d1f;
                border-radius: 12px;
            }
            QDialog QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #1d1d1f;
            }
            QDialog QLabel#titleLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                font-size: 18px;
                font-weight: 600;
                color: #1d1d1f;
            }
            QDialog QLabel#descriptionLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #6c757d;
            }
            QMessageBox {
                background-color: #ffffff;
                color: #1d1d1f;
                border-radius: 12px;
            }
            QMessageBox QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #1d1d1f;
                font-size: 13px;
                line-height: 1.4;
            }
            QMessageBox QPushButton {
                background-color: #e0e0e0;
                color: #2d2d2d;
                border: 1px solid #c0c0c0;
                border-radius: 8px;
                min-width: 100px;
                padding: 10px 20px;
                font-size: 13px;
                font-weight: 500;
            }
            QMessageBox QPushButton:hover {
                background-color: #d0d0d0;
                border-color: #a0a0a0;
            }
            QMessageBox QPushButton:pressed {
                background-color: #c0c0c0;
            }
            QMessageBox QPushButton[default="true"] {
                background-color: #4caf50;
                color: #ffffff;
                border: 1px solid #4caf50;
                font-weight: bold;
            }
            QMessageBox QPushButton[default="true"]:hover {
                background-color: #45a049;
                border-color: #45a049;
            }
            QMessageBox QPushButton[default="true"]:pressed {
                background-color: #3d8b40;
            }
            QInputDialog {
                background-color: #ffffff;
                color: #1d1d1f;
                border-radius: 12px;
            }
            QInputDialog QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #1d1d1f;
            }
            QInputDialog QLineEdit {
                background-color: #ffffff;
                color: #1d1d1f;
                border: 1px solid #e0e0e0;
                border-radius: 6px;
                padding: 8px 12px;
                font-size: 13px;
                selection-background-color: #007aff;
            }
            QInputDialog QLineEdit:focus {
                border: 2px solid #007aff;
            }
            QInputDialog QDialog QPushButton {
                background-color: #e0e0e0;
                color: #2d2d2d;
                border: 1px solid #c0c0c0;
                border-radius: 8px;
                min-width: 100px;
                padding: 10px 20px;
                font-size: 13px;
                font-weight: 500;
            }
            QInputDialog QDialog QPushButton:hover {
                background-color: #d0d0d0;
                border-color: #a0a0a0;
            }
            QInputDialog QDialog QPushButton:pressed {
                background-color: #c0c0c0;
            }
            QFileDialog {
                background-color: #ffffff;
                color: #1d1d1f;
                border-radius: 12px;
            }
            QFileDialog QLabel {
                background-color: transparent;
                border: none;
                padding: 0px;
                color: #1d1d1f;
            }
            QFileDialog QLineEdit {
                background-color: #ffffff;
                color: #1d1d1f;
                border: 1px solid #e0e0e0;
                border-radius: 6px;
                padding: 8px 12px;
                font-size: 13px;
                selection-background-color: #007aff;
            }
            QFileDialog QLineEdit:focus {
                border: 2px solid #007aff;
            }
            QFileDialog QTreeView {
                background-color: #ffffff;
                color: #1d1d1f;
                alternate-background-color: #f5f5f7;
                border: 1px solid #e0e0e0;
                border-radius: 6px;
            }
            QFileDialog QTreeView::item {
                padding: 6px 8px;
            }
            QFileDialog QTreeView::item:selected {
                background-color: #007aff;
                color: #ffffff;
            }
            QFileDialog QListView {
                background-color: #ffffff;
                color: #1d1d1f;
                alternate-background-color: #f5f5f7;
                border: 1px solid #e0e0e0;
                border-radius: 6px;
            }
            QFileDialog QListView::item {
                padding: 6px 8px;
            }
            QFileDialog QListView::item:selected {
                background-color: #007aff;
                color: #ffffff;
            }
            QFileDialog QPushButton {
                background-color: #e0e0e0;
                color: #2d2d2d;
                border: 1px solid #c0c0c0;
                border-radius: 8px;
                min-width: 100px;
                padding: 10px 20px;
                font-size: 13px;
                font-weight: 500;
            }
            QFileDialog QPushButton:hover {
                background-color: #d0d0d0;
                border-color: #a0a0a0;
            }
            QFileDialog QPushButton:pressed {
                background-color: #c0c0c0;
            }
            QFileDialog QPushButton[default="true"] {
                background-color: #4caf50;
                color: #ffffff;
                border: 1px solid #4caf50;
                font-weight: bold;
            }
            QFileDialog QPushButton[default="true"]:hover {
                background-color: #45a049;
                border-color: #45a049;
            }
            QFileDialog QPushButton[default="true"]:pressed {
                background-color: #3d8b40;
            }
            QToolTip {
                background-color: #1d1d1f;
                color: #ffffff;
                border: 1px solid #2d2d2f;
                padding: 6px;
                border-radius: 6px;
                font-size: 11px;
            }
            QScrollArea#rightScroll {
                background-color: #f5f5f5;
                border: none;
            }
            QScrollBar:vertical {
                background-color: #f5f5f5;
                width: 12px;
                border-radius: 6px;
            }
            QScrollBar::handle:vertical {
                background-color: #c0c0c0;
                border-radius: 6px;
                min-height: 30px;
            }
            QScrollBar::handle:vertical:hover {
                background-color: #a0a0a0;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
        """)
    
    def _update_right_scroll_style(self):
        """Update right scroll area styling based on current theme"""
        if hasattr(self, 'right_scroll'):
            if self.dark_mode:
                self.right_scroll.setStyleSheet("""
                    QScrollArea {
                        background-color: #1c1c1c;
                        border: none;
                    }
                    QScrollBar:vertical {
                        background-color: #1c1c1c;
                        width: 12px;
                        border-radius: 6px;
                    }
                    QScrollBar::handle:vertical {
                        background-color: #3c3c3c;
                        border-radius: 6px;
                        min-height: 30px;
                    }
                    QScrollBar::handle:vertical:hover {
                        background-color: #4a4a4a;
                    }
                    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                        height: 0px;
                    }
                    QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                        background: none;
                    }
                """)
            else:
                self.right_scroll.setStyleSheet("""
                    QScrollArea {
                        background-color: #f5f5f5;
                        border: none;
                    }
                    QScrollBar:vertical {
                        background-color: #f5f5f5;
                        width: 12px;
                        border-radius: 6px;
                    }
                    QScrollBar::handle:vertical {
                        background-color: #c0c0c0;
                        border-radius: 6px;
                        min-height: 30px;
                    }
                    QScrollBar::handle:vertical:hover {
                        background-color: #a0a0a0;
                    }
                    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                        height: 0px;
                    }
                    QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                        background: none;
                    }
                """)
    
    def create_ui(self):
        """Create the modern user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QVBoxLayout(central_widget)
        main_layout.setSpacing(0)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        screen = self.screen().availableGeometry()
        screen_width = screen.width()
        
        if screen_width < 1024:
            top_bar_height = 56
            top_bar_margin = 12
            top_bar_spacing = 12
        else:
            top_bar_height = 64
            top_bar_margin = 24
            top_bar_spacing = 16
        
        self.top_bar = QFrame()
        self.top_bar.setFixedHeight(top_bar_height)
        self.top_bar.setObjectName("topBar")
        top_bar_layout = QHBoxLayout(self.top_bar)
        top_bar_layout.setContentsMargins(top_bar_margin, 12, top_bar_margin, 12)
        top_bar_layout.setSpacing(top_bar_spacing)
        
        self.title_label = QLabel("Mini Tools")
        self.title_label.setObjectName("titleLabel")
        top_bar_layout.addWidget(self.title_label)
        
        top_bar_layout.addStretch()
        
        self.theme_toggle_btn = QPushButton("☀")
        self.theme_toggle_btn.setObjectName("themeToggle")
        self.theme_toggle_btn.setToolTip("Switch Theme")
        self.theme_toggle_btn.setFixedSize(40, 40)
        self.theme_toggle_btn.clicked.connect(self.toggle_theme)
        
        # Exit button
        self.exit_btn = QPushButton("✕")
        self.exit_btn.setObjectName("exitButton")
        self.exit_btn.setToolTip("Exit")
        self.exit_btn.setFixedSize(40, 40)
        self.exit_btn.clicked.connect(self.confirm_exit)
        
        top_bar_layout.addWidget(self.theme_toggle_btn)
        top_bar_layout.addWidget(self.exit_btn)
        
        main_layout.addWidget(self.top_bar)
        
        content_widget = QWidget()
        content_widget.setObjectName("contentArea")
        content_layout = QHBoxLayout(content_widget)
        
        if screen_width < 1024:
            content_spacing = 12
            content_margin = 12
            right_panel_min = 280
            right_panel_max = 320
        elif screen_width < 1280:
            content_spacing = 16
            content_margin = 16
            right_panel_min = 320
            right_panel_max = 380
        else:
            content_spacing = 20
            content_margin = 20
            right_panel_min = 360
            right_panel_max = 420
        
        content_layout.setSpacing(content_spacing)
        content_layout.setContentsMargins(content_margin, content_margin, content_margin, content_margin)
        
        left_panel = self.create_info_section()
        content_layout.addWidget(left_panel, stretch=2)
        
        right_scroll = QScrollArea()
        right_scroll.setWidgetResizable(True)
        right_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        right_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        right_scroll.setFrameShape(QFrame.Shape.NoFrame)
        right_scroll.setObjectName("rightScroll")
        self.right_scroll = right_scroll
        self._update_right_scroll_style()
        
        right_panel = self.create_button_sections()
        right_scroll.setWidget(right_panel)
        right_scroll.setMinimumWidth(right_panel_min)
        right_scroll.setMaximumWidth(right_panel_max)
        
        content_layout.addWidget(right_scroll, stretch=1)
        
        main_layout.addWidget(content_widget, stretch=1)
    
    def create_info_section(self):
        """Create the information display section"""
        screen = self.screen().availableGeometry()
        screen_width = screen.width()
        
        if screen_width < 1024:
            card_spacing = 12
            card_margin = 12
        elif screen_width < 1280:
            card_spacing = 14
            card_margin = 16
        else:
            card_spacing = 16
            card_margin = 20
        
        card = QFrame()
        card.setObjectName("infoCard")
        card_layout = QVBoxLayout(card)
        card_layout.setSpacing(card_spacing)
        card_layout.setContentsMargins(card_margin, card_margin, card_margin, card_margin)
        
        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        title = QLabel("Output Log")
        title.setObjectName("sectionTitle")
        header.addWidget(title)
        header.addStretch()
        card_layout.addLayout(header)
        
        log_section = QFrame()
        log_section.setObjectName("logSection")
        log_layout = QVBoxLayout(log_section)
        log_layout.setSpacing(12)
        log_layout.setContentsMargins(0, 0, 0, 0)
        
        # Zoom toolbar
        zoom_toolbar = QFrame()
        zoom_toolbar.setObjectName("zoomToolbar")
        zoom_layout = QHBoxLayout(zoom_toolbar)
        zoom_layout.setContentsMargins(0, 0, 0, 0)
        zoom_layout.setSpacing(8)
        zoom_layout.addStretch()
        
        # Zoom out button
        self.zoom_out_btn = QPushButton("−")
        self.zoom_out_btn.setObjectName("zoomButton")
        self.zoom_out_btn.setToolTip("Decrease font size")
        self.zoom_out_btn.setFixedSize(32, 32)
        self.zoom_out_btn.clicked.connect(self.zoom_out_log)
        zoom_layout.addWidget(self.zoom_out_btn)
        
        # Font size label
        self.font_size_label = QLabel(str(self.log_font_size))
        self.font_size_label.setObjectName("fontSizeLabel")
        self.font_size_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        zoom_layout.addWidget(self.font_size_label)
        
        # Zoom in button
        self.zoom_in_btn = QPushButton("+")
        self.zoom_in_btn.setObjectName("zoomButton")
        self.zoom_in_btn.setToolTip("Increase font size")
        self.zoom_in_btn.setFixedSize(32, 32)
        self.zoom_in_btn.clicked.connect(self.zoom_in_log)
        zoom_layout.addWidget(self.zoom_in_btn)
        
        log_layout.addWidget(zoom_toolbar)
        
        self.log_text = QTextBrowser()
        self.log_text.setObjectName("logText")
        self.log_text.setReadOnly(True)
        self.log_text.setFont(QFont(Config.LOG_FONT_FAMILY, self.log_font_size))
        self.log_text.setOpenExternalLinks(True)  # 允许点击链接在外部浏览器打开
        screen = self.screen().availableGeometry()
        if screen.height() < 768:
            self.log_text.setMinimumHeight(150)
        else:
            self.log_text.setMinimumHeight(200)
        log_layout.addWidget(self.log_text)
        
        card_layout.addWidget(log_section)
        
        return card
    
    def create_button_sections(self):
        """Create button sections for system information"""
        screen = self.screen().availableGeometry()
        screen_width = screen.width()
        
        if screen_width < 1024:
            container_spacing = 12
        elif screen_width < 1280:
            container_spacing = 14
        else:
            container_spacing = 16
        
        container = QWidget()
        container_layout = QVBoxLayout(container)
        container_layout.setSpacing(container_spacing)
        container_layout.setContentsMargins(0, 0, 0, 0)
        
        # System Info Group
        system_group = self.create_button_group(
            "System Information",
            [
                ("System Overview", self._auto_run_fetch_tool, "Show system overview using fastfetch/neofetch"),
                ("CPU Info", self.show_cpu_info, "Show processor details and usage"),
                ("Memory Info", self.show_memory_info, "Show RAM usage and statistics"),
                ("Swap Info", self.show_swap_info, "Show swap space usage"),
                ("Kernel Info", self.show_kernel_info, "Show kernel version and system details"),
                ("Disk Info", self.show_disk_info, "Show disk usage and mounts"),
            ]
        )
        container_layout.addWidget(system_group)
        
        # Maintenance Group
        maintenance_buttons = [
            ("Check System Updates", self.show_update_info, "Check for available system package updates"),
            ("Install Package from File", self.install_package_from_file, "Install package from file"),
        ]
        
        # Add Flatpak-related buttons only on Linux
        if not PlatformHelper.is_windows():
            maintenance_buttons.extend([
                ("Check Flatpak Updates", self.show_flatpak_update_info, "Check for available Flatpak updates"),
                ("Remove Unused Flatpak Runtimes", self.remove_unused_flatpak, "Remove unused Flatpak runtimes to free space"),
            ])
        
        maintenance_group = self.create_button_group(
            "System Maintenance",
            maintenance_buttons
        )
        container_layout.addWidget(maintenance_group)
        
        # Disk Operations Group
        if not PlatformHelper.is_windows():
            disk_group = self.create_button_group(
                "Disk Operations",
                [
                    ("Change Partition UUID", self.change_partition_uuid, "Generate and change partition UUID"),
                ]
            )
            container_layout.addWidget(disk_group)
        
        # Extensions Group (dynamic)
        self.extensions_dir = Config.get_extensions_dir()
        self.extension_scripts = []
        
        if os.path.exists(self.extensions_dir):
            try:
                for item in sorted(os.listdir(self.extensions_dir)):
                    item_path = os.path.join(self.extensions_dir, item)
                    if os.path.isfile(item_path) and any(item.endswith(ext) for ext in Config.SUPPORTED_SCRIPT_EXTENSIONS):
                        script_name = item  # Keep the full filename including extension
                        self.extension_scripts.append((script_name, item_path))
            except Exception as e:
                self.log(f"Error scanning extensions directory: {str(e)}", LogLevel.WARNING)
        
        if self.extension_scripts:
            extension_buttons = []
            for script_name, script_path in self.extension_scripts:
                # Create a callback with the script path using a wrapper function to avoid closure issues
                def make_callback(p, n):
                    return lambda: self.execute_extension_script(p, n)
                callback = make_callback(script_path, script_name)
                extension_buttons.append((script_name, callback, f"Execute {script_name} extension"))
            
            # Add guide button at the end
            extension_buttons.append(("Add more extensions", self.show_extensions_info, "Show how to add extension scripts"))
            
            extensions_group = self.create_button_group(
                "Extensions",
                extension_buttons
            )
            container_layout.addWidget(extensions_group)
        else:
            # Show empty extensions group with instructions
            extensions_group = self.create_button_group(
                "Extensions",
                [
                    ("No extensions found", self.show_extensions_info, f"Add .sh or .py scripts to {self.extensions_dir}"),
                ]
            )
            container_layout.addWidget(extensions_group)
        
        # iFlow CLI Group
        iflow_group = self.create_button_group(
            "iFlow CLI",
            [
                ("Install iFlow CLI", self.install_iflow_cli, "Install iFlow CLI from official repository"),
                ("Clear iFlow History", self.clear_iflow_history, "Clear iFlow CLI command history"),
            ]
        )
        
        # Only show iFlow CLI group if not on Windows (or show with Windows instructions)
        if not PlatformHelper.is_windows():
            container_layout.addWidget(iflow_group)
        else:
            # On Windows, show iFlow CLI with installation instructions
            iflow_group_windows = self.create_button_group(
                "iFlow CLI",
                [
                    ("Install iFlow CLI", self.install_iflow_cli, "Show iFlow CLI installation instructions for Windows"),
                    ("Clear iFlow History", self.clear_iflow_history, "Show iFlow CLI history location on Windows"),
                ]
            )
            container_layout.addWidget(iflow_group_windows)
        
        # About Group
        about_group = self.create_button_group(
            "About",
            [
                ("About MiniTools", self.show_about, "Show program information"),
            ]
        )
        container_layout.addWidget(about_group)
        
        container_layout.addStretch()
        
        return container
    
    def create_button_group(self, title, buttons):
        """Create a button group with title and buttons"""
        screen = self.screen().availableGeometry()
        screen_width = screen.width()
        
        if screen_width < 1024:
            card_spacing = 12
            card_margin = 12
        elif screen_width < 1280:
            card_spacing = 14
            card_margin = 16
        else:
            card_spacing = 16
            card_margin = 20
        
        card = QFrame()
        card.setObjectName("buttonCard")
        card_layout = QVBoxLayout(card)
        card_layout.setSpacing(card_spacing)
        card_layout.setContentsMargins(card_margin, card_margin, card_margin, card_margin)
        
        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        title_label = QLabel(title)
        title_label.setObjectName("sectionTitle")
        header.addWidget(title_label)
        header.addStretch()
        card_layout.addLayout(header)
        
        for button_text, callback, tooltip in buttons:
            btn = QPushButton(button_text)
            btn.setObjectName("actionButton")
            btn.setToolTip(tooltip)
            btn.clicked.connect(callback)
            card_layout.addWidget(btn)
        
        return card
    
    def show_cpu_info(self):
        """Show CPU information"""
        self.log("Fetching CPU information...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("cpu")
        self.info_worker.data_ready.connect(self._display_info)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def show_memory_info(self):
        """Show memory information"""
        self.log("Fetching memory information...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("memory")
        self.info_worker.data_ready.connect(self._display_info)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def show_kernel_info(self):
        """Show kernel information"""
        self.log("Fetching kernel information...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("kernel")
        self.info_worker.data_ready.connect(self._display_info)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def show_swap_info(self):
        """Show swap information"""
        self.log("Fetching swap information...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("swap")
        self.info_worker.data_ready.connect(self._display_info)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def show_disk_info(self):
        """Show disk information"""
        self.log("Fetching disk information...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("disk")
        self.info_worker.data_ready.connect(self._display_info)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def show_update_info(self):
        """Show update information"""
        self.log("Checking for software updates...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("update")
        self.info_worker.data_ready.connect(self._display_info_with_update_option)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def show_flatpak_update_info(self):
        """Show Flatpak update information"""
        self.log("Checking for Flatpak updates...", LogLevel.INFO)
        self.info_worker = SystemInfoWorker("flatpak")
        self.info_worker.data_ready.connect(self._display_info_with_flatpak_update_option)
        self.info_worker.error_signal.connect(self._display_error)
        self.info_worker.start()
    
    def _display_info_with_update_option(self, title, content):
        """Display the information in the log with update option"""
        self._display_info(title, content)
        
        # 检查是否有可用更新
        if "Upgradable packages:" in content or "Available patches:" in content or "Updates available" in content:
            self.log("\n" + "="*80, LogLevel.INFO)
            self.log("发现可用更新!", LogLevel.WARNING)
            self.log("="*80 + "\n", LogLevel.INFO)
            
            # 显示确认对话框
            reply = QMessageBox.question(
                self,
                "Execute System Update",
                "System updates are available.\n\nDo you want to execute system update now?\n\nNote: This operation requires root privileges and may require password input.",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No
            )
            
            if reply == QMessageBox.StandardButton.Yes:
                self.log("Executing system update...", LogLevel.WARNING)
                self.execute_system_update()
            else:
                self.log("Update operation cancelled.\n", LogLevel.INFO)
        else:
            self.log("\nSystem is up to date, no updates available.\n", "success")
    
    def _display_info_with_flatpak_update_option(self, title, content):
        """Display Flatpak update information with update option"""
        self._display_info(title, content)
        
        # 检查是否有可用Flatpak更新
        if "Available Flatpak updates:" in content:
            self.log("\n" + "="*80, LogLevel.INFO)
            self.log("Flatpak updates are available!", LogLevel.WARNING)
            self.log("="*80 + "\n", LogLevel.INFO)
            
            # 显示确认对话框
            reply = QMessageBox.question(
                self,
                "Execute Flatpak Update",
                "Flatpak updates are available.\n\nDo you want to update Flatpak applications now?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No
            )
            
            if reply == QMessageBox.StandardButton.Yes:
                self.log("Executing Flatpak update...", LogLevel.WARNING)
                self.execute_flatpak_update()
            else:
                self.log("Flatpak update operation cancelled.\n", LogLevel.INFO)
        else:
            self.log("\nFlatpak applications are up to date.\n", LogLevel.SUCCESS)
    
    def execute_flatpak_update(self):
        """Execute Flatpak update"""
        command = ["flatpak", "update", "-y"]
        
        self.log(f"Executing command: {' '.join(command)}", LogLevel.WARNING)
        
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            self.log("Starting Flatpak update, please wait...\n", LogLevel.INFO)
            
            def read_output():
                while True:
                    output = process.stdout.readline()
                    if output == '' and process.poll() is not None:
                        break
                    if output:
                        self.log(output.strip(), LogLevel.INFO)
                        QApplication.processEvents()
            
            import threading
            output_thread = threading.Thread(target=read_output)
            output_thread.daemon = True
            output_thread.start()
            
            return_code = process.wait()
            output_thread.join(timeout=2)
            
            if return_code == 0:
                self.log("\n✓ Flatpak update completed!\n", LogLevel.SUCCESS)
            else:
                self.log(f"\n✗ Flatpak update failed, error code: {return_code}\n", "error")
                    
        except Exception as e:
            self.log(f"\n✗ Error during Flatpak update: {str(e)}\n", LogLevel.ERROR)
    
    def remove_unused_flatpak(self):
        """Remove unused Flatpak runtimes"""
        if PlatformHelper.is_windows():
            self.log("\n" + "="*80, LogLevel.INFO)
            self.log("Flatpak not supported on Windows", LogLevel.WARNING)
            self.log("="*80 + "\n", LogLevel.INFO)
            self.log("Flatpak is a Linux package format and is not available on Windows.\n", LogLevel.INFO)
            return
        
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log("Removing unused Flatpak runtimes", LogLevel.WARNING)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        # 显示确认对话框
        reply = QMessageBox.question(
            self,
            "Remove Unused Flatpak Runtimes",
            "This will remove unused Flatpak runtimes to free disk space.\n\nDo you want to continue?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply != QMessageBox.StandardButton.Yes:
            self.log("Operation cancelled.\n", LogLevel.INFO)
            return
        
        command = ["flatpak", "uninstall", "--unused", "-y"]
        
        self.log(f"Executing command: {' '.join(command)}", LogLevel.WARNING)
        
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            self.log("Removing unused runtimes, please wait...\n", LogLevel.INFO)
            
            def read_output():
                while True:
                    output = process.stdout.readline()
                    if output == '' and process.poll() is not None:
                        break
                    if output:
                        self.log(output.strip(), LogLevel.INFO)
                        QApplication.processEvents()
            
            import threading
            output_thread = threading.Thread(target=read_output)
            output_thread.daemon = True
            output_thread.start()
            
            return_code = process.wait()
            output_thread.join(timeout=2)
            
            if return_code == 0:
                self.log("\n✓ Unused Flatpak runtimes removed successfully!\n", LogLevel.SUCCESS)
            else:
                self.log(f"\n✗ Operation failed, error code: {return_code}\n", "error")
                    
        except Exception as e:
            self.log(f"\n✗ Error during operation: {str(e)}\n", LogLevel.ERROR)
    
    def install_package_from_file(self):
        """Install package from file (.deb, .rpm, .pkg.tar.xz, .exe, .msi)"""
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log("Install Package from File", LogLevel.WARNING)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        if PlatformHelper.is_windows():
            # Windows: support .exe and .msi
            file_path, _ = QFileDialog.getOpenFileName(
                self,
                "Select Package File",
                str(Path.home()),
                "Package Files (*.exe *.msi);;All Files (*)"
            )
            
            if not file_path:
                self.log("No file selected. Operation cancelled.\n", LogLevel.INFO)
                return
            
            self.log(f"Selected file: {file_path}\n", LogLevel.INFO)
            
            file_ext = Path(file_path).suffix.lower()
            
            if file_ext == '.exe':
                self.log(f"Running installer: {file_path}\n", LogLevel.WARNING)
                try:
                    import subprocess
                    subprocess.Popen([file_path], shell=True)
                    self.log("✓ Installer started successfully.\n", LogLevel.SUCCESS)
                except Exception as e:
                    self.log(f"✗ Failed to start installer: {str(e)}\n", LogLevel.ERROR)
            elif file_ext == '.msi':
                self.log(f"Running MSI installer: {file_path}\n", LogLevel.WARNING)
                try:
                    subprocess.Popen(['msiexec', '/i', file_path], shell=True)
                    self.log("✓ Installer started successfully.\n", LogLevel.SUCCESS)
                except Exception as e:
                    self.log(f"✗ Failed to start installer: {str(e)}\n", LogLevel.ERROR)
            else:
                self.log(f"✗ Unsupported package format: {file_ext}\n", LogLevel.ERROR)
                self.log("Supported formats on Windows: .exe, .msi\n", LogLevel.INFO)
            return
        
        # Linux/macOS: support .deb, .rpm, .pkg.tar.xz
        file_path, _ = QFileDialog.getOpenFileName(
            self,
            "Select Package File",
            str(Path.home()),
            "Package Files (*.deb *.rpm *.pkg.tar.xz *.pkg.tar.zst);;All Files (*)"
        )
        
        if not file_path:
            self.log("No file selected. Operation cancelled.\n", LogLevel.INFO)
            return
        
        self.log(f"Selected file: {file_path}\n", LogLevel.INFO)
        
        # 检测包类型并构建安装命令
        file_ext = Path(file_path).suffix.lower()
        distro = self._detect_distro()
        
        command = []
        
        if file_ext == '.deb':
            if distro in ["ubuntu", "debian", "mint", "pop", "zorin", "elementary"]:
                command = ["pkexec", "dpkg", "-i", file_path]
                command_fix = ["pkexec", "apt-get", "install", "-f"]
            else:
                self.log(f"Warning: .deb packages are for Debian-based systems only.\n", LogLevel.WARNING)
                reply = QMessageBox.question(
                    self,
                    "Continue Anyway?",
                    "This system is not Debian-based. Continue installation anyway?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.Yes:
                    command = ["pkexec", "dpkg", "-i", file_path]
                    command_fix = ["pkexec", "apt-get", "install", "-f"]
                else:
                    self.log("Operation cancelled.\n", LogLevel.INFO)
                    return
        
        elif file_ext == '.rpm':
            if distro in ["fedora", "nobara", "rhel", "centos", "almalinux", "rocky", "opensuse-leap", "opensuse-tumbleweed", "sle"]:
                command = ["pkexec", "rpm", "-i", file_path]
            else:
                self.log(f"Warning: .rpm packages are for RPM-based systems only.\n", LogLevel.WARNING)
                reply = QMessageBox.question(
                    self,
                    "Continue Anyway?",
                    "This system is not RPM-based. Continue installation anyway?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.Yes:
                    command = ["pkexec", "rpm", "-i", file_path]
                else:
                    self.log("Operation cancelled.\n", LogLevel.INFO)
                    return
        
        elif file_ext in ['.pkg.tar.xst', '.pkg.tar.xz']:
            if distro in ["arch", "cachyos", "manjaro", "endeavouros", "xerolinux", "garuda"]:
                command = ["pkexec", "pacman", "-U", "--noconfirm", file_path]
            else:
                self.log(f"Warning: Arch packages are for Arch-based systems only.\n", LogLevel.WARNING)
                reply = QMessageBox.question(
                    self,
                    "Continue Anyway?",
                    "This system is not Arch-based. Continue installation anyway?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.Yes:
                    command = ["pkexec", "pacman", "-U", "--noconfirm", file_path]
                else:
                    self.log("Operation cancelled.\n", LogLevel.INFO)
                    return
        
        else:
            self.log(f"Error: Unsupported package format: {file_ext}\n", LogLevel.ERROR)
            self.log("Supported formats: .deb, .rpm, .pkg.tar.xz, .pkg.tar.zst\n", LogLevel.INFO)
            return
        
        if not command:
            self.log("No installation command generated.\n", LogLevel.ERROR)
            return
        
        # 显示确认对话框
        reply = QMessageBox.question(
            self,
            "Install Package",
            f"Install package: {Path(file_path).name}?\n\nThis operation requires root privileges.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply != QMessageBox.StandardButton.Yes:
            self.log("Installation cancelled.\n", LogLevel.INFO)
            return
        
        # 执行安装
        self.log(f"Executing: {' '.join(command)}\n", LogLevel.WARNING)
        
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            self.log("Installing package, please wait...\n", LogLevel.INFO)
            
            def read_output():
                while True:
                    output = process.stdout.readline()
                    if output == '' and process.poll() is not None:
                        break
                    if output:
                        self.log(output.strip(), LogLevel.INFO)
                        QApplication.processEvents()
            
            import threading
            output_thread = threading.Thread(target=read_output)
            output_thread.daemon = True
            output_thread.start()
            
            return_code = process.wait()
            output_thread.join(timeout=2)
            
            if return_code == 0:
                self.log("\n✓ Package installed successfully!\n", LogLevel.SUCCESS)
                
                # 如果是deb包，尝试修复依赖
                if file_ext == '.deb' and 'command_fix' in locals():
                    self.log("Checking and fixing dependencies...\n", LogLevel.INFO)
                    process_fix = subprocess.Popen(
                        command_fix,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1,
                        universal_newlines=True
                    )
                    
                    def read_fix_output():
                        while True:
                            output = process_fix.stdout.readline()
                            if output == '' and process_fix.poll() is not None:
                                break
                            if output:
                                self.log(output.strip(), LogLevel.INFO)
                                QApplication.processEvents()
                    
                    fix_thread = threading.Thread(target=read_fix_output)
                    fix_thread.daemon = True
                    fix_thread.start()
                    
                    fix_return_code = process_fix.wait()
                    fix_thread.join(timeout=2)
                    
                    if fix_return_code == 0:
                        self.log("\n✓ Dependencies fixed successfully!\n", LogLevel.SUCCESS)
                    else:
                        self.log(f"\n⚠ Dependency check completed with warnings.\n", LogLevel.WARNING)
            else:
                self.log(f"\n✗ Installation failed, error code: {return_code}\n", "error")
                    
        except Exception as e:
            self.log(f"\n✗ Error during installation: {str(e)}\n", LogLevel.ERROR)
    
    def execute_system_update(self):
        """Execute system update based on distribution"""
        distro = self._detect_distro()
        command = []
        
        if PlatformHelper.is_windows():
            self.log("Windows Updates must be run through Windows Update Settings.\n", LogLevel.INFO)
            self.log("Press Win + I to open Settings, then go to Windows Update.\n", LogLevel.INFO)
            return
        elif PlatformHelper.is_macos():
            self.log("macOS updates must be run through System Settings > Software Update.\n", LogLevel.INFO)
            return
        elif distro in ["ubuntu", "debian", "mint", "pop", "zorin", "elementary"]:
            command = ["pkexec", "sh", "-c", "apt update && apt upgrade -y"]
        elif distro in ["fedora", "nobara", "rhel", "centos", "almalinux", "rocky"]:
            command = ["pkexec", "sh", "-c", "dnf upgrade -y"]
        elif distro in ["arch", "cachyos", "manjaro", "endeavouros", "xerolinux", "garuda"]:
            command = ["pkexec", "sh", "-c", "pacman -Syu --noconfirm"]
        elif distro in ["opensuse-leap", "opensuse-tumbleweed", "sle"]:
            command = ["pkexec", "sh", "-c", "zypper dup -y"]
        else:
            self.log("不支持的发行版，请手动更新。", LogLevel.ERROR)
            return
        
        # 启动更新进程
        self.log(f"正在执行命令: {' '.join(command)}", LogLevel.WARNING)
        self.log("注意: 更新过程会在新的终端窗口中进行\n", LogLevel.INFO)
        
        try:
            # 使用QProcess来处理pkexec，并等待完成
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            # 实时读取输出
            self.log("开始更新，请稍候...\n", LogLevel.INFO)
            
            # 创建一个线程来读取输出
            def read_output():
                while True:
                    output = process.stdout.readline()
                    if output == '' and process.poll() is not None:
                        break
                    if output:
                        self.log(output.strip(), LogLevel.INFO)
                        # 强制UI更新
                        QApplication.processEvents()
            
            import threading
            output_thread = threading.Thread(target=read_output)
            output_thread.daemon = True
            output_thread.start()
            
            # 等待进程完成
            return_code = process.wait()
            output_thread.join(timeout=2)
            
            if return_code == 0:
                self.log("\n✓ 系统更新完成!\n", LogLevel.SUCCESS)
            else:
                self.log(f"\n✗ 更新失败，错误码: {return_code}\n", LogLevel.ERROR)
                    
        except Exception as e:
            self.log(f"\n✗ 更新过程中出现错误: {str(e)}\n", LogLevel.ERROR)
    
    def _detect_distro(self):
        """Detect the Linux distribution"""
        try:
            with open("/etc/os-release", "r") as f:
                content = f.read()
            for line in content.split("\n"):
                if line.startswith("ID="):
                    distro = line.split("=", 1)[1].strip().strip('"').lower()
                    if distro == "pika":
                        distro = "pikaos"
                    return distro
        except (IOError, FileNotFoundError):
            pass
        return "unknown"
    
    def _display_info(self, title, content):
        """Display the information in the log"""
        self.log(f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", LogLevel.INFO)
        self.log(f"{title}", LogLevel.SUCCESS)
        self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", LogLevel.INFO)
        
        # 将内容按行分割，为不同类型的信息添加颜色
        lines = content.split('\n')
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # 根据内容类型设置颜色
            if line.startswith("Error:") or line.startswith("✗"):
                self.log(line, LogLevel.ERROR)
            elif line.startswith("Warning:") or line.startswith("⚠"):
                self.log(line, LogLevel.WARNING)
            elif line.startswith("✓") or "Installed" in line or "Available" in line:
                self.log(line, LogLevel.SUCCESS)
            else:
                self.log(line, LogLevel.INFO)
        
        self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", LogLevel.INFO)
        
        # 自动滚动到底部
        self.log_text.verticalScrollBar().setValue(self.log_text.verticalScrollBar().maximum())
    
    def _display_error(self, error_message):
        """Display error message"""
        self.log(f"\n{error_message}\n", LogLevel.ERROR)
    
    def install_iflow_cli(self):
        """Install iFlow CLI from official repository"""
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log("Install iFlow CLI", LogLevel.WARNING)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        # 显示确认对话框
        if PlatformHelper.is_windows():
            install_command = "irm https://gitee.com/iflow-ai/iflow-cli/raw/main/install.ps1 | iex"
            message = "This will download and install iFlow CLI using PowerShell.\n\nCommand:\n" + install_command + "\n\nDo you want to continue?"
        else:
            install_script_url = "https://gitee.com/iflow-ai/iflow-cli/raw/main/install.sh"
            message = "This will download and install iFlow CLI from:\n" + install_script_url + "\n\nDo you want to continue?"
        
        reply = QMessageBox.question(
            self,
            "Install iFlow CLI",
            message,
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply != QMessageBox.StandardButton.Yes:
            self.log("Installation cancelled.\n", LogLevel.INFO)
            return
        
        if PlatformHelper.is_windows():
            # Windows: 使用 npm 安装
            self.log("Installing iFlow CLI using npm...\n", LogLevel.WARNING)
            
            try:
                # 先检查 Node.js 是否已安装
                self.log("Checking for Node.js...", LogLevel.INFO)
                check_process = subprocess.run(
                    ["node", "--version"],
                    capture_output=True,
                    text=True
                )
                
                if check_process.returncode != 0:
                    self.log("✗ Node.js not found!\n", LogLevel.ERROR)
                    self.log("iFlow CLI requires Node.js on Windows.\n", LogLevel.INFO)
                    self.log("Please install Node.js first:\n", LogLevel.INFO)
                    self.log("1. Visit: https://nodejs.org/zh-cn/download\n", LogLevel.INFO)
                    self.log("2. Download and install Node.js\n", LogLevel.INFO)
                    self.log("3. Restart this application and try again\n", LogLevel.INFO)
                    return
                
                self.log(f"✓ Node.js {check_process.stdout.strip()} found\n", LogLevel.SUCCESS)
                
                # 使用 npm 安装 iFlow CLI
                self.log("Installing iFlow CLI via npm...\n", LogLevel.INFO)
                
                process = subprocess.Popen(
                    ["npm", "install", "-g", "@iflow-ai/iflow-cli@latest"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )
                
                def read_output():
                    while True:
                        output = process.stdout.readline()
                        if output == '' and process.poll() is not None:
                            break
                        if output:
                            self.log(output.strip(), LogLevel.INFO)
                            QApplication.processEvents()
                
                import threading
                output_thread = threading.Thread(target=read_output)
                output_thread.daemon = True
                output_thread.start()
                
                return_code = process.wait()
                output_thread.join(timeout=30)
                
                if return_code == 0:
                    self.log("\n✓ iFlow CLI installed successfully!\n", LogLevel.SUCCESS)
                    self.log("You can now use 'iflow' command in PowerShell.\n", LogLevel.INFO)
                    
                    # 验证安装
                    verify_process = subprocess.run(
                        ["iflow", "--version"],
                        capture_output=True,
                        text=True
                    )
                    if verify_process.returncode == 0:
                        self.log(f"✓ Verified: iFlow CLI {verify_process.stdout.strip()}\n", LogLevel.SUCCESS)
                else:
                    self.log(f"\n✗ Installation failed, error code: {return_code}\n", LogLevel.ERROR)
                    
            except FileNotFoundError:
                self.log("✗ npm command not found!\n", LogLevel.ERROR)
                self.log("Please install Node.js from: https://nodejs.org/zh-cn/download\n", LogLevel.INFO)
            except Exception as e:
                self.log(f"\n✗ Error during installation: {str(e)}\n", LogLevel.ERROR)
        else:
            # Linux/macOS: 使用 bash 脚本安装
            self.log("Downloading iFlow CLI installer...", LogLevel.INFO)
            
            install_script_url = "https://gitee.com/iflow-ai/iflow-cli/raw/main/install.sh"
            temp_dir = tempfile.mkdtemp()
            install_script_path = os.path.join(temp_dir, "install.sh")
            
            try:
                # Download install script
                import urllib.request
                urllib.request.urlretrieve(install_script_url, install_script_path)
                self.log("Download completed successfully.\n", LogLevel.SUCCESS)
                
                # Make script executable
                os.chmod(install_script_path, 0o755)
                
                # Run install script
                self.log("Running iFlow CLI installer...\n", LogLevel.WARNING)
                
                process = subprocess.Popen(
                    ["bash", install_script_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )
                
                def read_output():
                    while True:
                        output = process.stdout.readline()
                        if output == '' and process.poll() is not None:
                            break
                        if output:
                            self.log(output.strip(), LogLevel.INFO)
                            QApplication.processEvents()
                
                import threading
                output_thread = threading.Thread(target=read_output)
                output_thread.daemon = True
                output_thread.start()
                
                return_code = process.wait()
                output_thread.join(timeout=2)
                
                # Cleanup
                import shutil
                shutil.rmtree(temp_dir)
                
                if return_code == 0:
                    self.log("\n✓ iFlow CLI installed successfully!\n", LogLevel.SUCCESS)
                    self.log("You can now use 'iflow' command in your terminal.\n", LogLevel.INFO)
                else:
                    self.log(f"\n✗ Installation failed, error code: {return_code}\n", LogLevel.ERROR)
                    
            except Exception as e:
                self.log(f"\n✗ Error during installation: {str(e)}\n", LogLevel.ERROR)
                # Cleanup on error
                import shutil
                if os.path.exists(temp_dir):
                    shutil.rmtree(temp_dir)
    
    def clear_iflow_history(self):
        """Clear iFlow CLI command history"""
        self.log("\n" + "="*80, LogLevel.INFO)
        self.log("Clear iFlow CLI Command History", LogLevel.WARNING)
        self.log("="*80 + "\n", LogLevel.INFO)
        
        if PlatformHelper.is_windows():
            # Windows
            appdata = os.environ.get('APPDATA')
            if not appdata:
                home = os.path.expanduser('~')
                appdata = os.path.join(home, 'AppData', 'Roaming')
            iflow_dir = os.path.join(appdata, 'iflow')
            history_dir = os.path.join(iflow_dir, 'history')
        else:
            # Linux and macOS use the same path
            iflow_dir = os.path.expanduser("~/.iflow")
            history_dir = os.path.join(iflow_dir, 'history')
        
        if not os.path.exists(history_dir):
            self.log(f"History directory not found: {history_dir}\n", LogLevel.INFO)
            self.log("iFlow CLI history does not exist or has already been cleared.\n", LogLevel.SUCCESS)
            return
        
        # 显示确认对话框
        reply = QMessageBox.question(
            self,
            "Clear iFlow CLI History",
            f"This will clear the iFlow CLI command history directory:\n{history_dir}\n\nAll history files will be deleted.\nDo you want to continue?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        
        if reply != QMessageBox.StandardButton.Yes:
            self.log("Operation cancelled.\n", LogLevel.INFO)
            return
        
        try:
            # Delete all files and subdirectories in the history directory
            import shutil
            deleted_count = 0
            for item in os.listdir(history_dir):
                item_path = os.path.join(history_dir, item)
                if os.path.isfile(item_path):
                    os.remove(item_path)
                    deleted_count += 1
                elif os.path.isdir(item_path):
                    shutil.rmtree(item_path)
                    deleted_count += 1
            
            self.log(f"✓ History directory cleared: {history_dir}\n", LogLevel.SUCCESS)
            self.log(f"Deleted {deleted_count} item(s) from iFlow CLI history.\n", LogLevel.INFO)
            self.log("iFlow CLI command history has been cleared.\n", LogLevel.INFO)
            
        except PermissionError:
            self.log(f"✗ Permission denied: Cannot access {history_dir}\n", LogLevel.ERROR)
            self.log("Try running the application as administrator.\n", LogLevel.INFO)
        except Exception as e:
            self.log(f"✗ Error clearing history directory: {str(e)}\n", LogLevel.ERROR)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Mini Tools")
    app.setOrganizationName("Mini Tools")
    
    # Set application icon for Windows taskbar
    # For development mode, load icon from file
    # For compiled EXE, icon is embedded by PyInstaller
    if not getattr(sys, 'frozen', False):
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            icon_path = os.path.join(script_dir, "minitools.ico")
            if os.path.exists(icon_path):
                app.setWindowIcon(QIcon(icon_path))
        except Exception:
            pass
    
    window = MiniToolsGUI()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
