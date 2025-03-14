from .autolabel import RegiStreamAccessor  # registers accessor automatically
from .lookup import lookup  # import the lookup function

# Export these symbols when importing the package  (i.e. from registream import *)
__all__ = ['lookup']

