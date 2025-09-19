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

    integer fd;
    logic [DATA_WIDTH-1:0] expected_word;
    int word_idx;
    string ciphertext_filename;
    integer next_test_number = 0;
    bit file_open = 0;

    initial begin
    end

    always_ff @(posedge clk) begin
        s_axis_tready <= s_axis_tready;
    
        if (rst) begin
            s_axis_tready <= 0;
            word_idx <= 0;
        end else if (file_open == 0) begin
            s_axis_tready <= 0;
            if (test_number == next_test_number) begin // Wait until caller increments to next test
                ciphertext_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_ciphertext.txt", test_number);
                fd = $fopen(ciphertext_filename, "r");
                if (fd == 0) $fatal(1, "Failed to open expected ciphertext file: %s", ciphertext_filename);
                //$display("Opened file %s: %0d", plaintext_filename, fd);
                
                word_idx <= 0;
                s_axis_tready <= 1;
                
                file_open <= 1;
                next_test_number <= test_number + 1;
            end
        end else if (s_axis_tvalid && s_axis_tready) begin
            if ($fscanf(fd, "%h\n", expected_word) == 1) begin
                if (s_axis_tdata !== expected_word) begin
                    $fclose(fd);
                    $fatal(1, "Test %0d: Ciphertext mismatch at word %0d: expected %h, got %h", test_number, word_idx, expected_word, s_axis_tdata);
                end else begin
                    $display("Test %0d, Word %0d OK: %h", test_number, word_idx, s_axis_tdata);
                    if (s_axis_tlast) begin
                        if ($feof(fd)) begin
                            $fclose(fd);
                            file_open <= 0;
                            s_axis_tready <= 0;
                            $display("Test %0d: Reached end of ciphertext file at index %0d, which aligns with tlast", test_number, word_idx);
                        end else begin
                            $fclose(fd);
                            $fatal(1, "Test %0d: Encountered tlast at index %0d, but expected more ciphertext.", test_number, word_idx);
                        end
                    end else if ($feof(fd)) begin
                        $fclose(fd);
                        $fatal(1, "Test %0d: Reached end of ciphertext file, at index %0d, but it was not tlast", test_number, word_idx);
                    end
                end
                word_idx++;
            end
        end
    end

endmodule
