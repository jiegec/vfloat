--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory         --
--                                                      --
--  AUTHOR       | Xiaojun Wang                         --
--  -------------+------------------------------------  --
--  DATE         | 27 February 2008                     --
--  -------------+------------------------------------  --
--  REVISED BY   | Jainik Kathiara                      --
--  -------------+------------------------------------  --
--  DATE         | 21 Sept. 2010                        --
--  --------------------------------------------------  --
--  REVISED BY   | Xin Fang                             --
--  --------------------------------------------------  --
--  DATE		 | 29 Sep. 2013						    --
--======================================================--

--******************************************************************************--
--                                                                              --
--	Copyright (C) 2015		                                                    --
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library fp_lib;
use fp_lib.float_pkg.all;

entity variable_precision_squareroot is
	Port
	(
		CLK							: in	STD_LOGIC;
		RESET							: in	STD_LOGIC;
		STALL							: in	STD_LOGIC;
		OP								: in	STD_LOGIC_VECTOR(63 downto 0);
		READY							: in	STD_LOGIC;
		ROUND							: in	STD_LOGIC;
		EXCEPTION_IN				: in	STD_LOGIC;
		DONE							: out	STD_LOGIC;
		RESULT						: out STD_LOGIC_VECTOR(63 downto 0);
		EXCEPTION_OUT				: out STD_LOGIC
	);
end variable_precision_squareroot;

architecture Behavioral of variable_precision_squareroot is
	--CONSTANTS
	constant exp_bits				: integer := 11;
	constant man_bits				: integer := 52;
	constant denorm_man_bits	: integer := man_bits + 1;
	constant sqrt_man_bits		: integer := ((((denorm_man_bits + 2)/4)+1)*4)+1;
	constant round_man_bits		: integer := 52;
	
	--SIGNALS
	signal sqrt_ready				: std_logic;
	signal sqrt_operand			: std_logic_vector(exp_bits+denorm_man_bits downto 0);	
	signal sqrt_exception_in	: std_logic;
	
	signal sqrt_done				: std_logic;
	signal sqrt_result			: std_logic_vector(exp_bits+sqrt_man_bits downto 0);
	signal sqrt_exception		: std_logic;
	
	signal rnd_delayed			: std_logic;
begin
	
	DENORM_1:denorm
	generic map
	(
		exp_bits 					=> exp_bits,
		man_bits 					=> man_bits	
	)
	port map
	(
		IN1							=> OP,
		READY 						=> READY,
		EXCEPTION_IN				=> EXCEPTION_IN,
		DONE							=> sqrt_ready,
		OUT1							=> sqrt_operand,
		EXCEPTION_OUT				=> sqrt_exception_in
	);
	
	SQRT_FUNC:fp_sqrt
	generic map
	(
		exp_bits						=> exp_bits,
		man_bits						=> denorm_man_bits
	)
	port map
	(
		CLK							=> CLK,
		RESET							=> RESET,
		STALL							=> STALL,
		OP								=> sqrt_operand,
		READY							=> sqrt_ready,
		EXCEPTION_IN				=> sqrt_exception_in,
		DONE							=> sqrt_done,
		RESULT						=> sqrt_result,
		EXCEPTION_OUT 				=> sqrt_exception
	);

	RND_NORM:rnd_norm_wrapper
	generic map
	(
		exp_bits						=> exp_bits,
		man_bits_in					=> sqrt_man_bits,
		man_bits_out				=> round_man_bits
	)
	port map
	(
		CLK							=> CLK,
		RESET							=> RESET,
		STALL							=> STALL,
		ROUND							=> rnd_delayed,
		READY							=> sqrt_done,
		OP								=> sqrt_result,
		EXCEPTION_IN				=> sqrt_exception,
		DONE							=> DONE,
		RESULT						=> RESULT,
		EXCEPTION_OUT  			=> EXCEPTION_OUT
	);
	
	ROUND_DELAY: delay_block generic map (SQRT_PIPELINE) port map (CLK,RESET,STALL,ROUND,rnd_delayed);

end Behavioral;
