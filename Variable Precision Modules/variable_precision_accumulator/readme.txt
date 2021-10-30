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

This module is the variable precision floating point accumulator module.
To use this module, please find the general modules folder and add the following modules to the project:
1. swap, shift_adjust, add_sub, correction
2. round to normal wrapper
3. float_pkg.vhd

Note that the input should be denormalize, meaning the integer '1' of the fractional part should be the explicit expression.