--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory         --
--                                                      --
--  AUTHOR       | Pavle Belanovic                      --
--  -------------+------------------------------------  --
--  DATE         | 20 June 2002                         --
--  -------------+------------------------------------  --
--  REVISED BY   | Haiqian Yu                           --
--  -------------+------------------------------------  --
--  DATE         | 18 Jan. 2003                         --
--  -------------+------------------------------------  --
--  REVISED BY   | Jainik Kathiara                      --
--  -------------+------------------------------------  --
--  DATE         | 21 Sept. 2010                        --
--  --------------------------------------------------  --
--  REVISED BY   | Xin Fang                             --
--  --------------------------------------------------  --
--  DATE		 | 25 Oct. 2012							--
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

entity variable_precision_multiplier is
	Port
	(
		CLK							: in	STD_LOGIC;
		RESET							: in	STD_LOGIC;
		STALL							: in	STD_LOGIC;
		OP1							: in	STD_LOGIC_VECTOR(31 downto 0);
		OP2							: in	STD_LOGIC_VECTOR(31 downto 0);
		READY							: in	STD_LOGIC;
		ROUND							: in	STD_LOGIC;
		EXCEPTION_IN				: in	STD_LOGIC;
		DONE							: out	STD_LOGIC;
		RESULT						: out STD_LOGIC_VECTOR(31 downto 0);
		EXCEPTION_OUT				: out STD_LOGIC
	);
end variable_precision_multiplier;

architecture Behavioral of variable_precision_multiplier is
	--CONSTANTS
	constant exp_bits				: integer := 8;
	constant man_bits				: integer := 23;
	constant denorm_man_bits	: integer := man_bits + 1;
	constant mul_man_bits		: integer := 2*denorm_man_bits;
	constant round_man_bits		: integer := 23;
	
	--SIGNALS
	signal ready_1					: std_logic;
	signal denorm_operand_1		: std_logic_vector(exp_bits+denorm_man_bits downto 0);
	signal denorm_exception_1	: std_logic;
	
	signal ready_2					: std_logic;
	signal denorm_operand_2		: std_logic_vector(exp_bits+denorm_man_bits downto 0);
	signal denorm_exception_2	: std_logic;
	
	signal mul_ready				: std_logic;
	signal mul_exception_in		: std_logic;
	
	signal mul_done				: std_logic;
	signal mul_result				: std_logic_vector(exp_bits+mul_man_bits downto 0);
	signal mul_exception			: std_logic;
	
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
		IN1							=> OP1,
		READY 						=> READY,
		EXCEPTION_IN				=> EXCEPTION_IN,
		DONE							=> ready_1,
		OUT1							=> denorm_operand_1,
		EXCEPTION_OUT				=> denorm_exception_1
	);

	DENORM_2:denorm
	generic map
	(
		exp_bits 					=> exp_bits,
		man_bits 					=> man_bits	
	)
	port map
	(
		IN1							=> OP2,
		READY 						=> READY,
		EXCEPTION_IN				=> EXCEPTION_IN,
		DONE							=> ready_2,
		OUT1							=> denorm_operand_2,
		EXCEPTION_OUT				=> denorm_exception_2
	);
	
	MUL_FUNC:fp_mul
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
		OP1							=> denorm_operand_1,
		OP2							=> denorm_operand_2,
		READY							=> mul_ready,
		EXCEPTION_IN				=> mul_exception_in,
		DONE							=> mul_done,
		RESULT						=> mul_result,
		EXCEPTION_OUT 				=> mul_exception
	);

	RND_NORM:rnd_norm_wrapper
	generic map
	(
		exp_bits						=> exp_bits,
		man_bits_in					=> mul_man_bits,
		man_bits_out				=> round_man_bits
	)
	port map
	(
		CLK							=> CLK,
		RESET							=> RESET,
		STALL							=> STALL,
		ROUND							=> rnd_delayed,
		READY							=> mul_done,
		OP								=> mul_result,
		EXCEPTION_IN				=> mul_exception,
		DONE							=> DONE,
		RESULT						=> RESULT,
		EXCEPTION_OUT  			=> EXCEPTION_OUT
	);
	
	mul_ready 					<= ready_1 and ready_2;
	mul_exception_in			<= denorm_exception_1 or denorm_exception_2;
	ROUND_DELAY: delay_block generic map (MUL_PIPELINE) port map (CLK,RESET,STALL,ROUND,rnd_delayed);

end Behavioral;
