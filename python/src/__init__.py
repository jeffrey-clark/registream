"""
RegiStream: Streamline your registry data workflow
"""

# Import and expose the main components
from .autolabel import autolabel
from .lookup import lookup

# Export these symbols when importing the package
__all__ = ['lookup', 'autolabel']

# Version information
__version__ = "1.0.0"

