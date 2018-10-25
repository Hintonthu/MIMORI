#!/usr/bin/env python
# Copyright 2016-2018 Yu Sheng Lin

# This file is part of MIMORI.

# MIMORI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MIMORI is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MIMORI.  If not, see <http://www.gnu.org/licenses/>.

from importlib import import_module
from os import environ

sample_conf = list()
verf_func = list()

def ImportFunction(mod_name):
	# somewhat ugly...
	m = import_module("."+mod_name, package=__name__)
	sample_conf.append(m.cfg)
	verf_func.append(m.VerfFunc)

samples = [
	"simple_conv",
	"integral_image",
	"gemm_medium",
	"motion_est",
	"meshgrid",
	"gradient",
	"downsample",
]
for s in samples:
	ImportFunction(s)

try:
	WHAT = int(environ["TEST_CFG"])
except:
	WHAT = 0
default_sample_conf = sample_conf[WHAT]
default_verf_func = verf_func[WHAT]

__all__ = [
	"sample_conf",
	"verf_func",
	"default_sample_conf",
	"default_verf_func",
]
