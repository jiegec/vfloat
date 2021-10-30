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

----------------------------------------------------------
--               Floating Point Divider                 --
----------------------------------------------------------
entity fp_sqrt is
	generic
	(
		exp_bits					: integer;
		man_bits					: integer
	);
	port
	(
		--inputs
		CLK						: in	std_logic;
		RESET						: in	std_logic;
		STALL						: in	std_logic;
		OP							: in	std_logic_vector(exp_bits+man_bits downto 0);
		READY						: in	std_logic;
		EXCEPTION_IN			: in	std_logic;
		--outputs
		DONE						: out	std_logic;
		RESULT					: out	std_logic_vector(exp_bits+((((man_bits+2)/4)+1)*4)+1 downto 0);
		EXCEPTION_OUT			: out	std_logic
	);
end fp_sqrt;


architecture fp_sqrt_arch of fp_sqrt is

	constant sq_bits			: integer := (man_bits+2)/4+1;
	constant f_bits			: integer := sq_bits * 4;
	constant bias		 		: std_logic_vector := CONV_STD_LOGIC_VECTOR((2**(exp_bits-1))-1,exp_bits);

	signal s						: std_logic;
	signal e						: std_logic_vector(exp_bits-1 downto 0);
	signal f						: std_logic_vector(man_bits-2 downto 0);

	signal e_unbiased			: std_logic_vector(exp_bits-1 downto 0);
	signal e_odd 				: std_logic;
	signal exp_unbiased		: std_logic_vector(exp_bits-1 downto 0);

	signal man_in 				: std_logic_vector(f_bits-1 downto 0);
	signal man_out 			: std_logic_vector(f_bits-1 downto 0);
	
	signal e_zero 				: std_logic;
	signal e_max 				: std_logic;

	signal corner 				: std_logic;
	
	signal rdy					: std_logic;
	signal rdy_s				: std_logic;
	signal s_s					: std_logic;
	signal exp					: std_logic_vector(exp_bits-1 downto 0);
	signal exp_s				: std_logic_vector(exp_bits-1 downto 0);
	signal exc					: std_logic;
	signal exc_s				: std_logic;
	
	signal rdy_0				: std_logic;
	signal s_0					: std_logic;
	signal exp_0				: std_logic_vector(exp_bits-1 downto 0);
	signal exc_0				: std_logic;
	
	signal rdy_1				: std_logic;
	signal s_1					: std_logic;
	signal exp_1				: std_logic_vector(exp_bits-1 downto 0);
	signal exc_1				: std_logic;
	
	signal rdy_2				: std_logic;
	signal s_2					: std_logic;
	signal exp_2				: std_logic_vector(exp_bits-1 downto 0);
	signal exc_2				: std_logic;
	
	signal rdy_3				: std_logic;
	signal s_3					: std_logic;
	signal exp_3				: std_logic_vector(exp_bits-1 downto 0);
	signal exc_3				: std_logic;

	signal rdy_4				: std_logic;
	signal s_4					: std_logic;
	signal exp_4				: std_logic_vector(exp_bits-1 downto 0);
	signal exc_4				: std_logic;
	
	signal value				: std_logic_vector(exp_bits+((((man_bits+2)/4)+1)*4)+1 downto 0);
	
	signal temp_result		: std_logic_vector(exp_bits+((((man_bits+2)/4)+1)*4)+1 downto 0);
	signal temp_exception	: std_logic;
	signal temp_done			: std_logic;
	
begin
	--------------------------------------------------------------------------------------------
	--														  READY	 													--
	--------------------------------------------------------------------------------------------
	rdy <= READY;

	READY_MULTIPLIER_YR_DELAY: delay_block generic map (SQRT_MULTIPLIER_YR_DELAY) port map (CLK,RESET,STALL,rdy_s,rdy_0);
	
	IF_SQ_BITS_GT_1_A2_A2_READY_DELAY: if (sq_bits>1) generate
		READY_MULTIPLIER_A2_A2_DELAY: delay_block generic map (SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,rdy_0,rdy_1);
	end generate;
	ELSE_A2_A2_READY_DELAY: if (sq_bits=1) generate
		rdy_1 <= rdy_0;
	end generate;
	
	IF_SQ_BITS_GT_2_A2_A3_READY_DELAY: if (sq_bits>=3) generate
		READY_MULTIPLIER_A2_A3_DELAY: delay_block generic map (SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,rdy_1,rdy_2);
	end generate;
	ELSE_A2_A3_READY_DELAY: if (sq_bits<3) generate
		rdy_2 <= rdy_1;
	end generate;
	
	IF_SQ_BITS_GT_4_A2_A2_A2_READY_DELAY: if (sq_bits>=5) generate
		READY_MULTIPLIER_A2_A2_A2_DELAY: delay_block generic map (SQRT_MULTIPLIER_M_DELAY) port map (CLK,RESET,STALL,rdy_2,rdy_3);
	end generate;
	ELSE_A2_A2_A2_READY_DELAY: if (sq_bits<5) generate
		rdy_3 <= rdy_2;
	end generate;
	
	READY_MULTIPLIER_L_DELAY: delay_block generic map (SQRT_MULTIPLIER_L_DELAY) port map (CLK,RESET,STALL,rdy_3,rdy_4);

	--------------------------------------------------------------------------------------------
	--														 	SIGN 														--
	--------------------------------------------------------------------------------------------
	
	SIGN_MULTIPLIER_YR_DELAY: delay_block generic map (SQRT_MULTIPLIER_YR_DELAY) port map (CLK,RESET,STALL,s_s,s_0);
	
	IF_SQ_BITS_GT_1_A2_A2_SIGN_DELAY: if (sq_bits>1) generate
		SIGN_MULTIPLIER_A2_A2_DELAY: delay_block generic map (SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,s_0,s_1);
	end generate;
	ELSE_A2_A2_SIGN_DELAY: if (sq_bits=1) generate
		s_1 <= s_0;
	end generate;
	
	IF_SQ_BITS_GT_2_A2_A3_SIGN_DELAY: if (sq_bits>=3) generate
		SIGN_MULTIPLIER_A2_A3_DELAY: delay_block generic map (SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,s_1,s_2);
	end generate;
	ELSE_A2_A3_SIGN_DELAY: if (sq_bits<3) generate
		s_2 <= s_1;
	end generate;
	
	IF_SQ_BITS_GT_4_A2_A2_A2_SIGN_DELAY: if (sq_bits>=5) generate
		SIGN_MULTIPLIER_A2_A2_A2_DELAY: delay_block generic map (SQRT_MULTIPLIER_M_DELAY) port map (CLK,RESET,STALL,s_2,s_3);
	end generate;
	ELSE_A2_A2_A2_SIGN_DELAY: if (sq_bits<5) generate
		s_3 <= s_2;
	end generate;
	
	SIGN_MULTIPLIER_L_DELAY: delay_block generic map (SQRT_MULTIPLIER_L_DELAY) port map (CLK,RESET,STALL,s_3,s_4);

	--------------------------------------------------------------------------------------------
	--														 EXPONENT 													--
	--------------------------------------------------------------------------------------------
	-- add bias to the exponent different after adjust
	EXPONENT_UNBIASED: parameterized_subtractor generic map (exp_bits) port map (e,bias,e_unbiased);

	e_odd 			<= e_unbiased(0);
	exp_unbiased 	<= e_unbiased(exp_bits-1) & e_unbiased(exp_bits-1 downto 1);

	EXPONENT_BIASED: parameterized_adder generic map (exp_bits) port map (exp_unbiased,bias,'0',exp,open);

	EXPONENT_MULTIPLIER_YR_DELAY: bus_delay_block generic map (exp_bits,SQRT_MULTIPLIER_YR_DELAY) port map (CLK,RESET,STALL,exp_s,exp_0);
	
	IF_SQ_BITS_GT_1_A2_A2_EXPONENT_DELAY: if (sq_bits>1) generate
		EXPONENT_MULTIPLIER_A2_A2_DELAY: bus_delay_block generic map (exp_bits,SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,exp_0,exp_1);
	end generate;
	ELSE_A2_A2_EXPONENT_DELAY: if (sq_bits=1) generate
		exp_1 <= exp_0;
	end generate;
	
	IF_SQ_BITS_GT_2_A2_A3_EXPONENT_DELAY: if (sq_bits>=3) generate
		EXPONENT_MULTIPLIER_A2_A3_DELAY: bus_delay_block generic map (exp_bits,SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,exp_1,exp_2);
	end generate;
	ELSE_A2_A3_EXPONENT_DELAY: if (sq_bits<3) generate
		exp_2 <= exp_1;
	end generate;
	
	IF_SQ_BITS_GT_4_A2_A2_A2_EXPONENT_DELAY: if (sq_bits>=5) generate
		EXPONENT_MULTIPLIER_A2_A2_A2_DELAY: bus_delay_block generic map (exp_bits,SQRT_MULTIPLIER_M_DELAY) port map (CLK,RESET,STALL,exp_2,exp_3);
	end generate;
	ELSE_A2_A2_A2_EXPONENT_DELAY: if (sq_bits<5) generate
		exp_3 <= exp_2;
	end generate;
	
	EXPONENT_MULTIPLIER_L_DELAY: bus_delay_block generic map (exp_bits,SQRT_MULTIPLIER_L_DELAY) port map (CLK,RESET,STALL,exp_3,exp_4);

	--------------------------------------------------------------------------------------------
	--														 MANTISSA 													--
	--------------------------------------------------------------------------------------------
	man_in(f_bits-1 downto f_bits-(man_bits-1))	<= f(man_bits-2 downto 0);
	man_in(f_bits-man_bits downto 0)					<= (others=>'0');

	man_comp : sq 
	generic map
	(
		bits						=>	sq_bits
	)
	port map
	(
		CLK						=>	CLK,
		RESET						=> RESET,
		STALL						=> STALL,
		odd_in					=>	e_odd,
		Y_in						=>	man_in,
		res						=>	man_out 
	);	
	
	--------------------------------------------------------------------------------------------
	--														EXCETPTION													--
	--------------------------------------------------------------------------------------------
	all_zero_exp: parameterized_or_gate generic map (exp_bits) port map (e,e_zero);
		
	all_one_exp: parameterized_and_gate generic map (exp_bits) port map (e,e_max);		

	corner	 <= NOT(e_zero) or e_max;
	
	exc		 <= (corner or s or EXCEPTION_IN) and READY;
	
	EXCEPTION_MULTIPLIER_YR_DELAY: delay_block generic map (SQRT_MULTIPLIER_YR_DELAY) port map (CLK,RESET,STALL,exc_s,exc_0);
	
	IF_SQ_BITS_GT_1_A2_A2_EXCEPTION_DELAY: if (sq_bits>1) generate
		EXCEPTION_MULTIPLIER_A2_A2_DELAY: delay_block generic map (SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,exc_0,exc_1);
	end generate;
	ELSE_A2_A2_EXCEPTION_DELAY: if (sq_bits=1) generate
		exc_1 <= exc_0;
	end generate;
	
	IF_SQ_BITS_GT_2_A2_A3_EXCEPTION_DELAY: if (sq_bits>=3) generate
		EXCEPTION_MULTIPLIER_A2_A3_DELAY: delay_block generic map (SQRT_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,exc_1,exc_2);
	end generate;
	ELSE_A2_A3_EXCEPTION_DELAY: if (sq_bits<3) generate
		exc_2 <= exc_1;
	end generate;
	
	IF_SQ_BITS_GT_4_A2_A2_A2_EXCEPTION_DELAY: if (sq_bits>=5) generate
		EXCEPTION_MULTIPLIER_A2_A2_A2_DELAY: delay_block generic map (SQRT_MULTIPLIER_M_DELAY) port map (CLK,RESET,STALL,exc_2,exc_3);
	end generate;
	ELSE_A2_A2_A2_EXCEPTION_DELAY: if (sq_bits<5) generate
		exc_3 <= exc_2;
	end generate;
	
	EXCEPTION_MULTIPLIER_L_DELAY: delay_block generic map (SQRT_MULTIPLIER_L_DELAY) port map (CLK,RESET,STALL,exc_3,exc_4);

	--------------------------------------------------------------------------------------------
	--												Asynchronous Assignments										--
	--------------------------------------------------------------------------------------------	
	s	<=	OP(exp_bits+man_bits);
	e	<=	OP(exp_bits+man_bits-1 downto man_bits);
	f	<=	OP(man_bits-2 downto 0);
   
	value	<= (s_4 & exp_4 & '1' & man_out) when (exc_4 ='0') else (others=>'0');
	
	--------------------------------------------------------------------------------------------
	--               							Synchronous Assignments                					--
	--------------------------------------------------------------------------------------------
	synchro: process (CLK,RESET,STALL) is
	begin
		if(RESET = '1') then
			rdy_s				<= '0';
			s_s				<= '0';
			exp_s				<= (others=>'0');
			exc_s				<= '0';

			temp_done		<= '0';
			temp_result		<= (others=>'0');
			temp_exception	<= '0';
		elsif(rising_edge(CLK) and STALL = '0') then
			rdy_s				<= rdy;
			s_s				<= s;
			exp_s				<= exp;
			exc_s				<= exc;
			
			temp_done		<= rdy_4;
			temp_result		<= value;
			temp_exception	<= exc_4;
		end if;
	end process;

	DONE				<= temp_done;
	RESULT 			<= temp_result;
	EXCEPTION_OUT 	<= temp_exception and temp_done;
	
end fp_sqrt_arch; 
