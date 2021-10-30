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

This module is the variable precision floating point multiplier module.
To use this module, please find the general modules folder and add the following modules to the project:
1. denormalize
2. parametrized adder, parametrized or gate, parametrized mux, parameterized_multiplier.
3. round to normal wrapper
4. delay block
5. float_pkg.vhd
6. Users should generate an IP core named mul_man_multiplier.xco and add it to the project. 
	You can vary the latency of the mul_man_multiplier.  
	- Update latency parameter (MUL_MANTISSA_DELAY) in float_pkg.vhdl file.
	- Latency for the floating point multiplier equals to latency of mantissa multiplier + 2.

	the multiplier is (man_bits+1)*(man_bits+1) = 2*man_bits+2
	for example, single precision man_bits(23) is 24*24=48;
		   double precision man_bits(52) is 53*53=106;

	Note that you have to change the corresponding initialization code of the multiplier IP core in parameterizd_multiplier if using the MegaCore in Altera IDE.