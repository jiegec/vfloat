--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory                        --
--                                                      --
--  AUTHOR       | Al Conti                             --
--  -------------+------------------------------------  --
--  DATE         | 20 Jan 2006                          --
--  -------------+------------------------------------  --
--  REVISED BY   | Jainik Kathiara                      --
--  -------------+------------------------------------  --
--  DATE         | 21 Sept. 2010                        --
--  -------------+------------------------------------  --
--  REVISED BY   | Xin Fang								--
--  -------------+------------------------------------  --
--  DATE		 | Aug. 2014							--
--  -------------+------------------------------------  --

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
--             Floating Point MULTIMAC                  --
----------------------------------------------------------
entity fp_multimac is
  generic 
  (
    exp_bits               : natural := 8;
    man_bits               : natural := 24;
    mult_in_parallel       : natural := 2
  );
  port 
  (
    CLK                    : in std_logic;
	 RESET					   : in std_logic;
	 STALL						: in std_logic;
	 READY						: in std_logic;

    OP1                    : in std_logic_vector(mult_in_parallel*(exp_bits+man_bits+1)-1 downto 0);
    OP2                    : in std_logic_vector(mult_in_parallel*(exp_bits+man_bits+1)-1 downto 0);
	 EXCEPTION_IN				: in std_logic;
    DONE                   : out std_logic;	 
    RESULT                 : out std_logic_vector(exp_bits+man_bits-1 downto 0);
    EXCEPTION_OUT          : out std_logic;
	 aaa							: out std_logic;
	 bbb							: out std_logic;
	 mac 							: out std_logic_vector(exp_bits+man_bits-1 downto 0)
  );
end fp_multimac;

architecture behavioral of fp_multimac is

	-- CONSTANTS
	constant fp_rnd_norm_latency 			: integer := 2;

	-- TYPE
	type input_fp_array	is array(0 to mult_in_parallel-1) of std_logic_vector(exp_bits+man_bits downto 0);
	type mult_fp_array	is array(0 to mult_in_parallel-1) of std_logic_vector(exp_bits+2*man_bits downto 0);
	type add_fp_array		is array(0 to mult_in_parallel-1) of std_logic_vector(exp_bits+man_bits-1 downto 0);
	type add_fp_table		is array(0 to (mult_in_parallel-1)*(ADD_PIPELINE+1)) of add_fp_array;
	type control_array	is array(0 to mult_in_parallel-1) of std_logic_vector(1 downto 0);
	type control_table	is array(0 to 1+(mult_in_parallel-1)*(ADD_PIPELINE+1)) of control_array;

	-- SIGNALS
	-- here I use rectangular arrays when only diaganol arrays are necessary 
	-- this is for progrmability, synthesis tools will whipe out unassigned signals
	signal ready_d 							: std_logic;
	signal exception_in_d 					: std_logic;
	signal sample 								: input_fp_array;
	signal weight 								: input_fp_array;
	signal control 							: control_table;
	signal control_joined 					: control_table;
	signal product 							: mult_fp_array;
	signal intermediate 						: add_fp_table;
	
	--signal  mac 								: std_logic_vector(exp_bits+man_bits-1 downto 0);

	signal mac1 									: std_logic_vector(exp_bits+man_bits-1 downto 0);
	signal mac_control 						: std_logic_vector(1 downto 0);
	signal accum 								: std_logic_vector(exp_bits+man_bits-1 downto 0);
	signal accum_control 					: std_logic_vector(1 downto 0);
	signal accum_control_joined 			: std_logic_vector(1 downto 0);
	--signal sum 									: std_logic_vector(exp_bits+man_bits+2 downto 0);
	--signal sum_control 						: std_logic_vector(1 downto 0);
	signal sum_norm 							: std_logic_vector(exp_bits+man_bits-1 downto 0);
	signal sum_norm_control 				: std_logic_vector(1 downto 0);
  
  	COMPONENT fp_adder
	GENERIC(
		exp_bits : integer:= 8;
		man_bits : integer:= 23
		);
	PORT(
		CLK : IN std_logic;
		RESET : IN std_logic;
		STALL : IN std_logic;
		OP1 : IN std_logic_vector(31 downto 0);
		OP2 : IN std_logic_vector(31 downto 0);
		READY : IN std_logic;
		ROUND : IN std_logic;
		EXCEPTION_IN : IN std_logic;          
		DONE : OUT std_logic;
		RESULT : OUT std_logic_vector(31 downto 0);
		EXCEPTION_OUT : OUT std_logic
		);
	END COMPONENT;
  
begin 

	gen0 : for i in 0 to mult_in_parallel-1 generate  
		process(CLK,RESET,STALL) is
		begin
			if (RESET = '1') then
				sample(i) <= (others=>'0');
				weight(i) <= (others=>'0');
			elsif (CLK'event and CLK = '1' and STALL = '0') then
				sample(i) <= op1((i+1)*(exp_bits+man_bits+1)-1 downto i*(exp_bits+man_bits+1));
				weight(i) <= op2((i+1)*(exp_bits+man_bits+1)-1 downto i*(exp_bits+man_bits+1));
			else
				sample(i) <= sample(i);
				weight(i) <= weight(i);
			end if;
		end process;
	end generate gen0;

	process(CLK,RESET,STALL) is
	begin
		if (RESET = '1') then
			ready_d			<= '0';
			exception_in_d <= '0';
		elsif (CLK'event and CLK = '1' and STALL = '0') then
			ready_d			<= ready;
			exception_in_d <= exception_in;
		else
			ready_d			<= ready_d;
			exception_in_d <= exception_in_d;
		end if;
	end process;
  
	gen1 : for i in 0 to mult_in_parallel-1 generate 
		fp_mul_i : fp_mul
		generic map 
		( 
			exp_bits           		=> exp_bits,
			man_bits           		=> man_bits
		)
		port map 
		(
			CLK							=> CLK,
			RESET							=> RESET,
			STALL							=> STALL,
			OP1							=> sample(i),
			OP2							=> weight(i),
			READY							=> ready_d,
			EXCEPTION_IN				=> exception_in_d,
			DONE							=> control(0)(i)(0),
			RESULT						=> product(i),
			EXCEPTION_OUT 				=> control(0)(i)(1)
		);
	end generate gen1;    

	gen2 : for i in 0 to mult_in_parallel-1 generate 

		--ifgen_i : if i < 2 generate
			rnd_norm_i : rnd_norm_wrapper
			generic map
			(
				exp_bits				=> exp_bits,
				man_bits_in			=> 2*man_bits,
				man_bits_out		=> man_bits-1
			)
			port map
			(
				CLK					=> CLK,
				RESET					=> RESET,
				STALL					=> STALL,
				OP						=> product(i),
				--------------------------------------------------------------------------
				READY					=> control(0)(i)(0),
				ROUND					=> '1',
				EXCEPTION_IN		=> control(0)(i)(1),
				--------------------------------------------------------------------------
				DONE					=> control(1)(i)(1),
				RESULT				=> intermediate(0)(i)(exp_bits+man_bits-1 downto 0),
				EXCEPTION_OUT  	=> control(1)(i)(0)
			);
		--end generate ifgen_i;

--		elsegen_i : if i > 1 generate
--			rnd_norm_i : rnd_norm_wrapper
--			generic map
--			(
--				exp_bits				=> exp_bits,
--				man_bits_in			=> 2*man_bits,
--				man_bits_out		=> man_bits
--			)
--			port map
--			(
--				CLK					=> CLK,
--				RESET					=> RESET,
--				STALL					=> STALL,
--				OP						=> product(i),
--				READY					=> control(0)(i)(1),
--				ROUND					=> '1',
--				EXCEPTION_IN		=> control(0)(i)(0),
--				DONE					=> control(1)(i)(1),
--				RESULT				=> intermediate(0)(i)(exp_bits+man_bits downto 0),
--				EXCEPTION_OUT  	=> control(1)(i)(0)
--			);
--		end generate elsegen_i;
	end generate gen2;
  
	ifgen0: if mult_in_parallel > 1 generate
		gen : for i in 0 to mult_in_parallel-2 generate
			--exception_out
			control_joined(i*(ADD_PIPELINE+1)+1)(i+1)(0) <= control(i*(ADD_PIPELINE+1)+1)(i)(0) or control(i*(ADD_PIPELINE+1)+1)(i+1)(0);
			--DONE
			control_joined(i*(ADD_PIPELINE+1)+1)(i+1)(1) <= control(i*(ADD_PIPELINE+1)+1)(mult_in_parallel-1)(1); 
			--and control(i*(ADD_PIPELINE+1)+1)(i+1)(1);

--			fp_add_i : fp_add
--			generic map 
--			(
--				exp_bits				=> exp_bits,
--				man_bits				=> man_bits+i  
--			)
--			port map 
--			(
--				CLK					=> CLK,
--				RESET					=> RESET,
--				STALL					=> STALL,
--				OP1					=> intermediate(i*(ADD_PIPELINE+1))(i)(i+exp_bits+man_bits downto 0),
--				OP2					=> intermediate(i*(ADD_PIPELINE+1))(i+1)(i+exp_bits+man_bits downto 0),
--				READY					=> control_joined(i*(ADD_PIPELINE+1)+1)(i+1)(1),
--				EXCEPTION_IN 		=> control_joined(i*(ADD_PIPELINE+1)+1)(i+1)(0),
--				DONE					=> control((i+1)*(ADD_PIPELINE+1)+1)(i+1)(1),
--				RESULT				=> intermediate((i+1)*(ADD_PIPELINE+1))(i+1)(i+2+exp_bits+man_bits downto 0),
--				EXCEPTION_OUT		=> control((i+1)*(ADD_PIPELINE+1)+1)(i+1)(0)
--			);

--			ifgen_i : if i < mult_in_parallel-2 generate
--				gen_i : for j in i+2 to mult_in_parallel-1 generate
--				
--					gen_j : for k in 0 to ADD_PIPELINE-1 generate
--						process(CLK,RESET,STALL) is
--						begin
--							if (RESET = '1') then
--								intermediate(i*(ADD_PIPELINE+1)+1+k)(j)<= (others=>'0');
--								control(i*(ADD_PIPELINE+1)+2+k)(j)		<= (others=>'0');
--							elsif (CLK'event and CLK = '1' and STALL = '0') then
--								intermediate(i*(ADD_PIPELINE+1)+1+k)(j)<= intermediate(i*(ADD_PIPELINE+1)+k)(j);
--								control(i*(ADD_PIPELINE+1)+2+k)(j) 		<= control(i*(ADD_PIPELINE+1)+1+k)(j);
--							else
--								intermediate(i*(ADD_PIPELINE+1)+1+k)(j)<= intermediate(i*(ADD_PIPELINE+1)+1+k)(j);
--								control(i*(ADD_PIPELINE+1)+2+k)(j) 		<= control(i*(ADD_PIPELINE+1)+2+k)(j);						
--							end if;
--						end process;
--					end generate gen_j;
--
--					intermediate((i+1)*(ADD_PIPELINE+1))(j)<= intermediate((i+1)*(ADD_PIPELINE+1)-1)(j);
--					control((i+1)*(ADD_PIPELINE+1)+1)(j)	<= control((i+1)*(ADD_PIPELINE+1))(j);
--				end generate gen_i;
--				
--			end generate ifgen_i;


	fp_adder_i: fp_adder 
			generic map
			(
				exp_bits			=> exp_bits,
				man_bits			=> man_bits-1+i
			)
			port map
			(
						CLK => CLK,
						RESET => RESET,
						STALL => STALL,
						OP1 => intermediate(i*(ADD_PIPELINE+1))(i)(exp_bits+man_bits-1 downto 0),
						OP2 => intermediate(i*(ADD_PIPELINE+1))(i+1)(exp_bits+man_bits-1 downto 0),
						READY => control_joined(i*(ADD_PIPELINE+1)+1)(i+1)(1),
						ROUND => '1',
						EXCEPTION_IN => control_joined(i*(ADD_PIPELINE+1)+1)(i+1)(0),
						DONE	=> mac_control(1),
	--------------------------    DONE is never 1 ?! ---------------------------------------------------
						RESULT	=> mac1,
						-- works
						EXCEPTION_OUT	=> mac_control(0)
					--	DONE => control((i+1)*(ADD_PIPELINE+1)+1)(i+1)(1),
					--	RESULT => intermediate((i+1)*(ADD_PIPELINE+1))(i+1)(i+exp_bits+man_bits-1 downto 0),
					--	EXCEPTION_OUT => control((i+1)*(ADD_PIPELINE+1)+1)(i+1)(0)
			);

		end generate gen;

	end generate ifgen0;
  
--	rnd_norm_0 : rnd_norm_wrapper
--	generic map 
--	(
--		exp_bits             => exp_bits,
--		man_bits_in          => man_bits+mult_in_parallel,
--		man_bits_out         => man_bits
--	)
--	port map 
--	(
--		CLK						=> CLK,
--		RESET						=> RESET,
--		STALL						=> STALL,
--		READY						=> control((mult_in_parallel-1)*(ADD_PIPELINE+1)+1)(mult_in_parallel-1)(1),
--		ROUND						=> '1',
--		OP							=> intermediate((mult_in_parallel-1)*(ADD_PIPELINE+1))(mult_in_parallel-1),
--		EXCEPTION_IN			=> control((mult_in_parallel-1)*(ADD_PIPELINE+1)+1)(mult_in_parallel-1)(0),
--		DONE						=> mac_control(1),
--		RESULT					=> mac,
--		EXCEPTION_OUT			=> mac_control(0)
--	);

	accum_control_joined(0) <= accum_control(0) or mac_control(0);
	--accum_control_joined(1) <= mac_control(1);
    
--	fp_add_0 : fp_add
--	generic map 
--	(
--		exp_bits             => exp_bits,
--		man_bits             => man_bits
--	)
--	port map 
--	(
--		CLK						=> CLK,
--		RESET						=> RESET,
--		STALL						=> STALL,
--		READY                => accum_control_joined(1),
--		OP1                  => mac,
--		OP2                  => accum,
--		EXCEPTION_IN         => accum_control_joined(0),
--		DONE                 => sum_control(1),
--		RESULT               => sum,
--		EXCEPTION_OUT        => sum_control(0)
--	);

	fp_add_0:fp_adder 
			generic map
			(
				exp_bits			=> exp_bits,
				man_bits			=> man_bits-1
			)
			port map
			(
						CLK => CLK,
						RESET => RESET,
						STALL => STALL,
						OP1 => mac1,
						OP2 => accum,
						READY => mac_control(1),
						ROUND => '1',
						EXCEPTION_IN => '0',
						--accum_control_joined(0),
						DONE	=> sum_norm_control(1),
						RESULT	=> sum_norm,
						EXCEPTION_OUT	=> sum_norm_control(0)
					--	DONE => control((i+1)*(ADD_PIPELINE+1)+1)(i+1)(1),
					--	RESULT => intermediate((i+1)*(ADD_PIPELINE+1))(i+1)(i+exp_bits+man_bits-1 downto 0),
					--	EXCEPTION_OUT => control((i+1)*(ADD_PIPELINE+1)+1)(i+1)(0)
			);

--	rnd_norm_1 : rnd_norm_wrapper
--	generic map 
--	(
--		exp_bits             => exp_bits,
--		man_bits_in          => man_bits+2,
--		man_bits_out         => man_bits
--	)
--	port map 
--	(
--		CLK                  => CLK,
--		RESET						=> RESET,
--		STALL						=> STALL,
--		READY                => sum_control(1),
--		ROUND                => '1',
--		OP	                  => sum,
--		EXCEPTION_IN         => sum_control(0),
--		DONE                 => sum_norm_control(1),
--		RESULT               => sum_norm,
--		EXCEPTION_OUT        => sum_norm_control(0)
--	);

	process(CLK,RESET,STALL) is
	begin
		if (RESET = '1') then
			accum				<= (others=>'0');
			accum_control	<= (others=>'0');
		elsif (CLK'event and CLK = '1' and STALL = '0') then
			if (sum_norm_control(1) = '1') then
				accum				<= sum_norm;
				accum_control	<= sum_norm_control;
			--else
			--	accum				<= (others=>'0');
			--	accum_control	<= (others=>'0');
			end if;
		else
			accum				<= accum;
			accum_control	<= accum_control;
		end if;
	end process;
	aaa				<= sum_norm_control(1);
	bbb				<= mac_control(1);
	mac 				<=  mac1;
	result 			<= accum;
	done 				<= accum_control(1);
	exception_out <= accum_control(0);

end behavioral;

