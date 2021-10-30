--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory         --
--                                                      --
--  AUTHOR       | Xiaojun Wang	                        --
--  -------------+------------------------------------  --
--  DATE         | 27 February 2008                     --
--  -------------+------------------------------------  --
--  REVISED BY   | Jainik Kathiara                      --
--  -------------+------------------------------------  --
--  DATE         | 21 Sept. 2010                        --
--  -------------+------------------------------------  --
--  REVISED BY   | Xin Fang                    		    --
--  -------------+------------------------------------  --
--  DATE         | 29 Sep. 2013                         --
--  -------------+------------------------------------  --
--  REVISED BY   | Xin Fang		                        --
--  -------------+------------------------------------  --
--  DATE         | May 2015                             --
--======================================================--

--******************************************************************************--
--
--	Copyright (C) 2015		                                                    --
--                                                                              --
--	This program is free software; you can redistribute it and/or               --
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
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

library fp_lib;
use fp_lib.float_pkg.all;

entity variable_precision_divider is
	port
	(
		CLK				: in std_logic;
		RESET				: in std_logic;
		STALL				: in std_logic;
		OP1				: in std_logic_vector(63 downto 0);
		OP2				: in std_logic_vector(63 downto 0);
		READY				: in std_logic;
		ROUND				: in std_logic;
		EXCEPTION_IN	: in std_logic;
		DONE				: out std_logic;
		RESULT			: out std_logic_vector(63 downto 0);
		EXCEPTION_OUT	: out std_logic
	);
end variable_precision_divider;

architecture behavioral of variable_precision_divider is
	--constants
	constant exp_bits				: integer := 11;
	constant man_bits				: integer := 52;
	constant man_bits_1bit		: integer := man_bits + 1;
	constant denorm_man_bits	: integer := man_bits + 2; 
	constant round_input_bits	: integer := 2*denorm_man_bits; 
	constant mul_man_bits		: integer := 2*denorm_man_bits; 
	constant round_man_bits		: integer := man_bits;
	
	signal ready_1					: std_logic;
	signal denorm_operand_1		: std_logic_vector(exp_bits+denorm_man_bits downto 0); 
	signal denorm_exception_1	: std_logic;
	
	signal ready_2					: std_logic;
	signal denorm_operand_2		: std_logic_vector(exp_bits+denorm_man_bits downto 0);  
	signal denorm_exception_2	: std_logic;
	
	signal divider_ready				: std_logic;
	signal divider_exception_in		: std_logic;
	
	signal divider_done				: std_logic;
	signal divider_result				: std_logic_vector(exp_bits+mul_man_bits downto 0);  
	signal divider_exception			: std_logic;
	
	signal rnd_delayed			: std_logic;
	
	signal OP1_1						: std_logic_vector(exp_bits + man_bits_1bit downto 0);
	signal OP2_1						: std_logic_vector(exp_bits + man_bits_1bit downto 0);
	
	
	component fp_div is
	generic
	(
		exp_bits			:	integer := 11;  
		man_bits			:	integer := 53	 
	);
	port
	(
		--inputs
		CLK				:	in		std_logic;
		RESET				:	in		std_logic;
		STALL				:	in		std_logic;
		OP1				:	in		std_logic_vector(exp_bits+man_bits downto 0);  
		OP2				:	in		std_logic_vector(exp_bits+man_bits downto 0);  
		READY				:	in		std_logic;
		EXCEPTION_IN	:	in		std_logic;
		--outputs
		RESULT			:	out	std_logic_vector(exp_bits+2*man_bits downto 0);  
		EXCEPTION_OUT	:	out	std_logic;
		DONE				:	out	std_logic
	);
end component;
	
begin

	OP1_1			<= OP1 & '0';
	OP2_1			<= OP2 & '0';

	DENORM_1:denorm
	generic map
	(
		exp_bits 					=> exp_bits,
		man_bits 					=> man_bits_1bit	
	)
	port map
	(
		IN1							=> OP1_1,
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
		man_bits 					=> man_bits_1bit	
	)
	port map
	(
		IN1							=> OP2_1,
		READY 						=> READY,
		EXCEPTION_IN				=> EXCEPTION_IN,
		DONE							=> ready_2,
		OUT1							=> denorm_operand_2,
		EXCEPTION_OUT				=> denorm_exception_2
	);
	
   Divider:fp_div
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
		READY							=> divider_ready,
		EXCEPTION_IN				=> divider_exception_in,
		DONE							=> divider_done,
		RESULT						=> divider_result,		
		EXCEPTION_OUT 				=> divider_exception
	);
	
	RND_NORM:rnd_norm_wrapper
	generic map
	(
		exp_bits						=> exp_bits,	  
		man_bits_in					=> round_input_bits, 
		man_bits_out				=> round_man_bits 
	)
	port map
	(
		CLK							=> CLK,
		RESET							=> RESET,
		STALL							=> STALL,
		ROUND							=> rnd_delayed,
		READY							=> divider_done,
		OP								=> divider_result, 
		EXCEPTION_IN				=> divider_exception,
		DONE							=> DONE,
		RESULT						=> RESULT,
		EXCEPTION_OUT  			=> EXCEPTION_OUT
	);
	
	divider_ready 					<= ready_1 and ready_2;
	divider_exception_in			<= denorm_exception_1 or denorm_exception_2;
	ROUND_DELAY: delay_block generic map (DIV_PIPELINE) port map (CLK,RESET,STALL,ROUND,rnd_delayed);
end Behavioral;