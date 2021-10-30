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

This module is the variable precision floating point reciprocal module.
To use this module, please find the general modules folder and add the following modules to the project:
1. denormalize
2. parametrized subtractor, parametrized adder, parametrized or gate, parametrized and gate.
3. round to normal wrapper
4. delay block
5. float_pkg.vhd
6. IP core:
	Determine x for your reciprocal operator. x = floor((man_bits+3)/4) + 1.
	  For example, for IEEE single-precision floating-point format, man_bits is 23, so x is 7;
				   for IEEE double-precision floating-point format, man_bits is 52, so x is 14.
	- You need to create one look up tables for the design unit.
		recip_r_table - input width will be x and output width will be x+2. Memory initialization file is located in file r_table/R_Table_x.
	- After creating the look up table create four multipliers:
		1. recip_multiplier_yr - width of input will be x+3,4*x+2 and output will be 5*x+5.
		2. recip_multiplier_s - width of both input will be x and output will be 2*x.
		3. recip_multiplier_m - width of input will be 2*x,x and output will be 3*x.
		4. recip_multiplier_l - width of input will be x+2, 4*x+2 and output will be 5*x+4.
	- Update the above multiplier latency parameters (RECIP_MULTIPLIER_YR_DELAY, RECIP_MULTIPLIER_S_DELAY, RECIP_MULTIPLIER_M_DELAY, RECIP_MULTIPLIER_L_DELAY) in float_pkg.vhdl file.
	- Latency of the reciprocal will be RECIP_MULTIPLIER_YR_DELAY+ 2*RECIP_MULTIPLIER_S_DELAY + RECIP_MULTIPLIER_M_DELAY + RECIP_MULTIPLIER_L_DELAY + 2.
	
Note that you have to change the corresponding initialization code of the multiplier IP core in parameterizd_multiplier if using the MegaCore in Altera IDE.
