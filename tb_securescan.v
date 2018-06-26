//------------------------------------------------------------------
// Simulator directives.
//------------------------------------------------------------------
`timescale 1ns/1ps


//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_securescan();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 0;
  parameter DUMP_WAIT = 0;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

  parameter AES_128_BIT_KEY = 0;
  parameter AES_256_BIT_KEY = 1;

  parameter AES_DECIPHER = 1'b0;
  parameter AES_ENCIPHER = 1'b1;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;

  reg            tb_clk,secure_mode,test_mode;
  reg            tb_reset_n;
  reg            tb_encdec;
  reg            tb_init;
  reg            tb_next;
  wire           tb_ready;
  reg [255 : 0]  tb_key;
  reg            tb_keylen;
  reg [127 : 0]  tb_plaintext;
  wire [127 : 0] tb_ciphertext,ScanOut,ScanIn;
  wire           tb_result_valid,faults;
  wire [255 : 0] mux_key;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  securescan dut(
               .clk(tb_clk),
               .reset_n(tb_reset_n),
               .secure_mode(secure_mode),
               .encdec(tb_encdec),
               .init(tb_init),
               .next(tb_next),
               .keylen(tb_keylen),
					.test_mode(test_mode),
					.key(tb_key),
               .plaintext(tb_plaintext),
					.ready(tb_ready),               
					.result_valid(tb_result_valid),
					.ciphertext(tb_ciphertext),
					.ScanOut(ScanOut),
					.faults(faults),
					.mux_key(mux_key),
					.ScanIn(ScanIn)
              );

initial secure_mode = 0;
initial test_mode = 1;
  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;
      #(CLK_PERIOD);
      if (DEBUG)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("State of DUT");
      $display("------------");
      $display("Inputs and outputs:");
      $display("encdec = 0x%01x, init = 0x%01x, next = 0x%01x",
               dut.encdec, dut.init, dut.next);
      $display("keylen = 0x%01x, key  = 0x%032x ", dut.keylen, dut.key);
      $display("plaintext  = 0x%032x", dut.plaintext);
      $display("");
      $display("ready        = 0x%01x", dut.ready);
      $display("result_valid = 0x%01x, result = 0x%032x",
               dut.result_valid, dut.ciphertext);
      $display("");
      $display("Encipher state::");
      $display("enc_ctrl = 0x%01x, round_ctr = 0x%01x",
               dut.AES.enc_block.enc_ctrl_reg, dut.AES.enc_block.round_ctr_reg);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // dump_keys()
  //
  // Dump the keys in the key memory of the dut.
  //----------------------------------------------------------------
  task dump_keys;
    begin
      $display("State of key memory in DUT:");
      $display("key[00] = 0x%016x", dut.AES.keymem.key_mem[00]);
      $display("key[01] = 0x%016x", dut.AES.keymem.key_mem[01]);
      $display("key[02] = 0x%016x", dut.AES.keymem.key_mem[02]);
      $display("key[03] = 0x%016x", dut.AES.keymem.key_mem[03]);
      $display("key[04] = 0x%016x", dut.AES.keymem.key_mem[04]);
      $display("key[05] = 0x%016x", dut.AES.keymem.key_mem[05]);
      $display("key[06] = 0x%016x", dut.AES.keymem.key_mem[06]);
      $display("key[07] = 0x%016x", dut.AES.keymem.key_mem[07]);
      $display("key[08] = 0x%016x", dut.AES.keymem.key_mem[08]);
      $display("key[09] = 0x%016x", dut.AES.keymem.key_mem[09]);
      $display("key[10] = 0x%016x", dut.AES.keymem.key_mem[10]);
      $display("key[11] = 0x%016x", dut.AES.keymem.key_mem[11]);
      $display("key[12] = 0x%016x", dut.AES.keymem.key_mem[12]);
      $display("key[13] = 0x%016x", dut.AES.keymem.key_mem[13]);
      $display("key[14] = 0x%016x", dut.AES.keymem.key_mem[14]);
      $display("");
    end
  endtask // dump_keys


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggle reset.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr = 0;
      error_ctr = 0;
      tc_ctr    = 0;

      tb_clk     = 0;
      tb_reset_n = 1;
      tb_encdec  = 0;
      tb_init    = 0;
      tb_next    = 0;
      tb_key     = {8{32'hz}};
      tb_keylen  = 0;

      tb_plaintext  = {4{32'h00000000}};
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // display_test_result()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_result


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag in the dut to be set.
  //
  // Note: It is the callers responsibility to call the function
  // when the dut is actively processing and will in fact at some
  // point set the flag.
  //----------------------------------------------------------------
  task wait_ready;
    begin
      while (!tb_ready)
        begin
          #(CLK_PERIOD);
          if (DUMP_WAIT)
            begin
              dump_dut_state();
            end
        end
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // wait_valid()
  //
  // Wait for the result_valid flag in the dut to be set.
  //
  // Note: It is the callers responsibility to call the function
  // when the dut is actively processing a block and will in fact
  // at some point set the flag.
  //----------------------------------------------------------------
  task wait_valid;
    begin
      while (!tb_result_valid)
        begin
          #(CLK_PERIOD);
        end
    end
  endtask // wait_valid


  //----------------------------------------------------------------
  // ecb_mode_single_block_test()
  //
  // Perform ECB mode encryption or decryption single block test.
  //----------------------------------------------------------------
  task ecb_mode_single_block_test(input    tc_number,
                                  input           encdec,
                                  input [255 : 0] key,
                                  input           key_length,
                                  input [127 : 0] block,
                                  input [127 : 0] expected);
   begin
     $display("*** TC %0d ECB mode test started.", tc_number);
     tc_ctr = tc_ctr + 1;

     // Init the cipher with the given key and length.
     tb_key = key;
     tb_keylen = key_length;
     tb_init = 1;
     #(2 * CLK_PERIOD);
     tb_init = 0;
     wait_ready();

     $display("Key expansion done");
     $display("");

     dump_keys();


     // Perform encipher och decipher operation on the block.
     tb_encdec = encdec;
     tb_plaintext = block;
     tb_next = 1;
     #(2 * CLK_PERIOD);
     tb_next = 0;
     wait_ready();

     if (tb_ciphertext == expected)
       begin
         $display("*** TC %0d successful.", tc_number);
         $display("");
       end
     else
       begin
         $display("*** ERROR: TC %0d NOT successful.", tc_number);
         $display("Expected: 0x%032x", expected);
         $display("Got:      0x%032x", tb_ciphertext);
         $display("");

         error_ctr = error_ctr + 1;
       end
   end
  endtask // ecb_mode_single_block_test


  //----------------------------------------------------------------
  // aes_core_test
  // The main test functionality.
  //
  // Test cases taken from NIST SP 800-38A:
  // http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
  //----------------------------------------------------------------
  initial
    begin : aes_core_test
	   reg [127 : 0] aes128_key;
      reg [255 : 0] nist_aes128_key;
      reg [255 : 0] nist_aes256_key;

      reg [127 : 0] nist_plaintext0;
      reg [127 : 0] nist_plaintext1;
      reg [127 : 0] nist_plaintext2;
      reg [127 : 0] nist_plaintext3;

      reg [127 : 0] nist_ecb_128_enc_expected0;
      reg [127 : 0] nist_ecb_128_enc_expected1;
      reg [127 : 0] nist_ecb_128_enc_expected2;
      reg [127 : 0] nist_ecb_128_enc_expected3;

      reg [127 : 0] nist_ecb_256_enc_expected0;
      reg [127 : 0] nist_ecb_256_enc_expected1;
      reg [127 : 0] nist_ecb_256_enc_expected2;
      reg [127 : 0] nist_ecb_256_enc_expected3;

      aes128_key = 128'h4861727368612d535856313531363330; 
      nist_aes128_key = {aes128_key,128'hZ};
      nist_aes256_key = {aes128_key,aes128_key};

      nist_plaintext0 = 128'h0;
      nist_plaintext1 = 128'h1;
      nist_plaintext2 = 128'h2;
      nist_plaintext3 = 128'h3;

      nist_ecb_128_enc_expected0 = 128'h128;
//////////      nist_ecb_128_enc_expected1 = 128'h14c7583117de1844e5adba66a0ba2eff;
//////////      nist_ecb_128_enc_expected2 = 128'h320135f817768ba5116858e49a22a98a;
//////////      nist_ecb_128_enc_expected3 = 128'h5b428f73fe558d227aabcb085e8e5d1e;

      nist_ecb_256_enc_expected0 = 128'h256;
//////////      nist_ecb_256_enc_expected1 = 128'h8e078edc7c40495585e437f13f375643;
//////////      nist_ecb_256_enc_expected2 = 128'he4e1045556734ecedcbdb0759268469c;
//////////      nist_ecb_256_enc_expected3 = 128'he2f27e2c1da01938d64b753778fb2764;


      $display("   -= Testbench for aes core started =-");
      $display("     ================================");
      $display("");

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();


      $display("ECB 128 bit key tests");
      $display("---------------------");
      ecb_mode_single_block_test(8'h01, AES_ENCIPHER, nist_aes128_key, AES_128_BIT_KEY,
                                 ScanIn, nist_ecb_128_enc_expected0);

////////////////////     ecb_mode_single_block_test(8'h02, AES_ENCIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                nist_plaintext1, nist_ecb_128_enc_expected1);
////////////////////
////////////////////     ecb_mode_single_block_test(8'h03, AES_ENCIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                nist_plaintext2, nist_ecb_128_enc_expected2);
////////////////////
////////////////////     ecb_mode_single_block_test(8'h04, AES_ENCIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                nist_plaintext3, nist_ecb_128_enc_expected3);
////////////////////
////////////////////
////////////////////      ecb_mode_single_block_test(8'h05, AES_DECIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                 nist_ecb_128_enc_expected0, nist_plaintext0);
////////////////////
////////////////////      ecb_mode_single_block_test(8'h06, AES_DECIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                 nist_ecb_128_enc_expected1, nist_plaintext1);
////////////////////
////////////////////      ecb_mode_single_block_test(8'h07, AES_DECIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                 nist_ecb_128_enc_expected2, nist_plaintext2);
////////////////////
////////////////////      ecb_mode_single_block_test(8'h08, AES_DECIPHER, nist_aes128_key, AES_128_BIT_KEY,
////////////////////                                 nist_ecb_128_enc_expected3, nist_plaintext3);


      $display("");
      $display("ECB 256 bit key tests");
      $display("---------------------");
      ecb_mode_single_block_test(8'h10, AES_ENCIPHER, nist_aes256_key, AES_256_BIT_KEY,
                                 ScanIn, nist_ecb_256_enc_expected0);

////////////////      ecb_mode_single_block_test(8'h11, AES_ENCIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_plaintext1, nist_ecb_256_enc_expected1);
////////////////
////////////////      ecb_mode_single_block_test(8'h12, AES_ENCIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_plaintext2, nist_ecb_256_enc_expected2);
////////////////
////////////////      ecb_mode_single_block_test(8'h13, AES_ENCIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_plaintext3, nist_ecb_256_enc_expected3);
////////////////
////////////////
////////////////      ecb_mode_single_block_test(8'h14, AES_DECIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_ecb_256_enc_expected0, nist_plaintext0);
////////////////
////////////////      ecb_mode_single_block_test(8'h15, AES_DECIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_ecb_256_enc_expected1, nist_plaintext1);
////////////////
////////////////      ecb_mode_single_block_test(8'h16, AES_DECIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_ecb_256_enc_expected2, nist_plaintext2);
////////////////
////////////////      ecb_mode_single_block_test(8'h17, AES_DECIPHER, nist_aes256_key, AES_256_BIT_KEY,
////////////////                                 nist_ecb_256_enc_expected3, nist_plaintext3);


      display_test_result();
      $display("");
      $display("*** AES core simulation done. ***");
      #100 $finish;
    end // aes_core_test
endmodule // tb_aes_core

//======================================================================
// EOF tb_aes_core.v
//======================================================================

