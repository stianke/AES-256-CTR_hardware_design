module data_consumer #(
    parameter DATA_WIDTH = 128
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    input  logic                  s_axis_tlast,
    output logic                  s_axis_tready,
    input  integer                test_number
);

    integer fd_ciphertext;
    integer fd_delays;
    integer curr_delay;
    string ciphertext_filename;
    string delays_filename;
    logic [DATA_WIDTH-1:0] expected_word;
    int word_idx;
    integer next_test_number = 0;
    bit file_open = 0;

    initial begin
    end

    always_ff @(posedge clk) begin
        s_axis_tready <= s_axis_tready;
    
        if (rst) begin
            s_axis_tready <= 0;
            word_idx <= 0;
        end else if (curr_delay > 0) begin
            curr_delay = curr_delay - 1;
            if (curr_delay > 0) begin
                s_axis_tready <= 0;
            end else begin
                s_axis_tready <= 1;
            end
        end else if (s_axis_tready) begin
            if (s_axis_tvalid) begin
                
                // Check if received ciphertet is correct
                $fscanf(fd_ciphertext, "%h\n", expected_word);
                if (s_axis_tdata !== expected_word) begin
                    $fclose(fd_ciphertext);
                    $fatal(1, "Test %0d: Ciphertext mismatch at word %0d: expected %h, got %h", test_number, word_idx, expected_word, s_axis_tdata);
                end else begin
                    $display("Test %0d, Word %0d OK: %h", test_number, word_idx, s_axis_tdata);
                end
                
                // Check for error in tlast 
                if (s_axis_tlast) begin
                    if ($feof(fd_ciphertext)) begin
                        file_open = 0;
                        s_axis_tready <= 0;
                        $display("Test %0d: Reached end of ciphertext file at index %0d, which aligns with tlast", test_number, word_idx);
                        $fclose(fd_ciphertext);
                        $fclose(fd_delays);
                        $display("Closed ciphertext data file %s", ciphertext_filename);
                        $display("Closed ciphertext delays file %s", delays_filename);
                    end else begin
                        $fclose(fd_ciphertext);
                        $fatal(1, "Test %0d: Encountered tlast at index %0d, but expected more ciphertext.", test_number, word_idx);
                    end
                end else if ($feof(fd_ciphertext)) begin
                    $fclose(fd_ciphertext);
                    $fatal(1, "Test %0d: Reached end of ciphertext file, at index %0d, but it was not tlast", test_number, word_idx);
                end
                
                if (file_open == 1) begin
                    $fscanf(fd_delays, "%d\n", curr_delay);
                    if (curr_delay > 0) begin
                        s_axis_tready <= 0;
                    end
                end
                word_idx++;
            end
        end else if (file_open == 0) begin
            s_axis_tready <= 0;
            if (test_number == next_test_number) begin // Wait until caller increments to next test
                ciphertext_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_ciphertext.txt", test_number);
                delays_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_consumer_delay_ticks.txt", test_number);
                
                fd_ciphertext = $fopen(ciphertext_filename, "r");
                fd_delays = $fopen(delays_filename, "r");
                
                if (fd_ciphertext == 0) $fatal(1, "Failed to open expected ciphertext file: %s", ciphertext_filename);
                if (fd_delays == 0) $fatal(1, "Failed to open ciphertext delays file: %s", delays_filename);
                
                $display("Opened ciphertext data file %s", ciphertext_filename);
                $display("Opened ciphertext delays file %s", delays_filename);
                
                word_idx <= 0;
                s_axis_tready <= 1;
                
                file_open = 1;
                next_test_number <= test_number + 1;
            end
        end
    end

endmodule
