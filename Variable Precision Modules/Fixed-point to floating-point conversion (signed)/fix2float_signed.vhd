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
--       Fixed point to floating point conversion       --
----------------------------------------------------------
entity fix2float_signed is
	generic
	(
		fix_bits						: integer := 10;
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
		FIXED							: in	std_logic_vector(fix_bits-1 downto 0);
		ROUND							: in	std_logic;
		EXCEPTION_IN				: in	std_logic;
		--outputs
		FLOAT							: out	std_logic_vector(exp_bits+man_bits downto 0)	:=	(others=>'0');
		EXCEPTION_OUT				: out	std_logic := '0';
		DONE							: out	std_logic := '0'
	);
end fix2float_signed;

architecture fix2float_arch of fix2float_signed is
--======================================================--
--                     CONSTANTS                        --
--======================================================--
	constant	bias					: integer := (2**(exp_bits-1))-1;
	constant	shift_bits			: integer := ceil_log2(fix_bits);

	-- modified by xjwang
	constant  fix_man_bits 		: integer := max_width(fix_bits,man_bits+1);

--======================================================--
--                      SIGNALS                         --
--======================================================--
	signal	rdy1					:	std_logic :=	'0';
	signal	rdy2					:	std_logic :=	'0';
	signal	rdy3					:	std_logic :=	'0';
	signal	rdy4					:	std_logic :=	'0';
	signal	rnd1					:	std_logic :=	'0';
	signal	rnd2					:	std_logic :=	'0';
	signal	rnd3					:	std_logic :=	'0';
	signal	sign					:	std_logic :=	'0';
	signal	sign1					:	std_logic :=	'0';
	signal	sign2					:	std_logic :=	'0';
	signal	sign3					:	std_logic :=	'0';
	signal	exc1					:	std_logic :=	'0';
	signal	exc2					:	std_logic :=	'0';
	signal	exc3					:	std_logic :=	'0';
	signal	exc4					:	std_logic :=	'0';
	signal	dummy_exc			:	std_logic :=	'0';
	signal	cout3					:	std_logic :=	'0';
	signal	cout4					:	std_logic :=	'0';
	signal	abs_exc				:	std_logic :=	'0';
	signal	abs_exc1				:	std_logic :=	'0';
	signal	abs_exc2				:	std_logic :=	'0';
	signal	abs_exc3				:	std_logic :=	'0';
	signal	abs_exc4				:	std_logic :=	'0';
	signal	all_zero				:	std_logic :=	'0';
	signal	n_all_zero			:	std_logic :=	'0';
	signal	all_zero1			:	std_logic :=	'0';
	signal	all_zero2			:	std_logic :=	'0';
	signal	all_zero3			:	std_logic :=	'0';
	signal	all_zero4			:	std_logic :=	'0';
	signal	exc_out4				:	std_logic :=	'0';
	signal	ctrl					:	std_logic :=	'0';
	signal	absl					:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');
	signal	abs1					:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');
	signal	abs2					:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');
	signal	m1						:	std_logic_vector(shift_bits-1 downto 0) :=	(others=>'0');
	signal	m2						:	std_logic_vector(shift_bits-1 downto 0) :=	(others=>'0');
	signal	m2_wide				:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	man2					:	std_logic_vector(fix_bits-1 downto 0) :=	(others=>'0');
	signal	man3					:	std_logic_vector(fix_man_bits-1 downto 0) :=	(others=>'0');
	signal	man_out3				:	std_logic_vector(fix_man_bits-1 downto 0) :=	(others=>'0');
	signal	exp2					:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	exp3					:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');
	signal	float3				:	std_logic_vector(exp_bits+man_bits downto 0) :=	(others=>'0');
	signal	float4				:	std_logic_vector(exp_bits+man_bits downto 0) :=	(others=>'0');
	signal	float_out4			:	std_logic_vector(exp_bits+man_bits downto 0) :=	(others=>'0');
	signal	zero_float			:	std_logic_vector(man_bits+exp_bits downto 0) :=	(others=>'0');
	signal	zero_man				:	std_logic_vector(fix_man_bits-1 downto 0) :=	(others=>'0');
	signal	const					:	std_logic_vector(exp_bits-1 downto 0) :=	(others=>'0');

begin

	--absolute value
	abs_val : parameterized_absolute_value
	generic map
	(
		bits							=>	fix_bits
	)
	port map
	(
		IN1							=>	FIXED,
		EXC							=>	abs_exc,
		OUT1							=>	absl
	);

	--priority encoder
	pri_enc	: parameterized_priority_encoder
	generic map
	(
		man_bits						=>	fix_bits,
		shift_bits					=>	shift_bits
	)
	port map
	(
		MAN_IN						=>	abs1,
		SHIFT							=>	m1,
		EXCEPTION_OUT				=>	dummy_exc
	);

	--subtractor
	sub	: parameterized_subtractor
	generic map
	(
		bits							=>	exp_bits
	)
	port map
	(
		A								=>	std_logic_vector(const),
		B								=>	m2_wide,
		O								=>	exp2
	);


	--shifter
	var_shf	: parameterized_variable_shifter
	generic map
	(
		bits							=>	fix_bits,
		select_bits					=>	shift_bits,
		direction					=>	'1'
	)
	port map
	(
		I								=>	abs2,
		S								=>	m2,
		CLEAR							=>	'0',
		O								=>	man2
	);

	--adder
	add	: parameterized_adder
	generic map
	(
		bits							=>	fix_man_bits
	)
	port map
	(
		A								=>	man3,
		B								=>	zero_man,
		CIN							=>	'0',
		S								=>	man_out3,
		COUT							=>	cout3
	);

	--output mux
	mux	: parameterized_mux
	generic map
	(
		bits							=>	exp_bits+man_bits+1
	)
	port map
	(
		A								=>	zero_float,
		B								=>	float4,
		S								=>	ctrl,
		O								=>	float_out4
	);

	--OR gate
	or_gate	: parameterized_or_gate
	generic map
	(
		bits							=>	fix_bits
	)
	port map
	(
		A								=>	FIXED,
		O								=>	n_all_zero
	);

--======================================================--
--            ASYNCHRONOUS SIGNAL ASSIGNMENTS           --
--======================================================--

	sign																		<=	FIXED(fix_bits-1);
	all_zero																	<=	NOT(n_all_zero);
	-- modified
	--	zero_man																<=	(others=>'0');
	zero_man(fix_man_bits-1 downto fix_man_bits-fix_bits+2)	<= (others=>'0'); 
	zero_man(fix_man_bits-fix_bits+1)								<= rnd3;
	zero_man(fix_man_bits-fix_bits downto 0) 						<= (others=>'0');
	zero_float																<=	(others=>'0');
	const																		<=	conv_std_logic_vector(fix_bits+bias-1,exp_bits);
	m2_wide(exp_bits-1 downto shift_bits)							<=	(others=>'0');
	m2_wide(shift_bits-1 downto 0)									<=	m2;
	float3(exp_bits+man_bits)											<=	sign3;
	float3(exp_bits+man_bits-1 downto man_bits)					<=	exp3;
	-- modified
	--	float3(man_bits-1 downto 0)									<=	man_out3(man_bits downto 1); --truncate rouding bit
	float3(man_bits-1 downto 0)										<=	man_out3(fix_man_bits-1 downto fix_man_bits-man_bits) when fix_bits-1 >= man_bits else man_out3(fix_man_bits-1 downto 1);
		
	
	--3-input OR
	exc_out4																	<=	cout4 OR exc4 OR abs_exc4;
	--2-input OR
	ctrl																		<=	exc_out4 OR all_zero4;

--======================================================--
--             SYNCHRONOUS SIGNAL ASSIGNMENTS           --
--======================================================--
	synchronous: process (CLK,RESET,STALL) is
	begin
		if (RESET = '1') then
			--first clock cycle
			rdy1						<=	'0';
			rnd1						<=	'0';
			sign1						<=	'0';
			abs1						<=	(others => '0');
			exc1						<=	'0';
			abs_exc1					<=	'0';
			all_zero1				<=	'0';

			--second clock cycle
			rdy2						<=	'0';
			rnd2						<=	'0';
			sign2						<=	'0';
			m2							<=	(others => '0');
			abs2						<=	(others => '0');
			exc2						<=	'0';
			abs_exc2					<=	'0';
			all_zero2				<=	'0';

			--third clock cycle
			rdy3						<= '0';
			rnd3						<=	'0';
			sign3						<=	'0';
			exp3						<=	(others => '0');
			-- modified by xjwang
			--	man3					<=	man2(fix_bits-2 downto fix_bits-man_bits-2);
			man3(fix_man_bits-1 downto fix_man_bits-fix_bits+1) <= (others => '0'); -- remove hidden 1
			man3(fix_man_bits-fix_bits downto 0) 					 <= (others=>'0');
			exc3						<=	'0';
			abs_exc3					<=	'0';
			all_zero3				<=	'0';

			--fourth clock cycle
			rdy4						<=	'0';
			float4					<=	(others => '0');
			cout4						<=	'0';
			exc4						<=	'0';
			abs_exc4					<=	'0';
			all_zero4				<=	'0';

			--fifth clock cycle
			DONE						<=	'0';
			FLOAT						<=	(others => '0');
			EXCEPTION_OUT			<=	'0';		
		elsif(rising_edge(CLK) and STALL = '0') then
			--first clock cycle
			rdy1						<=	READY;
			rnd1						<=	ROUND;
			sign1						<=	sign;
			abs1						<=	absl;
			exc1						<=	EXCEPTION_IN;
			abs_exc1					<=	abs_exc;
			all_zero1				<=	all_zero;

			--second clock cycle
			rdy2						<=	rdy1;
			rnd2						<=	rnd1;
			sign2						<=	sign1;
			m2							<=	m1;
			abs2						<=	abs1;
			exc2						<=	exc1;
			abs_exc2					<=	abs_exc1;
			all_zero2				<=	all_zero1;

			--third clock cycle
			rdy3						<=	rdy2;
			rnd3						<=	rnd2;
			sign3						<=	sign2;
			exp3						<=	exp2;
			-- modified by xjwang
			--	man3					<=	man2(fix_bits-2 downto fix_bits-man_bits-2);
			man3(fix_man_bits-1 downto fix_man_bits-fix_bits+1)		<= man2(fix_bits-2 downto 0); -- remove hidden 1
			man3(fix_man_bits-fix_bits downto 0) <= (others=>'0');
			exc3						<=	exc2;
			abs_exc3					<=	abs_exc2;
			all_zero3				<=	all_zero2;

			--fourth clock cycle
			rdy4						<=	rdy3;
			float4					<=	float3;
			cout4						<=	cout3;
			exc4						<=	exc3;
			abs_exc4					<=	abs_exc3;
			all_zero4				<=	all_zero3;

			--fifth clock cycle
			DONE						<=	rdy4;
			FLOAT						<=	float_out4;
			EXCEPTION_OUT			<=	exc_out4;
		end if;
	end process;
end fix2float_arch;
