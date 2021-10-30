--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable & GPU Computing Laboratory           --
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
--  DATE		 | 25 Oct. 2012			                --
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

--======================================================--
--                      LIBRARIES                       --
--======================================================--

-- IEEE Libraries --
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

-- float
library fp_lib;
use fp_lib.float_pkg.all;

--======================================================--
--                      ENTITIES                        --
--======================================================--

----------------------------------------------------------
--              Floating Point Multiplier               --
----------------------------------------------------------
entity fp_mul is
	generic
	(
		exp_bits			:	integer := 8;
		man_bits			:	integer := 24
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
		RESULT			:	out	std_logic_vector(exp_bits+(2*man_bits) downto 0);
		EXCEPTION_OUT	:	out	std_logic;
		DONE				:	out	std_logic
	);
end entity;

architecture fp_mul_arch of fp_mul is

	-- Constants
	constant bias		: std_logic_vector := CONV_STD_LOGIC_VECTOR((2**(exp_bits-1))-2,exp_bits+1);
	constant	zero		: std_logic_vector := CONV_STD_LOGIC_VECTOR(0,1+exp_bits+(2*man_bits));

	-- Signals
	signal s1						: std_logic;
	signal e1						: std_logic_vector(exp_bits-1 downto 0);
	signal f1						: std_logic_vector(man_bits-1 downto 0);
	signal s2						: std_logic;
	signal e2						: std_logic_vector(exp_bits-1 downto 0);
	signal f2						: std_logic_vector(man_bits-1 downto 0);
	
	signal rdy						: std_logic;
	signal rdy_delayed			: std_logic;
	signal rdy_s					: std_logic;
	
	signal sign						: std_logic;
	signal sign_delayed			: std_logic;
	
	signal exp_unbiased			: std_logic_vector(exp_bits downto 0);
	signal exp_delayed			: std_logic_vector(exp_bits downto 0);
	signal exp_biased				: std_logic_vector(exp_bits downto 0);

	signal man						: std_logic_vector((2*man_bits)-1 downto 0);
	
	signal exc						: std_logic;
	signal exc_delayed			: std_logic;
	signal exc_biased				: std_logic;
	signal exception				: std_logic;
	signal exc_s					: std_logic;
	
	signal op1_or					: std_logic;
	signal op2_or					: std_logic;
	signal all_zero				: std_logic;
	signal all_zero_s				: std_logic;
	signal all_zero_delayed		: std_logic;

	signal clear					: std_logic;
	
	signal res						:	std_logic_vector(exp_bits+(2*man_bits) downto 0)	:=	(others=>'0');
	signal res_s					:	std_logic_vector(exp_bits+(2*man_bits) downto 0)	:=	(others=>'0');
	signal res_e					:	std_logic_vector(exp_bits+(2*man_bits) downto 0)	:=	(others=>'0');
	
	signal temp_result			: std_logic_vector(exp_bits+(2*man_bits) downto 0);
	signal temp_exception		: std_logic;
	signal temp_done				: std_logic;
	
begin

	--------------------------------------------------------------------------------------------
	--														  READY	 													--
	--------------------------------------------------------------------------------------------
	rdy <= READY;
	
	READY_FIXED_MULT_DELAY: delay_block generic map (MUL_MANTISSA_DELAY) port map (CLK,RESET,STALL,rdy,rdy_delayed);

	--------------------------------------------------------------------------------------------
	--														 SIGN 														--
	--------------------------------------------------------------------------------------------
	sign <= s1 XOR s2;

	SIGN_FIXED_MULT_DELAY: delay_block generic map (MUL_MANTISSA_DELAY) port map (CLK,RESET,STALL,sign,sign_delayed);

	--------------------------------------------------------------------------------------------
	--														EXPONENT 													--
	--------------------------------------------------------------------------------------------
	exponent_adder: parameterized_adder generic map (exp_bits) port map (e1,e2,'0',exp_unbiased(exp_bits-1 downto 0),exp_unbiased(exp_bits));

	EXPONENT_FIXED_MULT_DELAY: bus_delay_block generic map (exp_bits+1,MUL_MANTISSA_DELAY) port map (CLK,RESET,STALL,exp_unbiased,exp_delayed);
	
	bias_subtractor: parameterized_subtractor generic map (exp_bits+1) port map (exp_delayed,bias,exp_biased);
	--------------------------------------------------------------------------------------------
	--														MANTISSA 													--
	--------------------------------------------------------------------------------------------

	mantissa_multiplier: parameterized_multiplier
	generic map
	(
		bits		=>	man_bits
	)
	port map
	(
		CLK		=> CLK,
		RESET 	=> RESET,
		STALL		=> STALL,
		A			=>	f1,
		B			=>	f2,
		S			=>	man
	);

	--------------------------------------------------------------------------------------------
	--														EXCETPTION													--
	--------------------------------------------------------------------------------------------
	all_zero_or_gate_op1: parameterized_or_gate generic map (exp_bits+man_bits) port map (OP1(exp_bits+man_bits-1 downto 0),op1_or);
	all_zero_or_gate_op2: parameterized_or_gate generic map (exp_bits+man_bits) port map (OP2(exp_bits+man_bits-1 downto 0),op2_or);

	all_zero		<=	(NOT(op1_or)) OR (NOT(op2_or));
	ALL_ZERO_FIXED_MULT_DELAY : delay_block generic map (MUL_MANTISSA_DELAY) port map (CLK,RESET,STALL,all_zero,all_zero_delayed);
	
	exc <= EXCEPTION_IN;	
	EXCEPTION_FIXED_MULT_DELAY: delay_block generic map (MUL_MANTISSA_DELAY) port map (CLK,RESET,STALL,exc,exc_delayed);

	exc_biased	<=	exp_biased(exp_bits) and rdy_delayed AND (NOT(all_zero_delayed));
	exception	<=	exc_delayed or exc_biased;

	--clear			<=	all_zero_s OR exc_s OR (NOT(rdy_s));
	clear <= '0';

	--------------------------------------------------------------------------------------------
	--												Asynchronous Assignments										--
	--------------------------------------------------------------------------------------------	
	s1				<=	OP1(exp_bits+man_bits);
	e1				<=	OP1(exp_bits+man_bits-1 downto man_bits);
	f1				<=	OP1(man_bits-1 downto 0);
	s2				<=	OP2(exp_bits+man_bits);
	e2				<=	OP2(exp_bits+man_bits-1 downto man_bits);
	f2				<=	OP2(man_bits-1 downto 0);
   
	res			<= sign_delayed & exp_biased(exp_bits-1 downto 0) & man;
	
	OUTPUT_MUX: parameterized_mux generic map (1+exp_bits+(2*man_bits)) port map (zero,res_s,clear,res_e);

	--------------------------------------------------------------------------------------------
	--               							Synchronous Assignments                					--
	--------------------------------------------------------------------------------------------
	synchro: process (CLK,RESET,STALL) is
	begin
		if(RESET = '1') then
			all_zero_s		<= '0';
			
			rdy_s				<= '0';
			res_s				<= (others=>'0');
			exc_s				<= '0';

			temp_done		<=	'0';
			temp_result		<=	(others=>'0');		
			temp_exception	<=	'0';
		elsif(rising_edge(CLK) and STALL = '0') then
			all_zero_s		<= all_zero_delayed;
			
			rdy_s				<= rdy_delayed;
			res_s				<= res;
			exc_s				<= exception;
			
			temp_done		<=	rdy_s;
			temp_result		<=	res_e;
			temp_exception	<=	exc_s;
		end if;--CLK
	end process;--synchro

	DONE				<= temp_done;
	RESULT 			<= temp_result;
	EXCEPTION_OUT 	<= temp_exception and temp_done;
	
end fp_mul_arch; --end of architecture

