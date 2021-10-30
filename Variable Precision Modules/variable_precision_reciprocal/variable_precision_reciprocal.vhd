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

entity variable_precision_reciprocal is
	generic 
	(
		exp_bits						: integer := 9;
		man_bits						: integer := 30
	);
	Port
	(
		CLK							: in	STD_LOGIC;
		RESET							: in	STD_LOGIC;
		STALL							: in	STD_LOGIC;
		OP							: in	STD_LOGIC_VECTOR(exp_bits+man_bits downto 0);
		READY							: in	STD_LOGIC;
		ROUND							: in	STD_LOGIC;
		EXCEPTION_IN				: in	STD_LOGIC;
		DONE							: out	STD_LOGIC;
		RESULT						: out STD_LOGIC_VECTOR(exp_bits+man_bits downto 0);
		EXCEPTION_OUT				: out STD_LOGIC
	);
end variable_precision_reciprocal;

architecture Behavioral of variable_precision_reciprocal is
	--CONSTANTS
	constant denorm_man_bits	: integer := man_bits + 1; 
	constant recip_man_bits		: integer := ((((denorm_man_bits + 2)/4)+1)*4)+1; 
	constant round_man_bits		: integer := man_bits;
	
	--SIGNALS
	signal recip_ready				: std_logic;
	signal recip_operand			: std_logic_vector(exp_bits+denorm_man_bits downto 0);
	signal recip_exception_in	: std_logic;
	
	signal recip_done				: std_logic;
	signal recip_result			: std_logic_vector(exp_bits+recip_man_bits downto 0);
	signal recip_exception		: std_logic;
	
	signal rnd_delayed			: std_logic;
	component fp_recip
	generic
	(
		exp_bits					: integer := 0;
		man_bits					: integer := 0
	);
	port
	(
		CLK					: in std_logic;
		RESET					: in std_logic;
		STALL					: in std_logic;
		OP						: in std_logic_vector(exp_bits+denorm_man_bits downto 0);
		READY					: in std_logic;
		EXCEPTION_IN		: in std_logic;
		DONE					: out std_logic;
		EXCEPTION_OUT		: out std_logic;
		RESULT				: out std_logic_vector(exp_bits+recip_man_bits downto 0)
	);
	end component;
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
		DONE							=> recip_ready,
		OUT1							=> recip_operand,
		EXCEPTION_OUT				=> recip_exception_in
	);
	
	RECIP_FUNC:fp_recip 
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
		OP								=> recip_operand,  
		READY							=> recip_ready,
		EXCEPTION_IN				=> recip_exception_in,
		DONE							=> recip_done,
		RESULT						=> recip_result,  
		EXCEPTION_OUT 				=> recip_exception
	);

	RND_NORM:rnd_norm_wrapper  
	generic map
	(
		exp_bits						=> exp_bits,
		man_bits_in					=> recip_man_bits,
		man_bits_out				=> round_man_bits
	)
	port map
	(
		CLK							=> CLK,
		RESET							=> RESET,
		STALL							=> STALL,
		ROUND							=> rnd_delayed,
		READY							=> recip_done,
		OP								=> recip_result,
		EXCEPTION_IN				=> recip_exception,
		DONE							=> DONE,
		RESULT						=> RESULT,
		EXCEPTION_OUT  			=> EXCEPTION_OUT
	);
	
	ROUND_DELAY: delay_block generic map (RECIP_PIPELINE) port map (CLK,RESET,STALL,ROUND,rnd_delayed);

end Behavioral;