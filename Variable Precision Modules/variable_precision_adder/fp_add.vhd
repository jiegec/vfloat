--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory           --
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
--  DATE		 | 25 Oct. 2012					        --
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
--use IEEE.std_logic_signed.all;


-- float
library fp_lib;
use fp_lib.float_pkg.all;

----------------------------------------------------------
--               Floating Point Adder                   --
----------------------------------------------------------
entity fp_add is
	generic
	(
		exp_bits			:	integer	:=	8;
		man_bits			:	integer	:=	24
	);
	port
	(
		--inputs
		CLK				:	in		std_logic;
		RESET				:	in		std_logic;
		STALL				:	in		std_logic;
		READY				:	in		std_logic;
		EXCEPTION_IN	:	in		std_logic;
		OP1				:	in		std_logic_vector(man_bits+exp_bits downto 0);
		OP2				:	in		std_logic_vector(man_bits+exp_bits downto 0);
		--outputs
		RESULT			:	out	std_logic_vector(man_bits+exp_bits+2 downto 0);
		EXCEPTION_OUT	:	out	std_logic := '0';
		DONE				:	out	std_logic := '0'
	);
end fp_add;

----------------------------------------------------------
--               Floating Point Adder                   --
----------------------------------------------------------
architecture fp_add_arch of fp_add is
	signal rdy1					: std_logic;
	signal rdy2					: std_logic;
	signal rdy3					: std_logic;

	signal exc					: std_logic;
	signal exc1					: std_logic;
	signal exc2					: std_logic;
	signal exc3					: std_logic;
	
	signal eq					: std_logic;
	signal eq1					: std_logic;
	signal eq2					: std_logic;
	signal eq3					: std_logic;
	
	signal s1					: std_logic;
	signal e1					: std_logic_vector(exp_bits-1 downto 0);
	signal f1					: std_logic_vector(man_bits+1 downto 0);
	signal s2					: std_logic;
	signal e2					: std_logic_vector(exp_bits-1 downto 0);
	signal f2					: std_logic_vector(man_bits+1 downto 0);

	signal exp_diff			: std_logic_vector(exp_bits-1 downto 0);
	
	signal s1_2					: std_logic;
	signal s2_2					: std_logic;
	signal e_2					: std_logic_vector(exp_bits-1 downto 0);
	signal f1_2					: std_logic_vector(man_bits+1 downto 0);
	signal f2_2					: std_logic_vector(man_bits+1 downto 0);
	
	signal op					: std_logic;

	signal fill					: std_logic;
	signal enable				: std_logic;
	
	signal s_out				: std_logic;
	signal e_out				: std_logic_vector(exp_bits-1 downto 0);
	signal f_out				: std_logic_vector(man_bits+1 downto 0);

	signal large				: std_logic_vector(man_bits+exp_bits+2 downto 0);
	signal small				: std_logic_vector(man_bits+exp_bits+2 downto 0);

	signal n_op2				: std_logic_vector(man_bits+exp_bits downto 0);
	
	signal temp_result		: std_logic_vector(man_bits+exp_bits+2 downto 0);
	signal temp_exception	: std_logic;
	signal temp_done			: std_logic;
	
begin
	--instances of all the components
	exc <= EXCEPTION_IN;
	equal: eq <= '1' when (OP1 = n_op2) else '0';
		
	swap_operand: swap
	generic map
	(
		exp_bits					=>	exp_bits,
		man_bits					=>	man_bits
	)
	port map
	(
		--inputs
		CLK						=>	CLK,
		RESET						=> RESET,
		STALL						=> STALL,
		READY						=>	READY,
		IN1						=>	OP1,
		IN2						=>	OP2,
		--outputs
		EXP_DIFF					=> exp_diff,
		OUT1						=>	large,
		OUT2						=>	small,
		DONE						=>	rdy1
	);
	 
	s_a: shift_adjust
	generic map
	(
		exp_bits					=> exp_bits,
		man_bits					=> man_bits
	)
	port map
	(
		--inputs
		CLK						=>	CLK,
		RESET						=> RESET,
		STALL						=> STALL,
		READY						=>	rdy1,
		FILL						=> fill,
		EXP_DIFF					=> exp_diff,
		F_IN						=> f2,
		--outputs
		F_OUT						=> f2_2,
		DONE						=> rdy2
	);

	a_s: add_sub
	generic map
	(
		man_bits					=>	man_bits
	)
	port map
	(
		--inputs
		CLK						=>	CLK,
		RESET						=> RESET,
		STALL						=> STALL,
		READY						=>	rdy2,
		F1							=>	f1_2,
		F2							=>	f2_2,
		OP							=>	op,
		--outputs
		F_OUT						=>	f_out,
		OVERFLOW					=>	enable,
		DONE						=>	rdy3
	);

	corr: correction 
	generic map
	(
		exp_bits					=>	exp_bits,
		man_bits					=>	man_bits
	)
	port map
	(
		--inputs
		CLK						=>	CLK,
		RESET						=> RESET,
		STALL						=> STALL,
		READY						=>	rdy3,
		ENABLE					=>	enable,
		EXCEPTION_IN			=>	exc3,
		F							=>	f_out,
		E							=>	e_out,
		S							=>	s_out,
		CLEAR						=>	eq3,
		--outputs
		RESULT					=>	temp_result,
		EXCEPTION_OUT			=>	temp_exception,
		DONE						=>	temp_done
	);
	
	--permanent connections (signal renaming)
	s1	<=	large(man_bits+exp_bits+2);
	e1	<=	large(man_bits+exp_bits+1 downto man_bits+2);
	f1	<=	large(man_bits+1 downto 0);
	s2	<=	small(man_bits+exp_bits+2);
	e2	<=	small(man_bits+exp_bits+1 downto man_bits+2);
	f2	<=	small(man_bits+1 downto 0);
	
	fill <= s1 XOR s2;
	op	<=	s1_2 XNOR s2_2;
	
	n_op2(exp_bits+man_bits-1 downto 0)	<=	OP2(exp_bits+man_bits-1 downto 0);
	n_op2(exp_bits+man_bits) <= NOT(OP2(exp_bits+man_bits)); --invert sign
	
	main: process (CLK,RESET,STALL) is
	begin
		if (RESET = '1') then
			exc1			<= '0';
			eq1			<= '0';
			
			exc2			<= '0';
			eq2			<= '0';
			s1_2			<= '0';
			s2_2			<= '0';
			e_2			<= (others=>'0');
			f1_2			<= (others=>'0');
			
			exc3			<= '0';
			eq3			<= '0';
			s_out			<= '0';
			e_out			<= (others=>'0');	
		elsif(rising_edge(CLK) and STALL = '0') then
			exc1			<= exc;
			eq1			<= eq;
			
			exc2			<= exc1;
			eq2			<= eq1;
			s1_2			<= s1;
			s2_2			<= s2;
			e_2			<= e1;
			f1_2			<= f1;

			exc3			<= exc2;
			eq3			<= eq2;
			s_out			<= s1_2;
			e_out			<= e_2;
		end if;--CLK
	end process MAIN;--main
	
	DONE				<= temp_done;
	RESULT 			<= temp_result;
	EXCEPTION_OUT 	<= temp_exception and temp_done;
	
end fp_add_arch; --end of architecture

