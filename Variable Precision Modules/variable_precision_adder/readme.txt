--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory			--
--	Created by 	 | Xin Fang								--
--  --------------------------------------------------  --
--  DATE		 | Aug. 2014						    --
--														--
--======================================================--
--******************************************************************************--
--                                                                              --
--	Copyright (C) 2014		                                                    --
--                                                                              --
--	This program is free software; you can redistribute it and/or				--
--	modify it under the terms of the GNU General Public License                 --
--	as published by the Free Software Foundation; either version 3              --
--	of the License, or (at your option) any later version.                      --
--                                                                              --
--	This program is distributed in the hope that it will be useful,             --
--	but WITHOUT ANY WARRANTY; without even the implied warranty of              --
--	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               --
--	GNU General Public License for more details.                                --
--                                                                              --
--	You should have received a copy of the GNU General Public License           --
--	along with this program.  If not, see<http://www.gnu.org/licenses/>.        --
--                                                                           	--
--******************************************************************************--

This module is the variable precision floating point adder module.
To use this module, please find the general modules folder and add the following modules to the project:
1. denormalize
2. swap, shift_adjust, add_sub, correction
3. round to normal wrapper
4. delay block
5. float_pkg.vhd

-The defaulted parameters for exponent and mantissa bit widths are set for single precision floating point arithmetic, users can modify them accordingly for variable precision floating point version. 
-For subtraction you need to explicitly invert sign.
-Latency of the add unit is fixed at 4 cycles.