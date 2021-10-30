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
--  REVISED BY   | Xin Fang		                        --
--  -------------+------------------------------------  --
--  DATE         | May 2015                             --
--======================================================--

--**********************************************************************************--
--                                                                                  --
--	Copyright (C) 2015		                                            --
--                                                                                  --
--	This program is free software; you can redistribute it and/or               --
--	modify it under the terms of the GNU General Public License                 --
--	as published by the Free Software Foundation; either version 3              --
--	of the License, or (at your option) any later version.                      --
--                                                                                  --
--	This program is distributed in the hope that it will be useful,             --
--	but WITHOUT ANY WARRANTY; without even the implied warranty of              --
--	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               --
--	GNU General Public License for more details.                                --
--                                                                                  --
--	You should have received a copy of the GNU General Public License           --
--	along with this program.  If not, see<http://www.gnu.org/licenses/>.        --
--                                                                           	    --
--**********************************************************************************--

--======================================================--
--                      LIBRARIES                       --
--======================================================--

-- IEEE Libraries --
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all; -- signed, 2's complement number

library fp_lib;
use fp_lib.float_pkg.all;

----------------------------------------------------------
--               Floating Point Square Root             --
----------------------------------------------------------
entity div is
	generic
	(
	   bits								:	integer := 14
	);
	port
	(
		--inputs
		CLK								:	in		std_logic;
		RESET								:	in		std_logic;
		STALL								:	in		std_logic;
	 	odd_in							:	in		std_logic;
		Y_in								:	in		std_logic_vector(4*bits-1 downto 0); --56
		--outputs
		res								:	out	std_logic_vector(4*bits-1 downto 0)  --56
	);	
end div;


architecture arch of div is

	component sqrt_r_table is
	port 
	(
		clka 								: in	std_logic;
		addra								: in	std_logic_VECTOR(bits-1 downto 0);--14
		ena								: in	std_logic;
		rsta								: in	std_logic;
		douta								: out std_logic_VECTOR(bits+1 downto 0)--16
	);
	end component;


--	component sqrt_m_table is
--	port 
--	(
--		clock 								: in	std_logic;
--		address								: in	std_logic_VECTOR(bits-1 downto 0);
--		clken								: in	std_logic;
--		aclr								: in	std_logic;
--		q								: out std_logic_VECTOR(4*bits-2 downto 0)
--	);
--	end component;
--
--
--	component sqrt_m_mul2_table is
--	port 
--	(
--		clock 								: in	std_logic;
--		address								: in	std_logic_VECTOR(bits-1 downto 0);
--		clken								: in	std_logic;
--		aclr								: in	std_logic;
--		q								: out	std_logic_VECTOR(4*bits+1 downto 0)
--	);
--	end component;


	component sqrt_multiplier_yr is
	port 
	(
		clk								: in std_logic;
   	a									: IN std_logic_VECTOR(bits+2 downto 0);
		b									: IN std_logic_VECTOR(4*bits+1 downto 0);
		ce									: IN std_logic;
		sclr								: IN std_logic;
		p									: OUT std_logic_VECTOR(5*bits+4 downto 0)
	);
   end component;

	
	component sqrt_multiplier_s is
	port 
	(
		clk								: in std_logic;
     	a									: IN std_logic_VECTOR(bits-1 downto 0);
		b									: IN std_logic_VECTOR(bits-1 downto 0);
		ce									: IN std_logic;
		sclr								: IN std_logic;
		p									: OUT std_logic_VECTOR(2*bits-1 downto 0)
	);
	end component;
	

	component sqrt_multiplier_m is
	port 
	(
		clk								: IN std_logic;
		ce									: IN std_logic;
		sclr								: IN std_logic;
		a									: IN std_logic_VECTOR(2*bits-1 downto 0);
		b									: IN std_logic_VECTOR(bits-1 downto 0);
		p									: OUT std_logic_VECTOR(3*bits-1 downto 0)
	);
	end component;
	

	component sqrt_multiplier_l is
	port 
	(
		clk								: IN std_logic;
		a									: IN std_logic_VECTOR(bits+1 downto 0);
		b									: IN std_logic_VECTOR(4*bits+1 downto 0);
		ce									: IN std_logic;
		sclr								: IN std_logic;
		p									: OUT std_logic_VECTOR(5*bits+3 downto 0)
	);
	end component;

	--======================================================--
	--                      SIGNALS                         --
	--======================================================--
	signal enable						: std_logic;
	
	signal y 							: std_logic_vector(4*bits-1 downto 0);
	signal yk 							: std_logic_vector(bits-1 downto 0);
	signal y_ext						: std_logic_vector(4*bits+1 downto 0);
	signal r 							: std_logic_vector(bits+1 downto 0);
	signal r_ext 						: std_logic_vector(bits+2 downto 0);

	signal a_mul 						: std_logic_vector(5*bits+4 downto 0);
	signal a_mul_short 				: std_logic_vector(4*bits+1 downto 0);
	signal a_mul_short_short 		: std_logic_vector(1 downto 0);
	signal a_mul_subone_short 		: std_logic_vector(1 downto 0);
	signal a_s 							: std_logic_vector(4*bits+1 downto 0); 
	signal a_s_neg 					: std_logic_vector(4*bits+1 downto 0); 		
	signal a_half 						: std_logic_vector(4*bits+1 downto 0);
	
	signal a2	 						: std_logic_vector(bits-1 downto 0);
	signal a2_neg 						: std_logic_vector(bits-1 downto 0);
	signal a2_pos 						: std_logic_vector(bits-1 downto 0);
	signal a3	 						: std_logic_vector(bits-1 downto 0);
	signal a3_neg 						: std_logic_vector(bits-1 downto 0);
	signal a3_pos 						: std_logic_vector(bits-1 downto 0);

	signal a2_pos_a2_a2_delay		: std_logic_vector(bits-1 downto 0);
	signal a3_pos_a2_a2_delay		: std_logic_vector(bits-1 downto 0);

	signal mul_a2_a2_short	 		: std_logic_vector(2*bits-1 downto 0);
	signal mul_a2_a2_ext 			: std_logic_vector(4*bits+3 downto 0);
	signal mul_a2_a2 					: std_logic_vector(4*bits+1 downto 0);

	signal a2_pos_a2_a3_delay		: std_logic_vector(bits-1 downto 0);

	signal mul_a2_a2_short_a2_a3_delay : std_logic_vector(2*bits-1 downto 0);
		
	signal mul_a2_a3_short	 		: std_logic_vector(2*bits-1 downto 0);
	signal mul_a2_a3_ext 			: std_logic_vector(4*bits+3 downto 0);
	signal mul_a2_a3 					: std_logic_vector(4*bits+1 downto 0);
	
	signal mul_a2_a2_a2_short	 	: std_logic_vector(3*bits-1 downto 0);
	signal mul_a2_a2_a2_short_neg : std_logic_vector(3*bits-1 downto 0);
	signal zero_mul_a2_a2_a2_short: std_logic;
	signal mul_a2_a2_a2_ext 		: std_logic_vector(4*bits+5 downto 0);        
	signal mul_a2_a2_a2 				: std_logic_vector(4*bits+1 downto 0);
	
	signal sum_two_short 			: std_logic_vector(1 downto 0);

	signal sum_two 					: std_logic_vector(4*bits+1 downto 0);
	signal sum_two_a2_a2_delay		: std_logic_vector(4*bits+1 downto 0);
	signal sum_three 					: std_logic_vector(4*bits+1 downto 0);
	signal sum_three_a2_a3_delay	: std_logic_vector(4*bits+1 downto 0);
	signal sum_four 					: std_logic_vector(4*bits+1 downto 0);
	signal sum_four_a2_a2_a2_delay: std_logic_vector(4*bits+1 downto 0);

	signal a_sign 						: std_logic; 
	signal a_sign_0					: std_logic;
	signal a_sign_1 					: std_logic; 
	signal a_sign_2 					: std_logic; 
	signal a_sign_3 					: std_logic; 

	signal b 							: std_logic_vector(4*bits+1 downto 0); 

	signal m 							: std_logic_vector(4*bits-2 downto 0); 
	signal m_mul2 						: std_logic_vector(4*bits+1 downto 0); 
	
	signal m_corr 						: std_logic_vector(bits+1 downto 0);
	signal m_corr_0					: std_logic_vector(bits+1 downto 0);
	signal m_corr_1					: std_logic_vector(bits+1 downto 0);
	signal m_corr_2					: std_logic_vector(bits+1 downto 0);
	signal m_corr_3					: std_logic_vector(bits+1 downto 0);

	signal mul_m_b 					: std_logic_vector(5*bits+3 downto 0);
 
	signal odd 							: std_logic;
	signal odd_s 						: std_logic;
begin

	enable<= not STALL;
	y		<= y_in;
	odd	<= odd_in;

	-----------------------------------------------------------------------------------------
	--               						Table Lookup Instantiation   									--
	-----------------------------------------------------------------------------------------
	-- reduction
	yk <= y(4*bits-1 downto 3*bits);
	
	r_table: sqrt_r_table
	port map
	(
		clka  							=> CLK,
		rsta								=> RESET,
		ena								=> enable,
		addra								=>	yk,
		douta								=>	r
	);	
	
--	m_table: sqrt_m_table
--	port map
--	(
--		clock								=> CLK,
--		aclr								=> RESET,
--		clken								=> enable,
--		address								=>	yk,
--		q								=>	m
--	);	
--
--	m_mul2_table: sqrt_m_mul2_table
--	port map
--	(
--		clock								=> CLK,
--		aclr								=> RESET,
--		clken								=> enable,
--		address								=>	yk,
--		q								=>	m_mul2
--	);	

	-- post processing
	--m_corr 		<= m_mul2 when (odd_s='1') else ("010" & m);
	m_corr			<= r ; --16 --& "000000000000000000000000000000000000000000";--58
	
	-----------------------------------------------------------------------------------------
	--               						Multiplier Instantiation   									--
	-----------------------------------------------------------------------------------------
	r_ext <= '0' & r(bits+1 downto 0) ;
	
	multiplier_y_r : sqrt_multiplier_yr
	port map
	(
		clk								=>	clk,
		sclr								=> RESET,
		ce									=> enable,
      a									=>	r_ext,
      b									=>	y_ext,
      p									=>	a_mul
	);     

	-- estimation
	-- a_half, sum_two     
	a_mul_short				<= a_mul(5*bits+2 downto bits+1);
	a_mul_short_short		<= a_mul_short(4*bits+1 downto 4*bits);         -- integer 00 or 01    

	a_mul_subone_short	<= a_mul_short_short - "01";   -- 11 or 00
	a_s	 					<= a_mul_subone_short & a_mul_short(4*bits-1 downto 0);

	a_sign 					<= a_s(4*bits+1);
	a_half 					<= a_s(4*bits+1) & a_s(4*bits+1 downto 1);
	a_s_neg 					<= -(a_s);

	a2 		<= a_s(3*bits-1 downto 2*bits);
	a2_neg 	<= a_s_neg(3*bits-1 downto 2*bits);
	a2_pos 	<= a2 when (a_sign = '0') else a2_neg;

	a3			<= a_s(2*bits-1 downto bits);
	a3_neg 	<= a_s_neg(2*bits-1 downto bits);
	a3_pos 	<= a3 when (a_sign = '0') else a3_neg;

	sum_two_short 			<= a_s_neg(4*bits+1 downto 4*bits) + "01";
	sum_two 					<= sum_two_short & a_s_neg(4*bits-1 downto 0);

	a_sign_0 <= a_sign;
	M_CORR_0_REG : bus_delay_block generic map (bits+2,DIV_MULTIPLIER_YR_DELAY) port map (CLK,RESET,STALL,m_corr,m_corr_0);

	-- a2xa2, sum_three
	MUL_A2_A2_BITS_GT_1: if (bits>1) generate
		multiplier_a2_a2 : sqrt_multiplier_s
		port map
		(
			clk 	=> clk,
			sclr	=> RESET,
			ce		=> enable,
			a 		=> a2_pos,
			b 		=> a2_pos,
			p 		=> mul_a2_a2_short
		);     
		mul_a2_a2_ext	<= CONV_STD_LOGIC_VECTOR(0,2*bits+4) & mul_a2_a2_short(2*bits-1 downto 0);
		mul_a2_a2 		<= mul_a2_a2_ext(4*bits+1 downto 0);
		
		--mul_a2_a2_ext	<= CONV_STD_LOGIC_VECTOR(0,2*bits+5) & mul_a2_a2_short(2*bits-1 downto 1);
		--mul_a2_a2 		<= mul_a2_a2_ext(4*bits+3 downto 2);
		
		-- sum_three
		SUM_TWO_DELAY  : bus_delay_block generic map (4*bits+2,DIV_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,sum_two,sum_two_a2_a2_delay);
		SUM_THREE_INST : parameterized_adder generic map (4*bits+2) port map (sum_two_a2_a2_delay,mul_a2_a2,'0',sum_three,open);

		A2_POS_A2_A2_REG	: bus_delay_block generic map (bits,DIV_MULTIPLIER_S_DELAY)port map (CLK,RESET,STALL,a2_pos,a2_pos_a2_a2_delay);
		A3_POS_A2_A2_REG	: bus_delay_block generic map (bits,DIV_MULTIPLIER_S_DELAY)port map (CLK,RESET,STALL,a3_pos,a3_pos_a2_a2_delay);
		
		A_SIGN_1_REG		: delay_block		generic map (DIV_MULTIPLIER_S_DELAY)	 			port map (CLK,RESET,STALL,a_sign_0,a_sign_1);	
		M_CORR_1_REG		: bus_delay_block generic map (bits+2,DIV_MULTIPLIER_S_DELAY)	port map (CLK,RESET,STALL,m_corr_0,m_corr_1);
	end generate;
	
	MUL_A2_A2_BITS_EQ_1: if (bits=1) generate
		m_corr_1		<= m_corr_0;
		sum_three	<= sum_two;
	end generate;
	
	-- a2xa3, sum_four
	MUL_A2_A3_BITS_GT_EQ_3: if (bits>=3) generate	
		multiplier_a2_a3 : sqrt_multiplier_s
		port map
		(
			clk	=> clk,
			sclr	=> RESET,
			ce		=> enable,
			a 		=> a2_pos_a2_a2_delay,
			b 		=> a3_pos_a2_a2_delay,
			p 		=> mul_a2_a3_short
		);		
		mul_a2_a3_ext	<= CONV_STD_LOGIC_VECTOR(0,3*bits+3) & mul_a2_a3_short(2*bits-1 downto bits-1);
		mul_a2_a3		<= mul_a2_a3_ext(4*bits+1 downto 0) ;

		--mul_a2_a3_ext	<= CONV_STD_LOGIC_VECTOR(0,3*bits+4) & mul_a2_a3_short(2*bits-1 downto bits);
		--mul_a2_a3		<= mul_a2_a3_ext(4*bits+3 downto 2);
		
		-- sum_four
		SUM_THREE_DELAY : bus_delay_block generic map (4*bits+2,DIV_MULTIPLIER_S_DELAY) port map (CLK,RESET,STALL,sum_three,sum_three_a2_a3_delay);
		SUM_FOUR_INST			 : parameterized_adder generic map (4*bits+2) port map (sum_three_a2_a3_delay,mul_a2_a3,'0',sum_four,open);

		MUL_A2_A2_SHORT_A2_A3_REG	: bus_delay_block generic map (2*bits,DIV_MULTIPLIER_S_DELAY)	port map (CLK,RESET,STALL,mul_a2_a2_short   ,mul_a2_a2_short_a2_a3_delay);
		A2_POS_A2_A3_REG				: bus_delay_block generic map (bits,DIV_MULTIPLIER_S_DELAY)	port map (CLK,RESET,STALL,a2_pos_a2_a2_delay,a2_pos_a2_a3_delay);
		
		A_SIGN_2_REG					: delay_block		generic map (DIV_MULTIPLIER_S_DELAY)	 			port map (CLK,RESET,STALL,a_sign_1,a_sign_2);	
		M_CORR_2_REG					: bus_delay_block generic map (bits+2,DIV_MULTIPLIER_S_DELAY)	port map (CLK,RESET,STALL,m_corr_1,m_corr_2);
	end generate;
	
	MUL_A2_A3_BITS_LT_3: if (bits<3) generate
		m_corr_2	<= m_corr_1;
		sum_four <= sum_three;   	
	end generate;    	

	-- a2xa2xa2, b
	MUL_A2_A2_A2_BITS_GT_EQ_5: if (bits>=5) generate		
		multiplier_a2_a2_a2 : sqrt_multiplier_m
		port map
		(
			clk	=> clk,
			sclr	=> RESET,
			ce		=> enable,
			a		=> mul_a2_a2_short_a2_a3_delay,
			b		=> a2_pos_a2_a3_delay,
			p		=> mul_a2_a2_a2_short
  		); 
		A_SIGN_3_REG: delay_block generic map (DIV_MULTIPLIER_M_DELAY) port map (CLK,RESET,STALL,a_sign_2,a_sign_3);


		mul_a2_a2_a2_short_neg <= -(mul_a2_a2_a2_short);
		all_zero_a2_a2_a2_short: parameterized_or_gate generic map (3*bits) port map (mul_a2_a2_a2_short,zero_mul_a2_a2_a2_short);
		mul_a2_a2_a2_ext <=	(3*bits+6-1 downto 0 => '0') & mul_a2_a2_a2_short(3*bits-1 downto 2*bits) when (a_sign_3='0' or zero_mul_a2_a2_a2_short='0') else (3*bits+6-1 downto 0 => '1') & mul_a2_a2_a2_short_neg(3*bits-1 downto 2*bits);
		mul_a2_a2_a2 <= mul_a2_a2_a2_ext(4*bits+1 downto 0);

      -- CONV_STD_LOGIC_VECTOR(0,3*bits+6) 
		-- CONV_STD_LOGIC_VECTOR(((2**(3*bits+6))-1),3*bits+6)

		--mul_a2_a2_a2_short_neg <= -(mul_a2_a2_a2_short);
		--all_zero_a2_a2_a2_short: parameterized_or_gate generic map (3*bits) port map (mul_a2_a2_a2_short,zero_mul_a2_a2_a2_short);
		--mul_a2_a2_a2_ext <=	CONV_STD_LOGIC_VECTOR(0,3*bits+6) & mul_a2_a2_a2_short	 (3*bits-1 downto 2*bits) when (a_sign_3='0' or zero_mul_a2_a2_a2_short='0') else 
		--							CONV_STD_LOGIC_VECTOR(((2**(3*bits+6))-1),3*bits+6) & mul_a2_a2_a2_short_neg(3*bits-1 downto 2*bits);
		--mul_a2_a2_a2 <= mul_a2_a2_a2_ext(4*bits+5 downto 4);

		
		
		-- b
		SUM_FOUR_DELAY : bus_delay_block generic map(4*bits+2,DIV_MULTIPLIER_M_DELAY) port map(CLK,RESET,STALL,sum_four,sum_four_a2_a2_a2_delay);
		SUM_B				: parameterized_subtractor generic map (4*bits+2) port map (sum_four_a2_a2_a2_delay,mul_a2_a2_a2,b);

		M_CORR_3_REG		: bus_delay_block generic map (bits+2,DIV_MULTIPLIER_M_DELAY) port map (CLK,RESET,STALL,m_corr_2,m_corr_3);		
	end generate;    

	MUL_A2_A2_A2_BITS_LT_5: if (bits<5) generate
		m_corr_3 <= m_corr_2;
		b <= sum_four;
	end generate;
	
	
	multiplier_m_b : sqrt_multiplier_l
	port map
	(
		clk 	=> clk,
		sclr	=> RESET,
		ce		=> enable,
		a 		=> m_corr_3,
		b 		=> b,
		p 		=> mul_m_b
	);     
   
	RES <= mul_m_b(5*bits-1 downto bits);
	--RES <= mul_m_b(8*bits-2 downto 4*bits-1);
	----------------------------------------------------------
	--               Synchronous Assignments                --
	----------------------------------------------------------
	synchro: process (CLK,RESET,STALL)
	begin
		if(RESET = '1') then
			y_ext			<= (others => '0');	        				
			odd_s			<= '0';						
		elsif(rising_edge(CLK) and STALL = '0') then
			y_ext			<= "01" & y;	        			
			odd_s			<= odd;			
		end if;
	end process;
end arch; 
