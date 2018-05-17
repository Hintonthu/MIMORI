# default numpy and i32 version numpy
from functools import partial
from numpy import newaxis
import numpy as npd
i16 = npd.int16
class npi(object): pass

wrapped = [
	'ones', 'zeros', 'empty', 'full', 'array',
	'cumsum', 'cumprod', 'sum', 'prod', 'arange', 'indices',
]
for f in wrapped:
	setattr(npi, f, partial(getattr(npd, f), dtype=npd.int32))

from .UmiModel import *
from .ramulator import *
