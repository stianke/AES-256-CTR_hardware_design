module data_consumer #(
    parameter DATA_WIDTH = 128,
    parameter FILE_NAME  = "../../../../../verif/generated_test_data/ciphertext.txt"
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    input  logic                  s_axis_tlast,
    output logic                  s_axis_tready
);

    integer fd;
    logic [DATA_WIDTH-1:0] expected_word;
    int word_idx;

    initial begin
        fd = $fopen(FILE_NAME, "r");
        if (fd == 0) $fatal(1, "Failed to open expected ciphertext file: %s", FILE_NAME);
        // Close file when done
        fork
            begin
                wait ($feof(fd));
            end
        join_none
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            s_axis_tready <= 1; // always ready
            word_idx <= 0;
        end else if (s_axis_tvalid && s_axis_tready) begin
            if ($fscanf(fd, "%h\n", expected_word) == 1) begin
                if (s_axis_tdata !== expected_word) begin
                    $fclose(fd);
                    $fatal(1, "Ciphertext mismatch at word %0d: expected %h, got %h", word_idx, expected_word, s_axis_tdata);
                end else begin
                    $display("Word %0d OK: %h", word_idx, s_axis_tdata);
                    if (s_axis_tlast) begin
                        if (!$feof(fd)) begin
                            $fclose(fd);
                            $fatal(1, "Encountered tlast at index %0d, but expected more ciphertext.", word_idx);
                        end else begin
                            $display("Ran out of expected ciphertext words at index %0d, which aligns with tlast", word_idx);
                            $display("Test successful");
                        end
                        $fclose(fd);
                    end
                end
                word_idx++;
            end else if (!s_axis_tlast) begin
                $fclose(fd);
                $fatal(1, "Ran out of expected ciphertext words at index %0d, but it was not tlast", word_idx);
            end
        end
    end

endmodule
