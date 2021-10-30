--======================================================--
--                                                      --
--  NORTHEASTERN UNIVERSITY                             --
--  DEPARTMENT OF ELECTRICAL AND COMPUTER ENGINEERING   --
--  Reconfigurable and GPU Computing Laboratory                        --
--                                                      --
--  AUTHOR       | Sherman Braganza                     --
--  -------------+------------------------------------  --
--  DATE         | 27 February 2008                     --
--  -------------+------------------------------------  --
--  REVISED BY   | Jainik Kathiara                      --
--  -------------+------------------------------------  --
--  DATE         | 21 Sept. 2010                        --
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


---- IEEE Libraries --
library IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE ieee.numeric_std.ALL;

library fp_lib;
use fp_lib.float_pkg.all;

entity fp_acc is
	generic  
	(	
		exp_bits						: integer := 8;
		man_bits						: integer := 24
	);
	port
	(
		CLK							: in	std_logic;
		RESET							: in	std_logic;
		STALL_IN						: in	std_logic;
		READY							: in	std_logic;
		EXCEPTION_IN				: in	std_logic;
		OP								: in	std_logic_vector(exp_bits+man_bits downto 0);
		--outputs
		DONE							: out	std_logic;
		RESULT						: out	std_logic_vector(exp_bits+man_bits+2 downto 0);
		EXCEPTION_OUT				: out	std_logic;
		STALL_OUT					: out	std_logic
	);
end fp_acc;

architecture accumulator_arch of fp_acc is

	constant	add_man_bits		: integer := man_bits + 2;
   
	type NEWOP_INSERTION_STATE is (IDLE,RISE,REGA,REGB,FALLA,FALLB,BUFB);	
		
	signal newop_state			: NEWOP_INSERTION_STATE;

	--These are IN1 and IN2 after registering
 	signal A 	  					: std_logic_vector(exp_bits+man_bits downto 0);
 	signal B	   					: std_logic_vector(exp_bits+man_bits downto 0);
   	
	signal add_rdy 				: std_logic;	
	signal add_done				: std_logic;
	signal add_result				: std_logic_vector(exp_bits+add_man_bits downto 0); 
	
	signal norm_done				: std_logic;	
	signal norm_result			: std_logic_vector(exp_bits+add_man_bits downto 0);  	
	
  	signal buff 					: std_logic_vector(exp_bits+add_man_bits downto 0);

	signal add_exception			: std_logic;
	signal norm_exception		: std_logic;
	signal exception				: std_logic;	     
	
	signal counter					: std_logic_vector(2 downto 0);
	
	signal finish					: std_logic;
	
	signal stall					: std_logic;
begin
	-- New operand insertion state machine
	NEW_OPERAND_STATE_MACHINE : process(CLK,RESET,STALL_IN) is
	begin 
		if (RESET = '1') then
			newop_state	<= IDLE;
			A				<= (others=>'0');
			B				<= (others=>'0');
			add_rdy		<= '0';
			finish		<= '0';
			stall			<= '0';
		elsif (CLK'event and CLK = '1' and STALL_IN = '0') then
			case newop_state is
				when IDLE =>
					if	(READY = '1' and norm_done = '0') then
						newop_state <= RISE;
						A				<= OP;
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '0';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when RISE =>
					if	(READY = '0' and norm_done = '0') then
						newop_state <= FALLB;
						A				<= A;
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '1' and norm_done = '0') then
						newop_state <= REGB;
						A				<= A;
						B				<= OP;
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '0';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when REGB =>
					if	(READY = '0' and norm_done = '0') then
						newop_state <= FALLB;
						A				<= (others=>'0');
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '0' and norm_done = '1') then
						newop_state <= FALLA;
						A				<= norm_result(exp_bits+add_man_bits downto 2);
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '1' and norm_done = '0') then
						newop_state <= REGA;
						A				<= OP;
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '0';
					elsif (READY = '1' and norm_done = '1') then
						newop_state <= REGB;
						A				<= OP;
						B				<= norm_result(exp_bits+add_man_bits downto 2);
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '0';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when REGA =>
					if	(READY = '0' and norm_done = '0') then
						newop_state <= FALLA;
						A				<= A;
						B				<=	B;
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '0' and norm_done = '1') then
						newop_state <= FALLB;
						A				<= A;
						B				<= norm_result(exp_bits+add_man_bits downto 2);
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '1' and norm_done = '0') then
						newop_state <= REGB;
						A				<= A;
						B				<= OP;
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '0';
					elsif (READY = '1' and norm_done = '1') then
						newop_state <= BUFB;
						A				<= A;
						B				<= OP;
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '0';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when BUFB =>
					if	(READY = '0' and norm_done = '0') then
						newop_state <= FALLA;
						A				<= buff(exp_bits+add_man_bits downto 2);
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '0' and norm_done = '1') then
						newop_state <= FALLB;
						A				<= buff(exp_bits+add_man_bits downto 2);
						B				<= norm_result(exp_bits+add_man_bits downto 2);
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '1';
					elsif (READY = '1' and norm_done = '0') then
						newop_state <= REGB;
						A				<= OP;
						B				<= buff(exp_bits+add_man_bits downto 2);
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '0';
					elsif (READY = '1' and norm_done = '1') then
						newop_state <= BUFB;
						A				<= OP;
						B				<= buff(exp_bits+add_man_bits downto 2);
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '0';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when FALLA =>
					if (norm_done = '1') then
						newop_state <= FALLB;
						A				<= A;
						B				<= norm_result(exp_bits+add_man_bits downto 2);
						add_rdy		<= '1';
						finish		<= '0';
						stall			<= '1';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when FALLB =>
					if (norm_done = '1' and counter /= "001") then
						newop_state <= FALLA;
						A				<= norm_result(exp_bits+add_man_bits downto 2);
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '0';
						stall			<= '1';
					elsif (norm_done = '1' and counter = "001") then
						newop_state <= IDLE;
						A				<= (others=>'0');
						B				<= (others=>'0');
						add_rdy		<= '0';
						finish		<= '1';
						stall			<= '0';
					else
						newop_state <= newop_state;
						A				<= A;
						B				<= B;
						add_rdy		<= '0';						
						finish		<= '0';
						stall			<= stall;
					end if;
				when others =>
					newop_state <= IDLE;				
					A				<= (others=>'0');
					B				<= (others=>'0');
					add_rdy		<= '0';
					finish		<= '0';
					stall			<= '0';
			end case;
		else
			newop_state <= newop_state;
			A				<= A;
			B				<= B;
			add_rdy		<= add_rdy;
			finish		<= finish;
		end if;
	end process NEW_OPERAND_STATE_MACHINE;
		
	-- floating point adder
	adder:fp_add
	generic map
	(
		exp_bits					=> exp_bits,
		man_bits					=> man_bits
	)
	port map
	(
		CLK						=> CLK,
		RESET						=> RESET,
		STALL						=> STALL_IN,
		READY						=> add_rdy,
		EXCEPTION_IN			=> '0',
		OP1	         		=> A,
		OP2						=> B,
		RESULT					=> add_result,
		EXCEPTION_OUT			=> add_exception,
		DONE						=> add_done
	);

	-- normalizer
	norm: normalizer
	generic map
	(
		exp_bits					=>	exp_bits,
		man_bits					=>	add_man_bits
	)
	port map
	(
		--inputs
		CLK						=> CLK,
		RESET						=> RESET,
		STALL						=> STALL_IN,
		READY						=>	add_done,
		SIGN_IN					=> add_result(add_man_bits+exp_bits),
		EXP_IN					=>	add_result(add_man_bits+exp_bits-1 downto add_man_bits),
		MAN_IN					=>	add_result(add_man_bits-1 downto 0),
		EXCEPTION_IN			=>	add_exception,
		--outputs
		DONE						=>	norm_done,
		SIGN_OUT					=> norm_result(add_man_bits+exp_bits),
		EXP_OUT					=>	norm_result(add_man_bits+exp_bits-1 downto add_man_bits),
		MAN_OUT					=>	norm_result(add_man_bits-1 downto 0),
		EXCEPTION_OUT			=>	norm_exception
	);	

	BUFFER_PROCESS : process (CLK,RESET,STALL_IN) is
	begin
		if (RESET = '1') then
			buff			<= (others=>'0');
			exception	<= '0';
		elsif (CLK'event and CLK = '1' and STALL_IN = '0') then
			if (norm_done = '1') then
				buff			<= norm_result;
				exception	<= norm_exception;
			else
				buff			<= buff;
				exception	<= exception;
			end if;
		else
			buff			<= buff;
			exception	<= exception;
		end if;
	end process BUFFER_PROCESS;
			
	
	ADD_COUNTER : process (CLK,RESET,STALL_IN) is
	begin
		if (RESET = '1') then
			counter <= (others=>'0');
		elsif (CLK'event and CLK = '1' and STALL_IN = '0') then
			if (add_rdy = '1' and norm_done = '0') then
				counter <= counter + 1;
			elsif (add_rdy = '0' and norm_done = '1') then
				counter <= counter - 1;
			else
				counter <= counter;
			end if;
		else
			counter <= counter;
		end if;
	end process ADD_COUNTER;
	
	DONE 				<= finish;
	RESULT			<= buff;
	EXCEPTION_OUT 	<= exception;
	STALL_OUT		<= stall;
end accumulator_arch;
