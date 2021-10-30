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
--  DATE		 | 29 Sep. 2013					        --
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
use IEEE.std_logic_signed.all;

-- float
library fp_lib;
use fp_lib.float_pkg.all;

----------------------------------------------------------
--       Floating point to fixed point conversion       --
----------------------------------------------------------
entity float2fix is
	generic
	(	
		fix_bits						: integer := 32;
		exp_bits						: integer := 8;
		man_bits						: integer := 23
	);
	port
	(
		--inputs
		CLK							: in	std_logic;
		RESET							: in	std_logic;
		READY							: in	std_logic;
		STALL							: in	std_logic;
		FLOAT							: in	std_logic_vector(exp_bits+man_bits downto 0);
		ROUND							: in	std_logic;
		EXCEPTION_IN				: in	std_logic;
		--outputs
		FIXED							: out	std_logic_vector(fix_bits-1 downto 0) := (others=>'0');
		EXCEPTION_OUT				: out	std_logic := '0';
		DONE							: out	std_logic := '0'
	);
end float2fix;

----------------------------------------------------------
--       Floating point to fixed point conversion       --
----------------------------------------------------------

architecture float2fix_arch of float2fix is

--======================================================--
--                     FUNCTIONS                        --
--======================================================--
	--function to calculate ceil(log2(n))
	function ceil_log2 (input: integer) return integer is
		variable max		:	integer :=1; -- exp=0 => max=2^0=1
		variable exp		:	integer :=0;
	begin
		log_loop: while max < input loop
			exp	:=	exp+1;	-- increment exponent
			max	:=	max*2;	-- max = 2^exp
		end loop log_loop;
		return exp; -- exponent that gives (2^exp) >= input
	end ceil_log2;
	
	function maxval (arg1, arg2 : integer) return integer is
	  variable result: integer;
	begin
	  if arg1>arg2 then
	    result:=arg1;
	  else
	    result:=arg2;
	  end if;
	  return result;
  end maxval;

--======================================================--
--                     CONSTANTS                        --
--======================================================--
  -- modified by xjwang
	constant	bias					: integer := (2**(exp_bits-1))-1;
	constant	of_limit				: integer := fix_bits+bias-2;
	
	-- modified by xjwang
	constant	shifted_bits		: integer := fix_bits+man_bits;
	constant	shift_bits			: integer := ceil_log2(shifted_bits);
	constant  shift2_bits 		: integer := maxval(shift_bits,exp_bits);

--======================================================--
--                      SIGNALS                         --
--======================================================--
	signal	rdy1					:	std_logic :=	'0';
	signal	rdy2					:	std_logic :=	'0';
	signal	rdy3					:	std_logic :=	'0';
	signal	rnd1					:	std_logic :=	'0';
	signal	rnd2					:	std_logic :=	'0';
	signal	s						:	std_logic :=	'0';
	signal	negative1			:	std_logic :=	'0';
	signal	exc1					:	std_logic :=	'0';
	signal	exc2					:	std_logic :=	'0';
	signal	exc3					:	std_logic :=	'0';
	signal	cout2					:	std_logic :=	'0';
	signal	uf_lt					:	std_logic :=	'0';
	signal	uf_eq					:	std_logic :=	'0';
	signal	uf_gt					:	std_logic :=	'0';
	signal	of_lt					:	std_logic :=	'0';
	signal	of_eq					:	std_logic :=	'0';
	signal	of_gt					:	std_logic :=	'0';
	signal	lt1					:	std_logic :=	'0';
	signal	underflow1			:	std_logic :=	'0';
	signal	overflow1			:	std_logic :=	'0';
	signal	all_zero				:	std_logic :=	'0';
	signal	n_all_zero			:	std_logic :=	'0';
	signal	all_zero1			:	std_logic :=	'0';
	signal	all_zero2			:	std_logic :=	'0';
	signal	all_zero3			:	std_logic :=	'0';
	signal	exc_out2				:	std_logic :=	'0';
	signal	exc_in1				:	std_logic :=	'0';
	signal	ctrl					:	std_logic :=	'0';
	signal	bias_vector			:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	of_vector			:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	e						:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	f						:	std_logic_vector(man_bits-1 downto 0) :=	(others=>'0');
	signal	shift					:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	shift1				:	std_logic_vector(shift_bits-1 downto 0) :=	(others=>'0');
	signal	shift2				:	std_logic_vector(shift2_bits-1 downto 0) :=	(others=>'0');
	signal	f1						:	std_logic_vector(shifted_bits-1 downto 0) :=	(others=>'0');
	signal	fix1					:	std_logic_vector(shifted_bits-1 downto 0) :=	(others=>'0');
	signal	fix2					:	std_logic_vector(fix_bits downto 0) :=	(others=>'0');
	signal	zero2					:	std_logic_vector(fix_bits downto 0) :=	(others=>'0');
	signal	fix_out2				:	std_logic_vector(fix_bits downto 0) :=	(others=>'0');
	signal	fix3					:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');
	signal	zero3					:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');
	signal	fix_out				:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');

begin

--======================================================--
--             COMPONENT INSTANTIATIONS                 --
--======================================================--

	--subtractor
	sub	: parameterized_subtractor
	generic map
	(
		bits							=>	exp_bits
	)
	port map
	(
		A								=>	e,
		B								=>	bias_vector,
		O								=>	shift
	);

	--underflow comparator
	uflow	: parameterized_comparator
	generic map
	(
		bits							=>	exp_bits
	)
	port map
	(
		A								=>	e,
		B								=>	bias_vector,
		A_GT_B						=>	uf_gt,
		A_EQ_B						=>	uf_eq,
		A_LT_B						=>	uf_lt
	);

	--overflow comparator
	oflow	: parameterized_comparator
	generic map
	(
		bits							=>	exp_bits
	)
	port map
	(
		A								=>	e,
		B								=>	of_vector,
		A_GT_B						=>	of_gt,
		A_EQ_B						=>	of_eq,
		A_LT_B						=>	of_lt
	);

	--shifter
	var_shf	: parameterized_variable_shifter
	generic map
	(
		bits							=>	shifted_bits,
		select_bits					=>	shift_bits,
		direction					=>	'1'						--left
	)
	port map
	(
		I								=>	f1,
		S								=>	shift1,
		clear						 	=> '0',
		O								=>	fix1
	);

	--rounding adder
	round_add	: parameterized_adder
	generic map
	(
		bits							=>	fix_bits+1
	)
	port map
	(
		A								=>	fix2,
		B								=>	zero2,
		CIN							=>	rnd2,
		S								=>	fix_out2,
		COUT							=>	cout2
	);

	--output mux
	out_mux	: parameterized_mux
	generic map
	(
		bits							=>	fix_bits
	)
	port map
	(
		A								=>	zero3,
		B								=>	fix3,
		S								=>	ctrl,
		O								=>	fix_out
	);

	--OR gate
	or_gate	: parameterized_or_gate
	generic map
	(
		bits							=>	exp_bits+man_bits
	)
	port map
	(
		A								=>	FLOAT(exp_bits+man_bits-1 downto 0), --e and f (no s)
		O								=>	n_all_zero
	);

--======================================================--
--            ASYNCHRONOUS SIGNAL ASSIGNMENTS           --
--======================================================--
	--level 0
	s													<=	FLOAT(exp_bits+man_bits);
	e													<=	FLOAT(exp_bits+man_bits-1 downto man_bits);
	f													<=	FLOAT(man_bits-1 downto 0);
	all_zero											<=	NOT(n_all_zero);
	bias_vector										<=	conv_std_logic_vector(bias,exp_bits);
	of_vector										<=	conv_std_logic_vector(of_limit,exp_bits);
	--level 1
	underflow1										<=	lt1 XOR all_zero1;
	exc1												<=	underflow1 OR overflow1 OR exc_in1 OR negative1;
	f1(shifted_bits-1 downto man_bits+1)	<=	(others=>'0');
	f1(man_bits)									<=	'1'; --implied 1
	--level 2
	exc_out2											<=	cout2 OR exc2;
	--level 3
	ctrl												<=	exc3 OR all_zero3;

  -- added by xjwang for type dismatch bug
	shift2(shift2_bits-1 downto exp_bits)	<= (others =>'0');
	shift2(exp_bits-1 downto 0)				<= shift;


--======================================================--
--             SYNCHRONOUS SIGNAL ASSIGNMENTS           --
--======================================================--
	synchronous: process (CLK,RESET,STALL) is
	begin
		if (RESET = '1') then
			--first clock cycle
			rdy1										<=	'0';
			rnd1										<=	'0';
			negative1								<=	'0';
			exc_in1									<=	'0';
			all_zero1								<=	'0';
			overflow1								<=	'0';
			lt1										<=	'0';
			f1(man_bits-1 downto 0)				<=	(others => '0');

			-- added by xjwang for type dismatch bug
			shift1 <= shift2(shift_bits-1 downto 0);

			--second clock cycle
			rdy2										<=	'0';
			rnd2										<=	'0';
			exc2										<=	'0';
			all_zero2								<=	'0';
			
			-- modified by xjwang
			fix2										<=	(others => '0');

			--third clock cycle
			rdy3										<=	'0';
			exc3										<=	'0';
			all_zero3								<=	'0';
			fix3										<=	(others => '0');

			--fourth clock cycle
			DONE										<=	'0';
			FIXED										<=	(others => '0');
			EXCEPTION_OUT							<=	'0';
			
		elsif (rising_edge(CLK) and STALL = '0') then
			--first clock cycle
			rdy1										<=	READY;
			rnd1										<=	ROUND;
			negative1								<=	s;
			exc_in1									<=	EXCEPTION_IN;
			all_zero1								<=	all_zero;
			overflow1								<=	of_gt;
			lt1										<=	uf_lt;
			f1(man_bits-1 downto 0)				<=	f;

			-- added by xjwang for type dismatch bug
			shift1 <= shift2(shift_bits-1 downto 0);

			--second clock cycle
			rdy2										<=	rdy1;
			rnd2										<=	rnd1;
			exc2										<=	exc1;
			all_zero2								<=	all_zero1;
			
			-- modified by xjwang
			fix2										<=	fix1(shifted_bits-1 downto man_bits-1);

			--third clock cycle
			rdy3										<=	rdy2;
			exc3										<=	exc_out2;
			all_zero3								<=	all_zero2;
			fix3										<=	fix_out2(fix_bits downto 1);

			--fourth clock cycle
			DONE										<=	rdy3;
			FIXED										<=	fix_out;
			EXCEPTION_OUT							<=	exc3;
		end if;
	end process;
end float2fix_arch;
